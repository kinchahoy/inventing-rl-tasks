"""This module implements an Earley parser with a dynamic lexer

The core Earley algorithm used here is based on Elizabeth Scott's implementation, here:
    https://www.sciencedirect.com/science/article/pii/S1571066108001497

That is probably the best reference for understanding the algorithm here.

The Earley parser outputs an SPPF-tree as per that document. The SPPF tree format
is better documented here:
    http://www.bramvandersanden.com/post/2014/06/shared-packed-parse-forest/

Instead of running a lexer beforehand, or using a costy char-by-char method, this parser
uses regular expressions by necessity, achieving high-performance while maintaining all of
Earley's power in parsing any CFG.
"""

import gc
from typing import TYPE_CHECKING, Callable, Optional, List, Any
from collections import defaultdict

from ..tree import Tree
from ..exceptions import UnexpectedCharacters
from ..lexer import Token
from ..grammar import Terminal
from .earley import Parser as BaseParser
from .earley_common import build_lr0, make_item
from .earley_forest import NEG_INF, PackedNode, StableSymbolNode, TokenNode
from ._parallel import Batch, thread_budget

if TYPE_CHECKING:
    from ..common import LexerConf, ParserConf

# Packed nodes of a column are created by pool tasks of at least this many families (see `_Run`).
GROUP_FAMILIES = 600

_new = object.__new__


def _record(item):
    """What a later completion needs to know about `item` acting as an originator."""
    nxt = item.l.next
    start = item.start
    return (nxt, start), (nxt.nid, start), nxt.s, item.node, item.rule


def _add_families(i, events, nodes):
    """Add the packed nodes of column `i`: one for every (originator, completed node) pair of `events`.

    Equivalent to the `add_family` calls of the sequential completer, in the same order. Each task owns
    the SPPF nodes ending at `i`, so tasks for different columns never write to the same node.
    """
    get = nodes.get
    for right, originators in events:
        for _, node_key, s, left, rule in originators:
            target = get(node_key)
            if target is None:
                continue    # label of a carried-over item: its node is unreachable
            packed = _new(PackedNode)
            packed.parent = target
            packed.s = s
            packed.start = i
            packed.rule = rule
            packed.left = left
            packed.right = right
            packed.priority = NEG_INF
            packed._hash = hash((left, right))
            target._children.d[packed] = None


def _add_group(group):
    for i, events, nodes in group:
        _add_families(i, events, nodes)


class _Run:
    """State of one optimized parse: originator index per column and the packed-node work queue."""
    __slots__ = ('prep', 'workers', 'batch', 'group', 'count')

    def __init__(self):
        self.prep = []                          # per column: expected symbol name -> originator records
        self.workers = thread_budget() - 1      # helper threads; 0 means everything runs inline
        self.batch = None
        self.group = []
        self.count = 0

    def families(self, i, events, nodes, total):
        if not self.workers:
            _add_families(i, events, nodes)
            return
        self.group.append((i, events, nodes))
        self.count += total
        if self.count >= GROUP_FAMILIES:
            if self.batch is None:
                self.batch = Batch(self.workers)
            self.batch.submit(_add_group, self.group)
            self.group = []
            self.count = 0

    def finish(self):
        if self.group:
            _add_group(self.group)
            self.group = []
        if self.batch is not None:
            self.batch.join()

    def cancel(self):
        if self.batch is not None:
            self.batch.cancel()


