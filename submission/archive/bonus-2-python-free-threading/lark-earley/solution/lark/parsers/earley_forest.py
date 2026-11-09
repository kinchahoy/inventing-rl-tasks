""""This module implements an SPPF implementation

This is used as the primary output mechanism for the Earley parser
in order to store complex ambiguities.

Full reference and more details is here:
https://web.archive.org/web/20190616123959/http://www.bramvandersanden.com/post/2014/06/shared-packed-parse-forest/
"""

import gc
import marshal
from typing import Type, AbstractSet
from random import randint
from collections import deque
from operator import attrgetter
from importlib import import_module
from functools import partial

from ..parse_tree_builder import AmbiguousIntermediateExpander
from ..visitors import Discard
from ..utils import logger, OrderedSet
from ..tree import Tree
from ._parallel import Gang, thread_budget

# Forests whose root spans fewer characters are prioritised by one thread.
GANG_MIN_SPAN = 64

# Initial priority shared by all nodes (a float is immutable, so one object serves all of them). It is
# taken from an unmarshalled code constant because those are immortal on free-threaded CPython (an
# implementation detail; elsewhere it is just a float): the parallel forest walk overwrites the
# priority of every node, and decrefs of one ordinary shared float would contend across all threads,
# while one float per node would be freed across threads.
NEG_INF = eval(marshal.loads(marshal.dumps(compile('-1e400', '<NEG_INF>', 'eval'))))


class ForestNode:
    pass

class SymbolNode(ForestNode):
    """
    A Symbol Node represents a symbol (or Intermediate LR0).

    Symbol nodes are keyed by the symbol (s). For intermediate nodes
    s will be an LR0, stored as a tuple of (rule, ptr). For completed symbol
    nodes, s will be a string representing the non-terminal origin (i.e.
    the left hand side of the rule).

    The children of a Symbol or Intermediate Node will always be Packed Nodes;
    with each Packed Node child representing a single derivation of a production.

    Hence a Symbol Node with a single child is unambiguous.

    Parameters:
        s: A Symbol, or a tuple of (rule, ptr) for an intermediate node.
        start: For dynamic lexers, the index of the start of the substring matched by this symbol (inclusive).
        end: For dynamic lexers, the index of the end of the substring matched by this symbol (exclusive).

    Properties:
        is_intermediate: True if this node is an intermediate node.
        priority: The priority of the node's symbol.
    """
    Set: Type[AbstractSet] = set   # Overridden by StableSymbolNode
    __slots__ = ('s', 'start', 'end', '_children', 'paths', 'paths_loaded', 'priority', 'is_intermediate')
    def __init__(self, s, start, end):
        self.s = s
        self.start = start
        self.end = end
        self._children = self.Set()
        self.paths = self.Set()
        self.paths_loaded = False

        ### We use inf here as it can be safely negated without resorting to conditionals,
        #   unlike None or float('NaN'), and sorts appropriately.
        self.priority = NEG_INF
        self.is_intermediate = isinstance(s, tuple)

    def add_family(self, lr0, rule, start, left, right):
        self._children.add(PackedNode(self, lr0, rule, start, left, right))

    def add_path(self, transitive, node):
        self.paths.add((transitive, node))

    def load_paths(self):
        for transitive, node in self.paths:
            if transitive.next_titem is not None:
                vn = type(self)(transitive.next_titem.s, transitive.next_titem.start, self.end)
                vn.add_path(transitive.next_titem, node)
                self.add_family(transitive.reduction.rule.origin, transitive.reduction.rule, transitive.reduction.start, transitive.reduction.node, vn)
            else:
                self.add_family(transitive.reduction.rule.origin, transitive.reduction.rule, transitive.reduction.start, transitive.reduction.node, node)
        self.paths_loaded = True

    @property
    def is_ambiguous(self):
        """Returns True if this node is ambiguous."""
        return len(self.children) > 1

    @property
    def children(self):
        """Returns a list of this node's children sorted from greatest to
        least priority."""
        if not self.paths_loaded:
            self.load_paths()
        children = self._children
        if len(children) == 1:
            return list(children)
        return sorted(children, key=attrgetter('sort_key'))

    def __iter__(self):
        return iter(self._children)

    def __repr__(self):
        if self.is_intermediate:
            rule = self.s[0]
            ptr = self.s[1]
            before = ( expansion.name for expansion in rule.expansion[:ptr] )
            after = ( expansion.name for expansion in rule.expansion[ptr:] )
            symbol = "{} ::= {}* {}".format(rule.origin.name, ' '.join(before), ' '.join(after))
        else:
            symbol = self.s.name
        return "({}, {}, {}, {})".format(symbol, self.start, self.end, self.priority)

