"""Private case generators for the Lark task, including the baked timed operations. Parent-only."""

from __future__ import annotations

import random
from typing import Any

_EXPR_GRAMMAR = r"""
start: expr
?expr: expr "+" expr -> add
     | INT          -> number
%import common.INT
%import common.WS
%ignore WS
"""

_NULLABLE_GRAMMAR = r"""
start: item*
item: "a" | "b"
"""

_RIGHT_RECURSIVE_GRAMMAR = r"""
start: "a" start | "a"
"""

_MULTI_START_GRAMMAR = r"""
start: expr
expr: INT
other: NAME
%import common.INT
%import common.CNAME -> NAME
"""


def _parse_case(
    grammar: str,
    text: str,
    ambiguity: str = "resolve",
    **options: Any,
) -> dict[str, Any]:
    return {"kind": "parse", "grammar": grammar, "text": text, "ambiguity": ambiguity, **options}


_LIST_GRAMMAR = r"""
start: value
?value: INT | "[" [value ("," value)*] "]" -> list
%import common.INT
%import common.WS
%ignore WS
"""

_PAREN_GRAMMAR = r"""
start: group
group: "(" (group | ITEM)* ")"
ITEM: /[a-z]+/
%import common.WS
%ignore WS
"""

_KEYWORD_GRAMMAR = r"""
start: stmt+
stmt: IF NAME | NAME
IF.2: "if"
NAME: /[a-z]+/
%import common.WS
%ignore WS
"""

_OPTIONAL_GRAMMAR = r"""
start: "x" [A] "y" [B]
A: "a"
B: "b"
"""

_AMBIGUOUS_STRING_GRAMMAR = r"""
start: s+
s: "a" | "a" "a" | "aa"
"""

_PRIORITY_GRAMMAR = r"""
start: x | y
x.2: INT
y: INT
%import common.INT
"""

_TEMPLATE_GRAMMAR = r"""
start: _seq{WORD} "." _seq{NUM}
_seq{item}: item ("," item)*
!pair: WORD "=" NUM
WORD: /[a-z]+/i
NUM: /\d+/
%import common.WS
%ignore WS
"""

_FLAG_GRAMMAR = r"""
start: (KW | OTHER)+
KW: /select|from/i
OTHER: /[a-z]+/
%ignore " "
"""


def _variant_seed(seed: int, variant: int) -> int:
    return seed ^ (variant * 0x9E3779B1)


def _extra_correctness_cases(rng: random.Random) -> list[dict[str, Any]]:
    def nested(depth: int) -> str:
        if depth == 0 or rng.random() < 0.3:
            return str(rng.randrange(100))
        return "[" + ", ".join(nested(depth - 1) for _ in range(rng.randint(0, 3))) + "]"

    def groups(depth: int) -> str:
        inner = [groups(depth - 1) if depth and rng.random() < 0.5 else rng.choice(("ab", "c", "xyz")) for _ in range(rng.randint(0, 3))]
        return "(" + " ".join(inner) + ")"

    words = " ".join(rng.choice(("if x", "iff", "x", "ifa", "go")) for _ in range(rng.randint(3, 6)))
    pair = f"{rng.choice(('ab', 'Cd'))},{rng.choice(('x', 'Yz'))} . {rng.randrange(9)},{rng.randrange(9)}"
    return [
        _parse_case(_LIST_GRAMMAR, "[" + nested(3) + ", " + nested(2) + "]", options={"lexer": "dynamic"}),
        _parse_case(_LIST_GRAMMAR, "[" + nested(2) + ", ]", options={"lexer": "dynamic"}),
        _parse_case(_PAREN_GRAMMAR, groups(3), options={"keep_all_tokens": True}),
        _parse_case(_PAREN_GRAMMAR, groups(2), "explicit", options={"lexer": "dynamic_complete", "propagate_positions": False}),
        _parse_case(_KEYWORD_GRAMMAR, words, options={"lexer": "basic"}),
        _parse_case(_KEYWORD_GRAMMAR, words + " 9", options={"lexer": "basic"}),
        _parse_case(_OPTIONAL_GRAMMAR, rng.choice(("xy", "xay", "xyb", "xayb")), options={"maybe_placeholders": True}),
        _parse_case(_OPTIONAL_GRAMMAR, "xy", options={"maybe_placeholders": False}),
        _parse_case(_AMBIGUOUS_STRING_GRAMMAR, "a" * rng.randint(3, 5), "explicit", options={"lexer": "dynamic_complete"}),
        _parse_case(_AMBIGUOUS_STRING_GRAMMAR, "a" * rng.randint(3, 5), options={"lexer": "basic"}),
        _parse_case(_PRIORITY_GRAMMAR, str(rng.randrange(10, 99)), options={"priority": "normal"}),
        _parse_case(_TEMPLATE_GRAMMAR, pair),
        _parse_case(_FLAG_GRAMMAR, "SeLeCt a from b", options={"lexer": "dynamic"}),
        _parse_case(_EXPR_GRAMMAR, "1 + (2", options={"lexer": "dynamic_complete"}),
    ]


def correctness_cases(seed: int) -> list[dict[str, Any]]:
    rng = random.Random(seed ^ 0x5A17)
    digits = [str(rng.randrange(1, 10)) for _ in range(4)]
    expr = " + ".join(digits)
    invalid = rng.choice(("2 + + 3", "2 +", "+ 3"))
    return [
        _parse_case(_EXPR_GRAMMAR, expr, "resolve"),
        _parse_case(_EXPR_GRAMMAR, expr, "explicit"),
        _parse_case(_NULLABLE_GRAMMAR, ""),
        _parse_case(_NULLABLE_GRAMMAR, "abba"),
        _parse_case(_RIGHT_RECURSIVE_GRAMMAR, "a" * rng.randint(5, 13)),
        _parse_case(_EXPR_GRAMMAR, invalid),
        _parse_case(_MULTI_START_GRAMMAR, str(rng.randrange(10, 100)), starts=["start", "other"], start="start"),
        _parse_case(_MULTI_START_GRAMMAR, "name" + str(rng.randrange(1, 9)), starts=["start", "other"], start="other"),
        *_extra_correctness_cases(rng),
        {"kind": "forest_transform", "grammar": _EXPR_GRAMMAR, "text": expr, "transformer": "parse_tree", "record_trace": True},
        {"kind": "forest_transform", "grammar": _EXPR_GRAMMAR, "text": expr, "transformer": "tree", "record_trace": True},
        {"kind": "forest_visit", "grammar": _EXPR_GRAMMAR, "text": expr, "single_visit": False, "record_trace": True},
        {"kind": "forest_visit", "grammar": _NULLABLE_GRAMMAR, "text": "abba", "single_visit": True, "record_trace": True},
    ]


def operation_cases(seed: int, variant: int = 0) -> dict[str, dict[str, Any]]:
    """The baked timed operations, keyed by label (see config.json "operations").

    Sizes come from `seed` (identical across variants); only token values differ per `variant`.
    The selection was made once by the task authors from baseline profiles (AUTHOR.md) and is not
    recomputed at verification time.
    """
    operand_count = random.Random(seed).randint(70, 74)  # >= ~115 ms original parse
    rng = random.Random(_variant_seed(seed ^ 0xB4C3, variant))
    text = "+".join(str(rng.randrange(1, 10)) for _ in range(operand_count))
    return {
        "end_to_end:parse": _parse_case(_EXPR_GRAMMAR, text),
        "forest_to_parse_tree": {
            "kind": "forest_transform", "grammar": _EXPR_GRAMMAR, "text": text,
            "transformer": "parse_tree", "record_trace": False,
        },
    }