class Parser(BaseParser):
    def __init__(self, lexer_conf: 'LexerConf', parser_conf: 'ParserConf', term_matcher: Callable,
                 resolve_ambiguity: bool=True, complete_lex: bool=False, debug: bool=False,
                 tree_class: Optional[Callable[[str, List], Any]]=Tree, ordered_sets: bool=True):
        BaseParser.__init__(self, lexer_conf, parser_conf, term_matcher, resolve_ambiguity,
                            debug, tree_class, ordered_sets)
        self.ignore = [Terminal(t) for t in lexer_conf.ignore]
        self.complete_lex = complete_lex

        # The optimized chart construction (`_parse_fast`) assumes insertion-ordered sets and no empty
        # rules, i.e. no zero-length completions, held completions or Leo transitives. Everything else
        # runs the generic algorithm below.
        rules = list(dict.fromkeys(list(parser_conf.rules) + [r for rs in self.predictions.values() for r in rs]))
        self._fast = bool(type(self) is Parser and ordered_sets and self.SymbolNode is StableSymbolNode
                          and all(rule.expansion for rule in rules))
        if self._fast:
            self._lr0_first = build_lr0(rules, self.TERMINALS)

    def _column(self, i, to_scan, columns, nodes, run):
        """Earley predictor and completer for column `i` (replaces `predict_and_complete`).

        Same items, in the same order, as the generic version. Differences that cannot be observed:
        completed nodes and predicted symbols are processed once per column (repeating them only
        re-adds identical packed nodes or already present items), originators come from an index
        instead of a scan of the column, and the packed nodes are created by `run` afterwards,
        possibly on other threads.
        """
        column = columns[i].d
        scan_items = to_scan.d
        incoming = defaultdict(list)
        run.prep.append(incoming)
        prep = run.prep
        seen = {}
        for item in column:
            pos = item.l
            seen[pos, item.start] = item
            if not pos.complete and not pos.eterm:
                incoming[pos.ename].append(_record(item))
        for item in scan_items:
            seen[item.l, item.start] = item

        predictions = self.predictions
        first = self._lr0_first
        symbol_node = self.SymbolNode
        stack = list(column)
        pop = stack.pop
        push = stack.append
        done = set()
        asked = set()
        events = []
        total = 0
        while stack:
            item = pop()
            pos = item.l
            if pos.complete:
                right = item.node
                if right in done:
                    continue
                done.add(right)
                originators = prep[item.start].get(pos.oname)
                if not originators:
                    continue
                events.append((right, originators))
                total += len(originators)
                for key, node_key, s, _, _ in [rec for rec in originators if rec[0] not in seen]:
                    nxt, start = key
                    new = make_item(nxt, start)
                    node = nodes.get(node_key)
                    if node is None:
                        node = nodes[node_key] = symbol_node(s, start, i)
                    new.node = node
                    seen[key] = new
                    if nxt.eterm:
                        scan_items[new] = None
                    else:
                        column[new] = None
                        push(new)
                        if not nxt.complete:
                            incoming[nxt.ename].append(_record(new))
            elif not pos.eterm:
                name = pos.ename
                if name in asked:
                    continue
                asked.add(name)
                for rule in predictions[pos.expect]:
                    start_pos = first[rule]
                    key = (start_pos, i)
                    if key in seen:
                        continue
                    new = make_item(start_pos, i)
                    seen[key] = new
                    if start_pos.eterm:
                        scan_items[new] = None
                    else:
                        column[new] = None
                        push(new)
                        incoming[start_pos.ename].append(_record(new))
        if events:
            run.families(i, events, nodes, total)

    def _parse_fast(self, stream, columns, to_scan, start_symbol=None):
        """`_parse` for grammars without empty rules; see `_column`."""
        make = make_item
        match = self.term_matcher
        terminals = self.lexer_conf.terminals_by_name
        symbol_node = self.SymbolNode
        ignore = self.ignore
        complete_lex = self.complete_lex

        def scan(i, to_scan):
            node_cache = {}
            matches = {}    # the match of a terminal at `i` does not depend on the item expecting it

            for item in to_scan:
                name = item.l.ename
                if name in matches:
                    m = matches[name]
                else:
                    m = matches[name] = match(item.expect, stream, i)
                if m:
                    t = Token(name, m.group(0), i, text_line, text_column)
                    delayed_matches[m.end()].append( (item, i, t) )

                    if complete_lex:
                        s = m.group(0)
                        for j in range(1, len(s)):
                            m = match(item.expect, s[:-j])
                            if m:
                                t = Token(item.expect.name, m.group(0), i, text_line, text_column)
                                delayed_matches[i+m.end()].append( (item, i, t) )

            for x in ignore:
                m = match(x, stream, i)
                if m:
                    delayed_matches[m.end()].extend([(item, i, None) for item in to_scan ])
                    delayed_matches[m.end()].extend([(item, i, None) for item in columns[i] if item.is_complete and item.s == start_symbol])

            next_to_scan = self.Set()
            next_set = self.Set()
            columns.append(next_set)
            transitives.append({})

            for item, start, token in delayed_matches[i+1]:
                if token is not None:
                    token.end_line = text_line
                    token.end_column = text_column + 1
                    token.end_pos = i + 1

                    pos = item.l.next
                    new_item = make(pos, item.start)
                    token_node = TokenNode(token, terminals[token.type])
                    node_key = (pos.nid, item.start)
                    node = node_cache.get(node_key)
                    if node is None:
                        node = node_cache[node_key] = symbol_node(pos.s, item.start, i + 1)
                    new_item.node = node
                    node.add_family(pos.s, item.rule, item.start, item.node, token_node)
                else:
                    new_item = item

                if new_item.l.eterm:
                    next_to_scan.add(new_item)
                else:
                    next_set.add(new_item)

            del delayed_matches[i+1]

            if not next_set and not delayed_matches and not next_to_scan:
                considered_rules = list(sorted(to_scan, key=lambda key: key.rule.origin.name))
                raise UnexpectedCharacters(stream, i, text_line, text_column, {item.expect.name for item in to_scan},
                                           set(to_scan), state=frozenset(i.s for i in to_scan),
                                           considered_rules=considered_rules
                                           )

            return next_to_scan, node_cache

        delayed_matches = defaultdict(list)
        transitives = [{}]
        text_line = 1
        text_column = 1

        run = _Run()
        enabled = gc.isenabled()
        gc.disable()    # the chart only allocates; collections would stop the packed-node threads
        try:
            i = 0
            node_cache = {}
            for token in stream:
                self._column(i, to_scan, columns, node_cache, run)

                to_scan, node_cache = scan(i, to_scan)

                if token == '\n':
                    text_line += 1
                    text_column = 1
                else:
                    text_column += 1
                i += 1

            self._column(i, to_scan, columns, node_cache, run)
            run.finish()
        except BaseException:
            run.cancel()
            raise
        finally:
            if enabled:
                gc.enable()

        assert i == len(columns)-1
        return to_scan

    def _parse(self, stream, columns, to_scan, start_symbol=None):
        if self._fast:
            return self._parse_fast(stream, columns, to_scan, start_symbol)

        def scan(i, to_scan):
            """The core Earley Scanner.

            This is a custom implementation of the scanner that uses the
            Lark lexer to match tokens. The scan list is built by the
            Earley predictor, based on the previously completed tokens.
            This ensures that at each phase of the parse we have a custom
            lexer context, allowing for more complex ambiguities."""

            node_cache = {}

            # 1) Loop the expectations and ask the lexer to match.
            # Since regexp is forward looking on the input stream, and we only
            # want to process tokens when we hit the point in the stream at which
            # they complete, we push all tokens into a buffer (delayed_matches), to
            # be held possibly for a later parse step when we reach the point in the
            # input stream at which they complete.
            for item in self.Set(to_scan):
                m = match(item.expect, stream, i)
                if m:
                    t = Token(item.expect.name, m.group(0), i, text_line, text_column)
                    delayed_matches[m.end()].append( (item, i, t) )

                    if self.complete_lex:
                        s = m.group(0)
                        for j in range(1, len(s)):
                            m = match(item.expect, s[:-j])
                            if m:
                                t = Token(item.expect.name, m.group(0), i, text_line, text_column)
                                delayed_matches[i+m.end()].append( (item, i, t) )

                    # XXX The following 3 lines were commented out for causing a bug. See issue #768
                    # # Remove any items that successfully matched in this pass from the to_scan buffer.
                    # # This ensures we don't carry over tokens that already matched, if we're ignoring below.
                    # to_scan.remove(item)

            # 3) Process any ignores. This is typically used for e.g. whitespace.
            # We carry over any unmatched items from the to_scan buffer to be matched again after
            # the ignore. This should allow us to use ignored symbols in non-terminals to implement
            # e.g. mandatory spacing.
            for x in self.ignore:
                m = match(x, stream, i)
                if m:
                    # Carry over any items still in the scan buffer, to past the end of the ignored items.
                    delayed_matches[m.end()].extend([(item, i, None) for item in to_scan ])

                    # If we're ignoring up to the end of the file, # carry over the start symbol if it already completed.
                    delayed_matches[m.end()].extend([(item, i, None) for item in columns[i] if item.is_complete and item.s == start_symbol])

            next_to_scan = self.Set()
            next_set = self.Set()
            columns.append(next_set)
            transitives.append({})

            ## 4) Process Tokens from delayed_matches.
            # This is the core of the Earley scanner. Create an SPPF node for each Token,
            # and create the symbol node in the SPPF tree. Advance the item that completed,
            # and add the resulting new item to either the Earley set (for processing by the
            # completer/predictor) or the to_scan buffer for the next parse step.
            for item, start, token in delayed_matches[i+1]:
                if token is not None:
                    token.end_line = text_line
                    token.end_column = text_column + 1
                    token.end_pos = i + 1

                    new_item = item.advance()
                    label = (new_item.s, new_item.start, i + 1)
                    token_node = TokenNode(token, terminals[token.type])
                    new_item.node = node_cache[label] if label in node_cache else node_cache.setdefault(label, self.SymbolNode(*label))
                    new_item.node.add_family(new_item.s, item.rule, new_item.start, item.node, token_node)
                else:
                    new_item = item

                if new_item.expect in self.TERMINALS:
                    # add (B ::= Aai+1.B, h, y) to Q'
                    next_to_scan.add(new_item)
                else:
                    # add (B ::= Aa+1.B, h, y) to Ei+1
                    next_set.add(new_item)

            del delayed_matches[i+1]    # No longer needed, so unburden memory

            if not next_set and not delayed_matches and not next_to_scan:
                considered_rules = list(sorted(to_scan, key=lambda key: key.rule.origin.name))
                raise UnexpectedCharacters(stream, i, text_line, text_column, {item.expect.name for item in to_scan},
                                           set(to_scan), state=frozenset(i.s for i in to_scan),
                                           considered_rules=considered_rules
                                           )

            return next_to_scan, node_cache


        delayed_matches = defaultdict(list)
        match = self.term_matcher
        terminals = self.lexer_conf.terminals_by_name

        # Cache for nodes & tokens created in a particular parse step.
        transitives = [{}]

        text_line = 1
        text_column = 1

        ## The main Earley loop.
        # Run the Prediction/Completion cycle for any Items in the current Earley set.
        # Completions will be added to the SPPF tree, and predictions will be recursively
        # processed down to terminals/empty nodes to be added to the scanner for the next
        # step.
        i = 0
        node_cache = {}
        for token in stream:
            self.predict_and_complete(i, to_scan, columns, transitives, node_cache)

            to_scan, node_cache = scan(i, to_scan)

            if token == '\n':
                text_line += 1
                text_column = 1
            else:
                text_column += 1
            i += 1

        self.predict_and_complete(i, to_scan, columns, transitives, node_cache)

        ## Column is now the final column in the parse.
        assert i == len(columns)-1
        return to_scan