class StableSymbolNode(SymbolNode):
    "A version of SymbolNode that uses OrderedSet for output stability"
    Set = OrderedSet

class PackedNode(ForestNode):
    """
    A Packed Node represents a single derivation in a symbol node.

    Parameters:
        rule: The rule associated with this node.
        parent: The parent of this node.
        left: The left child of this node. ``None`` if one does not exist.
        right: The right child of this node. ``None`` if one does not exist.
        priority: The priority of this node.
    """
    __slots__ = ('parent', 's', 'rule', 'start', 'left', 'right', 'priority', '_hash')
    def __init__(self, parent, s, rule, start, left, right):
        self.parent = parent
        self.s = s
        self.start = start
        self.rule = rule
        self.left = left
        self.right = right
        self.priority = NEG_INF
        self._hash = hash((self.left, self.right))

    @property
    def is_empty(self):
        return self.left is None and self.right is None

    @property
    def sort_key(self):
        """
        Used to sort PackedNode children of SymbolNodes.
        A SymbolNode has multiple PackedNodes if it matched
        ambiguously. Hence, we use the sort order to identify
        the order in which ambiguous children should be considered.
        """
        return self.left is None and self.right is None, -self.priority, self.rule.order

    @property
    def children(self):
        """Returns a list of this node's children."""
        left = self.left
        right = self.right
        if left is None:
            return [] if right is None else [right]
        return [left] if right is None else [left, right]

    def __iter__(self):
        yield self.left
        yield self.right

    def __eq__(self, other):
        if not isinstance(other, PackedNode):
            return False
        return self is other or (self.left == other.left and self.right == other.right)

    def __hash__(self):
        return self._hash

    def __repr__(self):
        if isinstance(self.s, tuple):
            rule = self.s[0]
            ptr = self.s[1]
            before = ( expansion.name for expansion in rule.expansion[:ptr] )
            after = ( expansion.name for expansion in rule.expansion[ptr:] )
            symbol = "{} ::= {}* {}".format(rule.origin.name, ' '.join(before), ' '.join(after))
        else:
            symbol = self.s.name
        return "({}, {}, {}, {})".format(symbol, self.start, self.priority, self.rule.order)

class TokenNode(ForestNode):
    """
    A Token Node represents a matched terminal and is always a leaf node.

    Parameters:
        token: The Token associated with this node.
        term: The TerminalDef matched by the token.
        priority: The priority of this node.
    """
    __slots__ = ('token', 'term', 'priority', '_hash')
    def __init__(self, token, term, priority=None):
        self.token = token
        self.term = term
        if priority is not None:
            self.priority = priority
        else:
            self.priority = term.priority if term is not None else 0
        self._hash = hash(token)

    def __eq__(self, other):
        if not isinstance(other, TokenNode):
            return False
        return self is other or (self.token == other.token)

    def __hash__(self):
        return self._hash

    def __repr__(self):
        return repr(self.token)

