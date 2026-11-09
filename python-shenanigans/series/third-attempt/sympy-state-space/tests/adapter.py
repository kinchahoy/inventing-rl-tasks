"""Worker-side adapter: builds the objects for one invocation and encodes results.

Contains no case generators, pools, seeds, thresholds, or checks. It is readable by the submitted
code and is also used unchanged by the trusted parent and the reference worker.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

def _expression(value: Any) -> Any:
    from sympy import Symbol, sympify

    return sympify(value, locals={"q": Symbol("q")})


def _matrix(rows: list[list[Any]], *, immutable: bool = False) -> Any:
    from sympy import ImmutableMatrix, Matrix

    data = [[_expression(value) for value in row] for row in rows]
    return ImmutableMatrix(data) if immutable else Matrix(data)


def _domain_matrix(rows: list[list[Any]], name: str) -> Any:
    from sympy import GF, QQ, ZZ
    from sympy.polys.matrices import DomainMatrix

    domain = GF(int(name.split(":", 1)[1])) if name.startswith("GF:") else (QQ if name == "QQ" else ZZ)
    entries = [[domain.from_sympy(_expression(value)) for value in row] for row in rows]
    return DomainMatrix(entries, (len(entries), len(entries[0])), domain).to_dense()


def prepare(case: dict[str, Any]) -> tuple[Callable[[], Any], Callable[[], Any]]:
    """Prepare reusable objects outside the timer; return one API call and an input snapshot."""
    kind = case["kind"]
    if kind == "dsolve_constructor_error":
        from sympy.physics.control import StateSpace

        matrices = tuple(_matrix(case[key], immutable=True) for key in ("A", "B", "C", "D"))
        return lambda: StateSpace(*matrices), lambda: {key: encode(value) for key, value in zip(("A", "B", "C", "D"), matrices, strict=True)}

    if kind == "dsolve":
        from sympy import Symbol
        from sympy.physics.control import StateSpace

        a, b, c, d = (_matrix(case[key], immutable=True) for key in ("A", "B", "C", "D"))
        initial = None if case["initial"] is None else _matrix(case["initial"], immutable=True)
        forcing = None if case["input"] is None else _matrix(case["input"], immutable=True)
        variable = case["var"] if not isinstance(case["var"], str) else Symbol(case["var"])
        system = StateSpace(a, b, c, d)

        def call() -> Any:
            return system.dsolve(initial_conditions=initial, input_vector=forcing, var=variable)

        return call, lambda: {"A": encode(a), "B": encode(b), "C": encode(c), "D": encode(d), "initial": encode(initial), "input": encode(forcing)}

    if kind == "statespace_method":
        from sympy.physics.control import StateSpace

        def build(spec: dict[str, Any]) -> Any:
            return StateSpace(*(_matrix(spec[key], immutable=True) for key in ("A", "B", "C", "D")))

        system = build(case)
        other = build(case["other"]) if "other" in case else None
        method = case["method"]

        def call_method() -> Any:
            if method in ("add", "sub", "mul"):
                return {"add": system.__add__, "sub": system.__sub__, "mul": system.__mul__}[method](other)
            if method == "neg":
                return -system
            if method == "evalf":
                return system.evalf()
            attribute = getattr(system, method)
            return attribute() if callable(attribute) else attribute

        return call_method, lambda: encode(system)

    if kind in ("linode_doit", "linode_product"):
        return _linode_fixture(case)

    op = case["op"]
    if op == "solver.linsolve":
        from sympy import linsolve

        matrix = _matrix(case["A"])
        rhs = _matrix(case["B"])
        return lambda: linsolve((matrix, rhs)), lambda: {"A": encode(matrix), "B": encode(rhs)}
    if op.startswith("matrix."):
        matrix = _matrix(case["A"])
        function_name = op.removeprefix("matrix.")
        method = getattr(matrix, function_name)
        return method, lambda: encode(matrix)

    domain_matrix = _domain_matrix(case["A"], case.get("domain", "ZZ"))
    if case.get("storage") == "sparse":
        domain_matrix = domain_matrix.to_sparse()
    function_name = op.removeprefix("domainmatrix.")
    if function_name == "solve_den":
        rhs = _domain_matrix(case["B"], case.get("domain", "ZZ"))
        return lambda: domain_matrix.solve_den(rhs), lambda: {"A": encode(domain_matrix), "B": encode(rhs)}
    method = getattr(domain_matrix, function_name)
    return method, lambda: encode(domain_matrix)


def _linode_fixture(case: dict[str, Any]) -> tuple[Callable[[], Any], Callable[[], Any]]:
    """Constituent operations of the state-space solve, built exactly as `linodesolve` builds them (untimed)."""
    from sympy import Dummy, Symbol, simplify
    from sympy.solvers.ode.systems import linodesolve, matrix_exp_jordan_form

    a, b = _matrix(case["A"], immutable=True), _matrix(case["B"], immutable=True)
    forcing = b * _matrix(case["input"], immutable=True)
    t = Symbol(case["var"])
    if case["kind"] == "linode_doit":
        entry = linodesolve(A=a, t=t, b=forcing, type="type2", doit=False)[case["entry"]]
        # Replace the arbitrary-constant Dummies (process-order dependent names) by stable symbols.
        constants = sorted(entry.atoms(Dummy), key=lambda d: d.dummy_index)
        entry = entry.xreplace({d: Symbol(f"C{i}") for i, d in enumerate(constants)})
        return entry.doit, lambda: encode(entry)
    p, j = matrix_exp_jordan_form(a, t)
    left = j.subs(t, -t) * simplify(p).inv()
    return lambda: left * forcing, lambda: {"left": encode(left), "forcing": encode(forcing)}


def encode(value: Any) -> Any:
    """Stable, type-aware encoding of exact SymPy return values for differential comparison."""
    from sympy import Basic, srepr
    from sympy.matrices.matrixbase import MatrixBase
    from sympy.polys.matrices import DomainMatrix

    if value is None or isinstance(value, (str, int, bool)):
        return {"type": type(value).__name__, "value": value}
    if isinstance(value, float):
        return {"type": "float", "hex": value.hex()}
    if isinstance(value, DomainMatrix):
        return {
            "type": "DomainMatrix",
            "shape": list(value.shape),
            "domain": str(value.domain),
            "entries": encode(value.to_Matrix()),
        }
    if isinstance(value, MatrixBase):
        return {
            "type": type(value).__name__,
            "shape": list(value.shape),
            "entries": [[srepr(value[row, column]) for column in range(value.cols)] for row in range(value.rows)],
        }
    if isinstance(value, Basic):
        return {"type": type(value).__name__, "srepr": srepr(value)}
    if isinstance(value, dict):
        return {"type": "dict", "items": [[encode(key), encode(item)] for key, item in value.items()]}
    if isinstance(value, (tuple, list)):
        return {"type": type(value).__name__, "items": [encode(item) for item in value]}
    if isinstance(value, (set, frozenset)):
        return {"type": type(value).__name__, "items": sorted((encode(item) for item in value), key=repr)}
    return {"type": type(value).__name__, "repr": repr(value)}
