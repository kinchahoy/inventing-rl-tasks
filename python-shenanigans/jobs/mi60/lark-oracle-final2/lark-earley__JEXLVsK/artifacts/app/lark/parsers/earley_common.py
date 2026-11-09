"""This module implements useful building blocks for the Earley parser
"""

from itertools import count


class Item:
    "An Earley Item, the atom of the algorithm."

    __slots__ = ('s', 'rule', 'ptr', 'start', 'is_complete', 'expect', 'previous', 'node', '_hash', 'l')
    def __init__(self, rule, ptr, start):
        self.l = None       # LR0 position record; only set for items made by `make_item`
        self.is_complete = len(rule.expansion) == ptr
        self.rule = rule    # rule
        self.ptr = ptr      # ptr
        self.start = start  # j
        self.node = None    # w
        if self.is_complete:
            self.s = rule.origin
            self.expect = None
            self.previous = rule.expansion[ptr - 1] if ptr > 0 and len(rule.expansion) else None
        else:
            self.s = (rule, ptr)
            self.expect = rule.expansion[ptr]
            self.previous = rule.expansion[ptr - 1] if ptr > 0 and len(rule.expansion) else None
        self._hash = hash((self.s, self.start, self.rule))

    def advance(self):
        return Item(self.rule, self.ptr + 1, self.start)

    def __eq__(self, other):
        return self is other or (self.s == other.s and self.start == other.start and self.rule == other.rule)

    def __hash__(self):
        return self._hash

    def __repr__(self):
        before = ( expansion.name for expansion in self.rule.expansion[:self.ptr] )
        after = ( expansion.name for expansion in self.rule.expansion[self.ptr:] )
        symbol = "{} ::= {}* {}".format(self.rule.origin.name, ' '.join(before), ' '.join(after))
        return '%s (%d)' % (symbol, self.start)


class LR0:
    """Static, shared description of one dotted position (rule, ptr).

    `nid` identifies the SPPF node a position maps to: positions inside a rule have their own node,
    all completed positions of the same origin share one (matching the node label `(s, start, end)`).
    """
    __slots__ = ('rule', 'ptr', 'complete', 's', 'expect', 'ename', 'oname', 'eterm', 'previous', 'h', 'nid', 'next')


def build_lr0(rules, terminals):
    """Map each rule to the chain of its LR0 positions (index 0 .. len(expansion))."""
    ids = count()
    complete_nid = {}
    first = {}
    for rule in rules:
        expansion = list(rule.expansion)
        size = len(expansion)
        chain = []
        for ptr in range(size + 1):
            pos = LR0()
            pos.rule = rule
            pos.ptr = ptr
            pos.complete = ptr == size
            pos.h = next(ids)
            pos.previous = expansion[ptr - 1] if ptr > 0 and size else None
            pos.next = None
            if pos.complete:
                pos.s = rule.origin
                pos.expect = pos.ename = None
                pos.eterm = False
                pos.oname = rule.origin.name
                if pos.oname not in complete_nid:
                    complete_nid[pos.oname] = next(ids)
                pos.nid = complete_nid[pos.oname]
            else:
                pos.s = (rule, ptr)
                pos.expect = expansion[ptr]
                pos.ename = pos.expect.name
                pos.eterm = pos.expect in terminals
                pos.oname = None
                pos.nid = next(ids)
            if chain:
                chain[-1].next = pos
            chain.append(pos)
        first[rule] = chain[0]
    return first


_new = object.__new__


def make_item(pos, start):
    """Equivalent of `Item(pos.rule, pos.ptr, start)` without recomputing the static parts."""
    item = _new(Item)
    item.s = pos.s
    item.rule = pos.rule
    item.ptr = pos.ptr
    item.start = start
    item.node = None
    item.is_complete = pos.complete
    item.expect = pos.expect
    item.previous = pos.previous
    item._hash = (pos.h * 1000003) ^ start
    item.l = pos
    return item


# class TransitiveItem(Item):
#   ...   # removed at commit 4c1cfb2faf24e8f8bff7112627a00b94d261b420