class ForestVisitor:
    """
    An abstract base class for building forest visitors.

    This class performs a controllable depth-first walk of an SPPF.
    The visitor will not enter cycles and will backtrack if one is encountered.
    Subclasses are notified of cycles through the ``on_cycle`` method.

    Behavior for visit events is defined by overriding the
    ``visit*node*`` functions.

    The walk is controlled by the return values of the ``visit*node_in``
    methods. Returning a node(s) will schedule them to be visited. The visitor
    will begin to backtrack if no nodes are returned.

    Parameters:
        single_visit: If ``True``, non-Token nodes will only be visited once.
    """

    def __init__(self, single_visit=False):
        self.single_visit = single_visit

    def visit_token_node(self, node):
        """Called when a ``Token`` is visited. ``Token`` nodes are always leaves."""
        pass

    def visit_symbol_node_in(self, node):
        """Called when a symbol node is visited. Nodes that are returned
        will be scheduled to be visited. If ``visit_intermediate_node_in``
        is not implemented, this function will be called for intermediate
        nodes as well."""
        pass

    def visit_symbol_node_out(self, node):
        """Called after all nodes returned from a corresponding ``visit_symbol_node_in``
        call have been visited. If ``visit_intermediate_node_out``
        is not implemented, this function will be called for intermediate
        nodes as well."""
        pass

    def visit_packed_node_in(self, node):
        """Called when a packed node is visited. Nodes that are returned
        will be scheduled to be visited. """
        pass

    def visit_packed_node_out(self, node):
        """Called after all nodes returned from a corresponding ``visit_packed_node_in``
        call have been visited."""
        pass

    def on_cycle(self, node, path):
        """Called when a cycle is encountered.

        Parameters:
            node: The node that causes a cycle.
            path: The list of nodes being visited: nodes that have been
                entered but not exited. The first element is the root in a forest
                visit, and the last element is the node visited most recently.
                ``path`` should be treated as read-only.
        """
        pass

    def get_cycle_in_path(self, node, path):
        """A utility function for use in ``on_cycle`` to obtain a slice of
        ``path`` that only contains the nodes that make up the cycle."""
        index = len(path) - 1
        while id(path[index]) != id(node):
            index -= 1
        return path[index:]

    def visit(self, root):
        # Visiting is a list of IDs of all symbol/intermediate nodes currently in
        # the stack. It serves two purposes: to detect when we 'recurse' in and out
        # of a symbol/intermediate so that we can process both up and down. Also,
        # since the SPPF can have cycles it allows us to detect if we're trying
        # to recurse into a node that's already on the stack (infinite recursion).
        visiting = set()

        # set of all nodes that have been visited
        visited = set()

        # a list of nodes that are currently being visited
        # used for the `on_cycle` callback
        path = []

        # We do not use recursion here to walk the Forest due to the limited
        # stack size in python. Therefore input_stack is essentially our stack.
        input_stack = deque([root])

        # It is much faster to cache these as locals since they are called
        # many times in large parses.
        vpno = getattr(self, 'visit_packed_node_out')
        vpni = getattr(self, 'visit_packed_node_in')
        vsno = getattr(self, 'visit_symbol_node_out')
        vsni = getattr(self, 'visit_symbol_node_in')
        vino = getattr(self, 'visit_intermediate_node_out', vsno)
        vini = getattr(self, 'visit_intermediate_node_in', vsni)
        vtn = getattr(self, 'visit_token_node')
        oc = getattr(self, 'on_cycle')

        while input_stack:
            current = next(reversed(input_stack))
            try:
                next_node = next(current)
            except StopIteration:
                input_stack.pop()
                continue
            except TypeError:
                ### If the current object is not an iterator, pass through to Token/SymbolNode
                pass
            else:
                if next_node is None:
                    continue

                if id(next_node) in visiting:
                    oc(next_node, path)
                    continue

                input_stack.append(next_node)
                continue

            if isinstance(current, TokenNode):
                vtn(current.token)
                input_stack.pop()
                continue

            current_id = id(current)
            if current_id in visiting:
                if isinstance(current, PackedNode):
                    vpno(current)
                elif current.is_intermediate:
                    vino(current)
                else:
                    vsno(current)
                input_stack.pop()
                path.pop()
                visiting.remove(current_id)
                visited.add(current_id)
            elif self.single_visit and current_id in visited:
                input_stack.pop()
            else:
                visiting.add(current_id)
                path.append(current)
                if isinstance(current, PackedNode):
                    next_node = vpni(current)
                elif current.is_intermediate:
                    next_node = vini(current)
                else:
                    next_node = vsni(current)
                if next_node is None:
                    continue

                if not isinstance(next_node, ForestNode):
                    next_node = iter(next_node)
                elif id(next_node) in visiting:
                    oc(next_node, path)
                    continue

                input_stack.append(next_node)

