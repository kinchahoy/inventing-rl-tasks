"""Input-free development-environment check; not the private verifier."""

import sys

import lark

if sys.version_info[:3] != (3, 15, 2) or lark.__version__ != "1.3.1":
    raise RuntimeError("Unexpected runtime or library version")
print(f"Lark {lark.__version__}; GIL enabled: {sys._is_gil_enabled()}")
