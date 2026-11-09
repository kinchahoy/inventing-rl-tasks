"""Private case generators for the SymPy task, including the baked timed operations. Parent-only."""

from __future__ import annotations

import random
from typing import Any

def _jordan_matrix(
    seed: int, order: int, *, integers: bool = False, singular: bool = False, variant: int = 0,
) -> Any:
    """Block structure and spectrum come from `seed`; the similarity transform differs per `variant`."""
    from sympy import Matrix, Rational

    rng = random.Random(seed)
    jordan = Matrix.zeros(order)
    index = 0
    block = 0
    while index < order:
        width = min(rng.choice((1, 2, 3)), order - index)
        if singular and block == 0:
            eigenvalue = 0
        else:
            numerator = rng.choice((-3, -1, 2, 5))
            denominator = 1 if integers else rng.choice((1, 2, 3))
            eigenvalue = Rational(numerator, denominator)
        for offset in range(width):
            jordan[index + offset, index + offset] = eigenvalue
            if offset + 1 < width:
                jordan[index + offset, index + offset + 1] = 1
        index += width
        block += 1

    rng = random.Random(seed ^ (variant * 0x9E3779B1))
    # Apply A <- E*A*E^-1 using elementary unimodular row/column updates.
    # This produces a known spectrum without constructing an inverse or solving the task.
    for _ in range(7 * order):
        row, column = rng.sample(range(order), 2)
        factor = rng.choice((-2, -1, 1, 2))
        jordan.row_op(row, lambda value, j, factor=factor, column=column: value + factor * jordan[column, j])
        jordan.col_op(column, lambda value, i, factor=factor, row=row: value - factor * jordan[i, row])
    return jordan


def _rows(matrix: Any) -> list[list[str]]:
    return [[str(matrix[row, column]) for column in range(matrix.cols)] for row in range(matrix.rows)]


def _state_case(
    seed: int, order: int, variant: int = 0, *, inputs: int = 2, outputs: int = 2,
    integers: bool = False, singular: bool = False,
) -> dict[str, Any]:
    from sympy import Matrix

    rng = random.Random(seed ^ (order * 7919) ^ (variant * 0x9E3779B1))
    state = _jordan_matrix(seed, order, integers=integers, singular=singular, variant=variant)
    b = Matrix(order, inputs, lambda _r, _c: rng.choice((-3, -2, -1, 1, 2, 3)))
    c = Matrix(outputs, order, lambda _r, _c: rng.choice((-3, -2, -1, 1, 2, 3)))
    d = Matrix(outputs, inputs, lambda _r, _c: rng.choice((-2, -1, 0, 1, 2)))
    initial = Matrix(order, 1, lambda _r, _c: rng.choice((-3, -2, -1, 1, 2, 3)))
    forcing = Matrix(inputs, 1, lambda _r, _c: rng.choice((-2, -1, 1, 2)))
    return {
        "kind": "dsolve",
        "A": _rows(state),
        "B": _rows(b),
        "C": _rows(c),
        "D": _rows(d),
        "initial": _rows(initial),
        "input": _rows(forcing),
        "var": "tau",
    }


def _integer_matrix_case(seed: int, order: int, op: str) -> dict[str, Any]:
    matrix = _jordan_matrix(
        seed,
        order,
        integers=True,
        singular="nullspace" in op or op.endswith(".rref") or op.endswith(".rref_den"),
    )
    case: dict[str, Any] = {
        "kind": "operation",
        "op": op,
        "A": _rows(matrix),
        "B": [[str((row % 5) - 2 or 1)] for row in range(order)],
        "domain": "QQ" if op in {"domainmatrix.inv", "domainmatrix.inv_den"} else "ZZ",
    }
    return case


def operation_cases(seed: int, variant: int = 0) -> dict[str, dict[str, Any]]:
    """The baked timed operations, keyed by label (see config.json "operations").

    Structure and sizes come from `seed`; only the similarity transform and vectors differ per `variant`.
    The selection was made once by the task authors from baseline profiles (AUTHOR.md) and is not
    recomputed at verification time. The two constituent fixtures are derived in the adapter from a
    state-space case: `doit` of one `linodesolve(..., doit=False)` solution entry, and the matrix-vector
    product of the Jordan-chain coefficient matrix with the forcing term.
    """
    large = _state_case(seed + 2 * 104729, 10, variant)
    return {
        "end_to_end:dsolve_8": _state_case(seed, 8, variant),
        "end_to_end:dsolve_10": _state_case(seed + 104729, 10, variant),
        "solution_entry_doit": {**large, "kind": "linode_doit", "entry": 3},
        "jordan_chain_product": {**large, "kind": "linode_product"},
    }