class ForestTransformer(ForestVisitor):
    """The base class for a bottom-up forest transformation. Most users will
    want to use ``TreeForestTransformer`` instead as it has a friendlier
    interface and covers most use cases.

    Transformations are applied via inheritance and overriding of the
    ``transform*node`` methods.

    ``transform_token_node`` receives a ``Token`` as an argument.
    All other methods receive the node that is being transformed and
    a list of the results of the transformations of that node's children.
    The return value of these methods are the resulting transformations.

    If ``Discard`` is raised in a node's transformation, no data from that node
    will be passed to its parent's transformation.
    """

    def __init__(self):
        super(ForestTransformer, self).__init__()
        # results of transformations
        self.data = dict()
        # used to track parent nodes
        self.node_stack = deque()

    def transform(self, root):
        """Perform a transformation on an SPPF."""
        self.node_stack.append('result')
        self.data['result'] = []
        self.visit(root)
        assert len(self.data['result']) <= 1
        if self.data['result']:
            return self.data['result'][0]

    def transform_symbol_node(self, node, data):
        """Transform a symbol node."""
        return node

    def transform_intermediate_node(self, node, data):
        """Transform an intermediate node."""
        return node

    def transform_packed_node(self, node, data):
        """Transform a packed node."""
        return node

    def transform_token_node(self, node):
        """Transform a ``Token``."""
        return node

    def visit_symbol_node_in(self, node):
        self.node_stack.append(id(node))
        self.data[id(node)] = []
        return node.children

    def visit_packed_node_in(self, node):
        self.node_stack.append(id(node))
        self.data[id(node)] = []
        return node.children

    def visit_token_node(self, node):
        transformed = self.transform_token_node(node)
        if transformed is not Discard:
            self.data[self.node_stack[-1]].append(transformed)

    def _visit_node_out_helper(self, node, method):
        self.node_stack.pop()
        transformed = method(node, self.data[id(node)])
        if transformed is not Discard:
            self.data[self.node_stack[-1]].append(transformed)
        del self.data[id(node)]

    def visit_symbol_node_out(self, node):
        self._visit_node_out_helper(node, self.transform_symbol_node)

    def visit_intermediate_node_out(self, node):
        self._visit_node_out_helper(node, self.transform_intermediate_node)

    def visit_packed_node_out(self, node):
        self._visit_node_out_helper(node, self.transform_packed_node)


class ForestSumVisitor(ForestVisitor):
    """
    A visitor for prioritizing ambiguous parts of the Forest.

    This visitor is used when support for explicit priorities on
    rules is requested (whether normal, or invert). It walks the
    forest (or subsets thereof) and cascades properties upwards
    from the leaves.

    It would be ideal to do this during parsing, however this would
    require processing each Earley item multiple times. That's
    a big performance drawback; so running a forest walk is the
    lesser of two evils: there can be significantly more Earley
    items created during parsing than there are SPPF nodes in the
    final tree.
    """
    def __init__(self):
        super(ForestSumVisitor, self).__init__(single_visit=True)

    def visit(self, root):
        # The plain visitor is a pure bottom-up reduction, so it needs no visitor protocol. Subclasses
        # (which may override the visit methods or on_cycle) and cyclic forests use the generic walk.
        if type(self) is ForestSumVisitor:
            if isinstance(root, SymbolNode):
                if _sum_by_span(root):
                    return
            elif _sum_priorities(root):
                return
        super(ForestSumVisitor, self).visit(root)

    def visit_packed_node_in(self, node):
        yield node.left
        yield node.right

    def visit_symbol_node_in(self, node):
        return iter(node.children)

    def visit_packed_node_out(self, node):
        priority = node.rule.options.priority if not node.parent.is_intermediate and node.rule.options.priority else 0
        priority += getattr(node.right, 'priority', 0)
        priority += getattr(node.left, 'priority', 0)
        node.priority = priority

    def visit_symbol_node_out(self, node):
        node.priority = max(child.priority for child in node.children)

