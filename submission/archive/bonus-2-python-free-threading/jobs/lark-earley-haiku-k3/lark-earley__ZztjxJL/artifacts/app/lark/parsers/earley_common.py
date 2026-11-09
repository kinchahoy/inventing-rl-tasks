"""This module implements useful building blocks for the Earley parser
"""


class Item:
    "An Earley Item, the atom of the algorithm."

    __slots__ = ('s', 'rule', 'ptr', 'start', 'is_complete', 'expect', 'previous', 'node', '_hash')
    def __init__(self, rule, ptr, start):
        expansion = rule.expansion
        is_complete = len(expansion) == ptr
        self.is_complete = is_complete
        self.rule = rule    # rule
        self.ptr = ptr      # ptr
        self.start = start  # j
        self.node = None    # w
        if is_complete:
            self.s = rule.origin
            self.expect = None
            # hash(self.s) == hash(origin.name), see Symbol.__hash__
            s_hash = hash(rule.origin.name)
        else:
            self.s = (rule, ptr)
            self.expect = expansion[ptr]
            # hash((rule, ptr)) == hash((hash(rule), ptr)), and hash(rule) == rule._hash
            s_hash = hash((rule._hash, ptr))
        self.previous = expansion[ptr - 1] if ptr > 0 and len(expansion) else None
        # Same value as hash((self.s, self.start, self.rule)), computed from the
        # component hashes without calling Python-level __hash__ methods.
        self._hash = hash((s_hash, start, rule._hash))

    def advance(self):
        return Item(self.rule, self.ptr + 1, self.start)

    def __eq__(self, other):
        if self is other:
            return True
        if self.rule is other.rule:
            # Same rule object: the symbols are equal iff the dot positions are equal.
            return self.ptr == other.ptr and self.start == other.start
        return self.s == other.s and self.start == other.start and self.rule == other.rule

    def __hash__(self):
        return self._hash

    def __repr__(self):
        before = ( expansion.name for expansion in self.rule.expansion[:self.ptr] )
        after = ( expansion.name for expansion in self.rule.expansion[self.ptr:] )
        symbol = "{} ::= {}* {}".format(self.rule.origin.name, ' '.join(before), ' '.join(after))
        return '%s (%d)' % (symbol, self.start)


# class TransitiveItem(Item):
#   ...   # removed at commit 4c1cfb2faf24e8f8bff7112627a00b94d261b420