def _extra_correctness_cases(seed: int) -> list[dict[str, Any]]:
    """Small varied state-space systems and StateSpace methods (each well under 200 ms with the original)."""
    rng = random.Random(seed ^ 0x51DE)

    def system(order: int, **options: Any) -> dict[str, Any]:
        return _state_case(rng.randrange(1 << 30), order, rng.randrange(4), **options)

    def dsolve(case: dict[str, Any], **overrides: Any) -> dict[str, Any]:
        return {**case, **overrides}

    def method(name: str, case: dict[str, Any], **extra: Any) -> dict[str, Any]:
        return {"kind": "statespace_method", "method": name, **{k: case[k] for k in "ABCD"}, **extra}

    a2 = system(2, integers=True)
    a3 = system(3, singular=True)
    a4 = system(4, integers=True, inputs=1, outputs=1)
    a5 = system(5, singular=True, integers=True, inputs=1, outputs=3)
    b3 = system(3, inputs=1, outputs=1)
    other = system(3, inputs=1, outputs=1)
    return [
        dsolve(a2),
        dsolve(a3, initial=None),
        dsolve(a3, input=None, var="s"),
        dsolve(a4),
        dsolve(a5),
        dsolve(b3, initial=None, input=None),
        dsolve(a2, var="x_1"),
        method("controllability_matrix", a4),
        method("observability_matrix", a3),
        method("is_controllable", a5),
        method("is_observable", a2),
        method("controllable_subspace", a3),
        method("observable_subspace", a4),
        method("state_matrix", b3),
        method("shape", a5),
        method("neg", b3),
        method("add", b3, other={k: other[k] for k in "ABCD"}),
        method("sub", b3, other={k: other[k] for k in "ABCD"}),
        method("mul", b3, other={k: other[k] for k in "ABCD"}),
        method("add", b3, other={k: a2[k] for k in "ABCD"}),
        method("evalf", a2),
    ]


def correctness_cases(seed: int) -> list[dict[str, Any]]:
    """Small edge cases for exact results, failures, and input-preservation checks."""
    cases: list[dict[str, Any]] = []
    cases.extend(_extra_correctness_cases(seed))
    cases.extend(
        [
            {
                "kind": "dsolve",
                "A": [["0", "0"], ["0", "0"]],
                "B": [["1"], ["-2"]],
                "C": [["1", "2"]],
                "D": [["0"]],
                "initial": None,
                "input": None,
                "var": "t",
            },
            {
                "kind": "dsolve",
                "A": [["2", "1"], ["0", "2"]],
                "B": [["1"], ["-1"]],
                "C": [["1", "-2"]],
                "D": [["1"]],
                "initial": [["3"], ["-1"]],
                "input": [["2"]],
                "var": "t",
            },
            {
                "kind": "dsolve",
                "A": [["q", "1"], ["0", "q"]],
                "B": [["1"], ["q"]],
                "C": [["q", "1"]],
                "D": [["0"]],
                "initial": [["1"], ["2"]],
                "input": [["1"]],
                "var": "t",
            },
            {"kind": "dsolve", "A": [["1"]], "B": [["1"]], "C": [["1"]], "D": [["0"]], "initial": None, "input": None, "var": 3},
            {"kind": "dsolve", "A": [["1", "0"], ["0", "-1"]], "B": [["1"], ["0"]], "C": [["1", "1"]], "D": [["0"]], "initial": [["1"]], "input": [["1"]], "var": "t"},
            {"kind": "dsolve", "A": [["1", "0"], ["0", "-1"]], "B": [["1"], ["0"]], "C": [["1", "1"]], "D": [["0"]], "initial": [["1"], ["2"]], "input": [["1"], ["2"]], "var": "t"},
            {"kind": "dsolve_constructor_error", "A": [["1", "0", "2"], ["0", "1", "3"]], "B": [["1"], ["1"]], "C": [["1", "1", "1"]], "D": [["0"]]},
        ]
    )
    cases.extend(
        [
            {"kind": "operation", "op": "matrix.inv", "A": [["1", "2"], ["2", "4"]]},
            {"kind": "operation", "op": "matrix.rref", "A": [["1", "2", "3"], ["2", "4", "6"]]},
            {"kind": "operation", "op": "matrix.charpoly", "A": [["1", "2", "3"], ["0", "1", "2"]]},
            _integer_matrix_case(seed + 71, 3, "matrix.nullspace"),
            _integer_matrix_case(seed + 73, 3, "matrix.eigenvals"),
            _integer_matrix_case(seed + 79, 3, "matrix.jordan_form"),
            {"kind": "operation", "op": "matrix.rank", "A": [["0", "1"], ["0", "2"]]},
            {"kind": "operation", "op": "domainmatrix.inv", "domain": "QQ", "A": [["1/2", "1"], ["1", "3/4"]]},
            {"kind": "operation", "op": "domainmatrix.rref_den", "domain": "GF:7", "storage": "sparse", "A": [["1", "0", "2"], ["0", "0", "3"], ["2", "0", "4"]]},
            {"kind": "operation", "op": "solver.linsolve", "A": [["1", "1"], ["2", "2"]], "B": [["1"], ["3"]]},
        ]
    )
    return cases