def _sum_by_span(root):
    """``ForestSumVisitor.visit`` for a forest rooted at a symbol node, level by span length.

    A child's span lies inside its parent's, so all nodes of one span length only depend on shorter
    spans and on nodes of the same span (unary chains, ordered topologically). Phase 1 walks the
    forest top down by decreasing length, phase 2 assigns priorities bottom up. On free-threaded
    builds with several CPUs, nodes are owned by thread according to their start (same span, same
    owner) and the threads meet at a barrier after every length. Returns False, having modified
    nothing but loaded paths, when the forest has a cycle, a childless symbol node or an unexpected
    shape; the caller then runs the generic walk.
    """
    base = root.start
    top = root.end
    span = top - base
    if span < 0:
        return False
    size = thread_budget() if span >= GANG_MIN_SPAN else 1
    owners = [((s * 0x9E3779B1) & 0xFFFFFFFF) * size >> 32 for s in range(span + 1)]
    posts = [None] * size       # posts[src][dst][length]: nodes found by src for owner dst
    failed = [False]
    found = [None] * size       # found[w][length]: w's nodes of that length, children first

    def member(w, wait):
        out = [[[] for _ in range(span + 1)] for _ in range(size)]
        posts[w] = out
        token = TokenNode
        packed_cls = PackedNode
        symbol_cls = SymbolNode
        seen = set()        # nodes of this member
        posted = set()      # shorter children already sent to their owner
        levels = [()] * (span + 1)
        found[w] = levels
        fail = False
        for length in range(span, -1, -1):
            if length == span:
                level = [root] if owners[0] == w else []
                seen.update(level)
            else:
                level = []
                for src in range(size):
                    for x in posts[src][w][length]:
                        if x not in seen:
                            seen.add(x)
                            level.append(x)
            same = None
            k = 0
            while not fail and k < len(level):
                x = level[k]
                k += 1
                if not x.paths_loaded:
                    x.load_paths()
                xs = x.start
                xe = x.end
                children = x._children
                if not children:
                    fail = True
                    break
                # No `__class__` loads and one post per distinct child: shared objects are increfed
                # atomically in free-threaded builds, so touching them less is what lets this scale.
                for p in children:
                    if not isinstance(p, packed_cls):
                        fail = True
                        break
                    for c in (p.left, p.right):
                        if c is None:
                            continue
                        if not isinstance(c, symbol_cls):
                            if isinstance(c, token):
                                continue
                            fail = True
                            break
                        cs = c.start
                        ce = c.end
                        if cs < xs or ce > xe:
                            fail = True
                            break
                        if ce - cs == length:
                            if same is None:
                                same = []
                            same.append((x, c))
                            if c not in seen:
                                seen.add(c)
                                level.append(c)
                        elif c not in posted:
                            posted.add(c)
                            out[owners[cs - base]][ce - cs].append(c)
                    if fail:
                        break
            if same is not None and not fail:
                level = _children_first(level, same)
                fail = level is None
            if level:
                levels[length] = level
            wait()
        if fail:
            failed[0] = True
        wait()
        if failed[0]:
            return False
        used = [length for length in range(span + 1) if any(f[length] for f in found)]
        last = len(used) - 1
        for index, length in enumerate(used):
            for x in levels[length]:
                best = None
                for p in x._children:
                    rule_priority = p.rule.options.priority
                    priority = rule_priority if rule_priority and not p.parent.is_intermediate else 0
                    right = p.right
                    if right is not None:
                        priority += getattr(right, 'priority', 0)
                    left = p.left
                    if left is not None:
                        priority += getattr(left, 'priority', 0)
                    p.priority = priority
                    if best is None or priority > best:
                        best = priority
                x.priority = best
            if index < last:
                wait()
        return True

    enabled = gc.isenabled()
    gc.disable()        # allocation-only phase; collections would stop every member
    try:
        return Gang(size).run(member)[0]
    finally:
        if enabled:
            gc.enable()


def _children_first(level, edges):
    """`level` reordered so that same-span children precede their parents; None on a cycle."""
    succ = {}
    for x, c in edges:
        succ.setdefault(x, []).append(c)
    state = {}      # 1: on the stack, 2: done
    order = []
    for start in level:
        if start in state:
            continue
        state[start] = 1
        stack = [(start, iter(succ.get(start, ())))]
        while stack:
            node, it = stack[-1]
            for c in it:
                mark = state.get(c)
                if mark == 1:
                    return None
                if mark is None:
                    state[c] = 1
                    stack.append((c, iter(succ.get(c, ()))))
                    break
            else:
                stack.pop()
                state[node] = 2
                order.append(node)
    return order


