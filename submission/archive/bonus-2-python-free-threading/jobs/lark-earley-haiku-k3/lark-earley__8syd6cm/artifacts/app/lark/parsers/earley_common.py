"""This module implements useful building blocks for the Earley parser
"""

from ..utils import OrderedSet


class IndexedColumn(OrderedSet):
    """An ordered Earley column that also indexes its items by the symbol they expect.

    Items are kept in insertion order exactly as in ``OrderedSet``; ``by_expect``
    maps each expected symbol to the items (in insertion order) expecting it, so the
    completer does not need to scan the whole column.
    """
    __slots__ = ('by_expect',)

    def __init__(self):
        OrderedSet.__init__(self)
        self.by_expect = {}

    def add(self, item):
        d = self.d
        if item not in d:
            d[item] = None
            expect = item.expect
            if expect is not None:
                lst = self.by_expect.get(expect)
                if lst is None:
                    self.by_expect[expect] = [item]
                else:
                    lst.append(item)


class Item:
    "An Earley Item, the atom of the algorithm."

    __slots__ = ('s', 'rule', 'ptr', 'start', 'is_complete', 'expect', 'previous', 'node', '_hash')
    def __init__(self, rule, ptr, start):
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
        if self is other:
            return True
        if self.start != other.start or self.s != other.s:
            return False
        return self.rule is other.rule or self.rule == other.rule

    def __hash__(self):
        return self._hash

    def __repr__(self):
        before = ( expansion.name for expansion in self.rule.expansion[:self.ptr] )
        after = ( expansion.name for expansion in self.rule.expansion[self.ptr:] )
        symbol = "{} ::= {}* {}".format(self.rule.origin.name, ' '.join(before), ' '.join(after))
        return '%s (%d)' % (symbol, self.start)


# class TransitiveItem(Item):
#   ...   # removed at commit 4c1cfb2faf24e8f8bff7112627a00b94d261b420
