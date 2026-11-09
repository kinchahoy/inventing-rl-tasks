"""Input-free development-environment check; not the private verifier."""

import sys

import sympy

if sys.version_info[:3] != (3, 15, 2) or sympy.__version__ != "1.14.0":
    raise RuntimeError("Unexpected runtime or library version")
print(f"SymPy {sympy.__version__}; GIL enabled: {sys._is_gil_enabled()}")