def _sum_priorities(root):
    """Iterative equivalent of ``ForestSumVisitor.visit`` for acyclic forests.

    Every node reachable from ``root`` gets the priority the visitor would assign. Returns False,
    leaving all priorities untouched, when a cycle is found; the caller then runs the generic walk
    (whose result depends on the visiting order in that case).
    """
    if isinstance(root, TokenNode):
        return True
    visiting = set()
    value = {}      # id(node) -> computed priority
    out = []        # (node, priority) in completion order
    stack = []      # (node, iterator over its children)
    node = root
    while True:
        if isinstance(node, PackedNode):
            children = iter((node.left, node.right))
        else:
            if not node.paths_loaded:
                node.load_paths()
            children = iter(node._children)
        visiting.add(id(node))
        stack.append((node, children))
        while stack:
            current, children = stack[-1]
            for child in children:
                if child is None or isinstance(child, TokenNode):
                    continue
                child_id = id(child)
                if child_id in visiting:
                    return False
                if child_id not in value:
                    node = child
                    break
            else:
                stack.pop()
                visiting.discard(id(current))
                if isinstance(current, PackedNode):
                    rule_priority = current.rule.options.priority
                    priority = rule_priority if not current.parent.is_intermediate and rule_priority else 0
                    for child in (current.right, current.left):
                        if child is not None:
                            priority += value[id(child)] if id(child) in value else getattr(child, 'priority', 0)
                else:
                    priority = max(value[id(child)] if id(child) in value else child.priority
                                   for child in current._children)
                value[id(current)] = priority
                out.append((current, priority))
                continue
            break
        else:
            break
    for node, priority in out:
        node.priority = priority
    return True


class PackedData():
    """Used in transformationss of packed nodes to distinguish the data
    that comes from the left child and the right child.
    """

    class _NoData():
        pass

    NO_DATA = _NoData()

    def __init__(self, node, data):
        self.left = self.NO_DATA
        self.right = self.NO_DATA
        if data:
            if node.left is not None:
                self.left = data[0]
                if len(data) > 1:
                    self.right = data[1]
            else:
                self.right = data[0]

class ForestToParseTree(ForestTransformer):
    """Used by the earley parser when ambiguity equals 'resolve' or
    'explicit'. Transforms an SPPF into an (ambiguous) parse tree.

    Parameters:
        tree_class: The tree class to use for construction
        callbacks: A dictionary of rules to functions that output a tree
        prioritizer: A ``ForestVisitor`` that manipulates the priorities of ForestNodes
        resolve_ambiguity: If True, ambiguities will be resolved based on
                        priorities. Otherwise, `_ambig` nodes will be in the resulting tree.
        use_cache: If True, the results of packed node transformations will be cached.
    """

    def __init__(self, tree_class=Tree, callbacks=dict(), prioritizer=ForestSumVisitor(), resolve_ambiguity=True, use_cache=True):
        super(ForestToParseTree, self).__init__()
        self.tree_class = tree_class
        self.callbacks = callbacks
        self.prioritizer = prioritizer
        self.resolve_ambiguity = resolve_ambiguity
        self._use_cache = use_cache
        self._cache = {}
        self._on_cycle_retreat = False
        self._cycle_node = None
        self._successful_visits = set()

    def visit(self, root):
        if self.prioritizer:
            self.prioritizer.visit(root)
        super(ForestToParseTree, self).visit(root)
        self._cache = {}

    def on_cycle(self, node, path):
        logger.debug("Cycle encountered in the SPPF at node: %s. "
                "As infinite ambiguities cannot be represented in a tree, "
                "this family of derivations will be discarded.", node)
        self._cycle_node = node
        self._on_cycle_retreat = True

    def _check_cycle(self, node):
        if self._on_cycle_retreat:
            if id(node) == id(self._cycle_node) or id(node) in self._successful_visits:
                self._cycle_node = None
                self._on_cycle_retreat = False
            else:
                return Discard

    def _collapse_ambig(self, children):
        new_children = []
        for child in children:
            if hasattr(child, 'data') and child.data == '_ambig':
                new_children += child.children
            else:
                new_children.append(child)
        return new_children

    def _call_rule_func(self, node, data):
        # called when transforming children of symbol nodes
        # data is a list of trees or tokens that correspond to the
        # symbol's rule expansion
        return self.callbacks[node.rule](data)

    def _call_ambig_func(self, node, data):
        # called when transforming a symbol node
        # data is a list of trees where each tree's data is
        # equal to the name of the symbol or one of its aliases.
        if len(data) > 1:
            return self.tree_class('_ambig', data)
        elif data:
            return data[0]
        return Discard

    def transform_symbol_node(self, node, data):
        if id(node) not in self._successful_visits:
            return Discard
        r = self._check_cycle(node)
        if r is Discard:
            return r
        self._successful_visits.remove(id(node))
        data = self._collapse_ambig(data)
        return self._call_ambig_func(node, data)

    def transform_intermediate_node(self, node, data):
        if id(node) not in self._successful_visits:
            return Discard
        r = self._check_cycle(node)
        if r is Discard:
            return r
        self._successful_visits.remove(id(node))
        if len(data) > 1:
            children = [self.tree_class('_inter', c) for c in data]
            return self.tree_class('_iambig', children)
        return data[0]

    def transform_packed_node(self, node, data):
        r = self._check_cycle(node)
        if r is Discard:
            return r
        if self.resolve_ambiguity and id(node.parent) in self._successful_visits:
            return Discard
        if self._use_cache and id(node) in self._cache:
            return self._cache[id(node)]
        children = []
        assert len(data) <= 2
        data = PackedData(node, data)
        if data.left is not PackedData.NO_DATA:
            if node.left.is_intermediate and isinstance(data.left, list):
                children += data.left
            else:
                children.append(data.left)
        if data.right is not PackedData.NO_DATA:
            children.append(data.right)
        transformed = children if node.parent.is_intermediate else self._call_rule_func(node, children)
        if self._use_cache:
            self._cache[id(node)] = transformed
        return transformed

    def visit_symbol_node_in(self, node):
        super(ForestToParseTree, self).visit_symbol_node_in(node)
        if self._on_cycle_retreat:
            return
        return node.children

    def visit_packed_node_in(self, node):
        self._on_cycle_retreat = False
        to_visit = super(ForestToParseTree, self).visit_packed_node_in(node)
        if not self.resolve_ambiguity or id(node.parent) not in self._successful_visits:
            if not self._use_cache or id(node) not in self._cache:
                return to_visit

    def visit_packed_node_out(self, node):
        super(ForestToParseTree, self).visit_packed_node_out(node)
        if not self._on_cycle_retreat:
            self._successful_visits.add(id(node.parent))

def handles_ambiguity(func):
    """Decorator for methods of subclasses of ``TreeForestTransformer``.
    Denotes that the method should receive a list of transformed derivations."""
    func.handles_ambiguity = True
    return func

class TreeForestTransformer(ForestToParseTree):
    """A ``ForestTransformer`` with a tree ``Transformer``-like interface.
    By default, it will construct a tree.

    Methods provided via inheritance are called based on the rule/symbol
    names of nodes in the forest.

    Methods that act on rules will receive a list of the results of the
    transformations of the rule's children. By default, trees and tokens.

    Methods that act on tokens will receive a token.

    Alternatively, methods that act on rules may be annotated with
    ``handles_ambiguity``. In this case, the function will receive a list
    of all the transformations of all the derivations of the rule.
    By default, a list of trees where each tree.data is equal to the
    rule name or one of its aliases.

    Non-tree transformations are made possible by override of
    ``__default__``, ``__default_token__``, and ``__default_ambig__``.

    Note:
        Tree shaping features such as inlined rules and token filtering are
        not built into the transformation. Positions are also not propagated.

    Parameters:
        tree_class: The tree class to use for construction
        prioritizer: A ``ForestVisitor`` that manipulates the priorities of nodes in the SPPF.
        resolve_ambiguity: If True, ambiguities will be resolved based on priorities.
        use_cache (bool): If True, caches the results of some transformations,
                          potentially improving performance when ``resolve_ambiguity==False``.
                          Only use if you know what you are doing: i.e. All transformation
                          functions are pure and referentially transparent.
    """

    def __init__(self, tree_class=Tree, prioritizer=ForestSumVisitor(), resolve_ambiguity=True, use_cache=False):
        super(TreeForestTransformer, self).__init__(tree_class, dict(), prioritizer, resolve_ambiguity, use_cache)

    def __default__(self, name, data):
        """Default operation on tree (for override).

        Returns a tree with name with data as children.
        """
        return self.tree_class(name, data)

    def __default_ambig__(self, name, data):
        """Default operation on ambiguous rule (for override).

        Wraps data in an '_ambig_' node if it contains more than
        one element.
        """
        if len(data) > 1:
            return self.tree_class('_ambig', data)
        elif data:
            return data[0]
        return Discard

    def __default_token__(self, node):
        """Default operation on ``Token`` (for override).

        Returns ``node``.
        """
        return node

    def transform_token_node(self, node):
        return getattr(self, node.type, self.__default_token__)(node)

    def _call_rule_func(self, node, data):
        name = node.rule.alias or node.rule.options.template_source or node.rule.origin.name
        user_func = getattr(self, name, self.__default__)
        if user_func == self.__default__ or hasattr(user_func, 'handles_ambiguity'):
            user_func = partial(self.__default__, name)
        if not self.resolve_ambiguity:
            wrapper = partial(AmbiguousIntermediateExpander, self.tree_class)
            user_func = wrapper(user_func)
        return user_func(data)

    def _call_ambig_func(self, node, data):
        name = node.s.name
        user_func = getattr(self, name, self.__default_ambig__)
        if user_func == self.__default_ambig__ or not hasattr(user_func, 'handles_ambiguity'):
            user_func = partial(self.__default_ambig__, name)
        return user_func(data)

class ForestToPyDotVisitor(ForestVisitor):
    """
    A Forest visitor which writes the SPPF to a PNG.

    The SPPF can get really large, really quickly because
    of the amount of meta-data it stores, so this is probably
    only useful for trivial trees and learning how the SPPF
    is structured.
    """
    def __init__(self, rankdir="TB"):
        super(ForestToPyDotVisitor, self).__init__(single_visit=True)
        self.pydot = import_module('pydot')
        self.graph = self.pydot.Dot(graph_type='digraph', rankdir=rankdir)

    def visit(self, root, filename):
        super(ForestToPyDotVisitor, self).visit(root)
        try:
            self.graph.write_png(filename)
        except FileNotFoundError as e:
            logger.error("Could not write png: ", e)

    def visit_token_node(self, node):
        graph_node_id = str(id(node))
        graph_node_label = "\"{}\"".format(node.value.replace('"', '\\"'))
        graph_node_color = 0x808080
        graph_node_style = "\"filled,rounded\""
        graph_node_shape = "diamond"
        graph_node = self.pydot.Node(graph_node_id, style=graph_node_style, fillcolor="#{:06x}".format(graph_node_color), shape=graph_node_shape, label=graph_node_label)
        self.graph.add_node(graph_node)

    def visit_packed_node_in(self, node):
        graph_node_id = str(id(node))
        graph_node_label = repr(node)
        graph_node_color = 0x808080
        graph_node_style = "filled"
        graph_node_shape = "diamond"
        graph_node = self.pydot.Node(graph_node_id, style=graph_node_style, fillcolor="#{:06x}".format(graph_node_color), shape=graph_node_shape, label=graph_node_label)
        self.graph.add_node(graph_node)
        yield node.left
        yield node.right

    def visit_packed_node_out(self, node):
        graph_node_id = str(id(node))
        graph_node = self.graph.get_node(graph_node_id)[0]
        for child in [node.left, node.right]:
            if child is not None:
                child_graph_node_id = str(id(child.token if isinstance(child, TokenNode) else child))
                child_graph_node = self.graph.get_node(child_graph_node_id)[0]
                self.graph.add_edge(self.pydot.Edge(graph_node, child_graph_node))
            else:
                #### Try and be above the Python object ID range; probably impl. specific, but maybe this is okay.
                child_graph_node_id = str(randint(100000000000000000000000000000,123456789012345678901234567890))
                child_graph_node_style = "invis"
                child_graph_node = self.pydot.Node(child_graph_node_id, style=child_graph_node_style, label="None")
                child_edge_style = "invis"
                self.graph.add_node(child_graph_node)
                self.graph.add_edge(self.pydot.Edge(graph_node, child_graph_node, style=child_edge_style))

    def visit_symbol_node_in(self, node):
        graph_node_id = str(id(node))
        graph_node_label = repr(node)
        graph_node_color = 0x808080
        graph_node_style = "\"filled\""
        if node.is_intermediate:
            graph_node_shape = "ellipse"
        else:
            graph_node_shape = "rectangle"
        graph_node = self.pydot.Node(graph_node_id, style=graph_node_style, fillcolor="#{:06x}".format(graph_node_color), shape=graph_node_shape, label=graph_node_label)
        self.graph.add_node(graph_node)
        return iter(node.children)

    def visit_symbol_node_out(self, node):
        graph_node_id = str(id(node))
        graph_node = self.graph.get_node(graph_node_id)[0]
        for child in node.children:
            child_graph_node_id = str(id(child))
            child_graph_node = self.graph.get_node(child_graph_node_id)[0]
            self.graph.add_edge(self.pydot.Edge(graph_node, child_graph_node))
