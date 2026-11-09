"""Generate the lean-to-isabelle Harbor tasks from the sources in this directory.

- Quantum tasks (TASKS): fully generated from the checked oracles here. Each gets a trusted Quantum_Basics.thy, a
  `sorry` stub of the oracle's theorems, a Canonical.thy that parses the statements where only Quantum_Basics is
  visible, a Check.thy comparing the submitted theorems to them term by term, verify.py (from
  verify_template.py) and, if `<Theory>.lean` exists here, a Lean reference proof.
- Group tasks (GROUP): hand-written; only their tests/verify.py is rendered from the same template.
- `metis` and `meson` are allowed in every task (banning them was artificial difficulty); `smt` stays banned.

Archived tasks (../../lean-to-isabelle-archive/) are frozen and not generated.
Usage: uv run lean-to-isabelle/quantum-src/gen.py
"""

import re
import shutil
from pathlib import Path

SRC = Path(__file__).resolve().parent
REPO = SRC.parent
# task dir -> (theory = oracle file stem, theorems the agent must prove, line cap, instruction title).
TASKS: dict[str, tuple[str, list[str], int, str]] = {
    "sonnet-hard-candidate-shor-general": (
        "Shor_General",
        ["shor_factor", "shor_peak", "shor_general_success"],
        700,
        "Shor's algorithm for a general period",
    ),
    "sonnet-hard-candidate-shor-general-paper": (
        "Shor_General",
        ["shor_factor", "shor_peak", "shor_general_success"],
        700,
        "Shor's algorithm for a general period",
    ),
}
# Reference shipped in environment/ (default: `<Theory>.lean` if it exists). A `.pdf` is a human-written paper (needs poppler-utils).
REFERENCE: dict[str, str] = {"sonnet-hard-candidate-shor-general-paper": "references/Lin_Shor_QFT_2013.pdf"}
# Hand-written group tasks: dir -> (theory, theorems, line cap).
GROUP: dict[str, tuple[str, list[str], int]] = {
    "haiku-hard-cauchy": ("Cauchy", ["cauchy"], 600),
}
METIS = {"metis", "meson"}
DIFFICULTY: dict[str, tuple[str, str]] = {
    "sonnet-hard-candidate-shor-general": (
        "sonnet-hard-candidate",
        "oracle 1.0 and nop 0.0 (jobs/lean-oracle-final, jobs/lean-nop-final); no model trial yet with the current setup (metis allowed, 60 min, cap ~1.5x oracle); earlier setup: claude-haiku-5.5 0/1 (jobs/2026-11-03__00-52-43, 30 min, before the Lean reference)",
    ),
    "sonnet-hard-candidate-shor-general-paper": (
        "sonnet-hard-candidate",
        "estimated: shor-general with a human-written paper (Lin, McGill 2013) instead of a Lean proof; no model trial yet",
    ),
}
DESCRIPTIONS = {
    "shor_core": "**Quantum core.** For an `r`-periodic state on `Z_N` with `r | N`, the state is a unit "
    "vector and after the QFT every outcome `j < N` has probability exactly `1/r` if `(N div r) dvd j`, "
    "else `0`.",
    "shor_factor": "**Classical step.** If `r` is the order of `a` modulo `n > 1`, `r` is even and "
    "`a^(r/2) mod n != n - 1`, then `gcd (a^(r/2) - 1) n` is a nontrivial factor of `n`.",
    "shor_success": "**Period recovery.** One run (QFT, measure `j`, output `N div gcd j N`) returns `r` "
    "with probability exactly `phi(r)/r`, where `phi(r) = card {k. k < r \\<and> coprime k r}`.",
    "shor_peak": "**Peaks for a general period.** For any period `0 < r < N` (not necessarily dividing `N`) "
    "and offset `x0 < r`, the periodic state is a unit vector, and every outcome `j < N` within `r/2` of a "
    "multiple of `N/r` (that is, `2 * |j * r - c * N| <= r` for some integer `c`) has probability at least "
    "`4 / (pi^2 * r) * (1 - r/N)^3`.",
    "shor_general_success": "**Period recovery for a general period.** If `r^2 < N`, one run (QFT, measure "
    "`j`, output `recover N j`, the least denominator of a fraction within `1/(2N)` of `j/N`) returns `r` "
    "with probability at least `4 / pi^2 * phi(r)/r * (1 - r/N)^3`, where "
    "`phi(r) = card {c. c < r \\<and> coprime c r}`.",
}


def forbidden_text() -> str:
    return "`apply`-style scripts (`apply`, `done`, `back`, `defer`, `prefer`), `sorry`, `oops`, `smt`, `sledgehammer`, `nitpick`, `nunchaku`, `quickcheck`, `axiomatization`, `axioms`, `oracle`, `skip_proofs`, `quick_and_dirty`, `tactic`, `raw_tactic`, and every ML, setup, syntax and translation command (`ML`, `ML_*`, `SML_*`, `setup`, `local_setup`, `method_setup`, `attribute_setup`, `simproc_setup`, `declaration`, `syntax_declaration`, `syntax`, `no_syntax`, `translations`, `*_translation`). Comments, cartouches and strings are not scanned"


ALLOWED_TEXT = "Ordinary methods such as `metis`, `meson`, `rule`, `simp`,"


def sandbox_text(theory: str) -> str:
    """Plain facts about the sandbox, shared by every task (the hand-written group instructions repeat it)."""
    return f"""## Working in the sandbox

- Only `/app/{theory}.thy` is graded; nothing else in the sandbox is kept. Keep your current best
  version there as you go.
- You have 60 minutes.
- `isabelle build` prints nothing until the session finishes, and a looping `simp`/`auto`/`blast` can
  run indefinitely. Wrap builds in `timeout`, e.g. `timeout 300 isabelle build -o threads=2 -D /app`.
  The grader allows 8 minutes for the whole build.
- `isabelle process` may not exit on its own; use `isabelle build`.
"""


def header_of(source: str, name: str) -> str:
    match = re.search(rf"^theorem {name}:.*?(?=^proof)", source, flags=re.DOTALL | re.MULTILINE)
    assert match is not None, name
    return match.group(0).rstrip()


def canonical_prop(header: str) -> str:
    parts = re.findall(r'"((?:\\.|[^"\\])*)"', header)
    return " \\<Longrightarrow> ".join(f"({p})" for p in parts)


def render_verify(theory: str, imports: set[str], trusted: tuple[str, ...], cap: int, theorems: list[str]) -> str:
    template = (SRC / "verify_template.py").read_text()
    return (
        template.replace("@@THEORY@@", theory)
        .replace("@@ALLOWED_IMPORTS@@", repr(sorted(imports)))
        .replace("@@TRUSTED@@", repr(trusted))
        .replace("@@MAX_LINES@@", str(cap))
        .replace("@@THEOREMS@@", repr(theorems))
        .replace("@@ALLOWED_METHODS@@", repr(sorted(METIS)))
    )


def write_quantum(task: str, theory: str, theorems: list[str], cap: int, title: str) -> None:
    root = REPO / task
    if root.exists():
        shutil.rmtree(root)
    for sub in ("environment", "tests", "solution"):
        (root / sub).mkdir(parents=True)
    cauchy = REPO / "haiku-hard-cauchy"
    basics = (SRC / "Quantum_Basics.thy").read_text()
    oracle = (SRC / f"{theory}.thy").read_text()
    lean = SRC / REFERENCE.get(task, f"{theory}.lean")
    headers = {n: header_of(oracle, n) for n in theorems}

    stub = f"theory {theory}\n  imports Quantum_Basics\nbegin\n\n"
    stub += "".join(f"{headers[n]}\n  sorry\n\n" for n in theorems) + "end\n"
    (root / "environment" / f"{theory}.thy").write_text(stub)
    for sub in ("environment", "tests"):
        (root / sub / "Quantum_Basics.thy").write_text(basics)
    (root / "environment" / "ROOT").write_text(
        f"session Submission = HOL +\n  options [quick_and_dirty = false]\n  theories\n"
        f"    Quantum_Basics\n    {theory}\n"
    )
    copied = f"Quantum_Basics.thy {theory}.thy ROOT"
    if lean.exists():
        shutil.copy(lean, root / "environment" / lean.name)
        copied = f"{lean.name} {copied}"
    dockerfile = (cauchy / "environment" / "Dockerfile").read_text()
    dockerfile = dockerfile.replace("COPY Cauchy.lean Group_Axioms.thy Cauchy.thy ROOT /app/", f"COPY {copied} /app/")
    if lean.suffix == ".pdf":
        dockerfile = dockerfile.replace("install -y --no-install-recommends tmux", "install -y --no-install-recommends poppler-utils tmux")
    if lean.suffix == ".lean":
        note = (
            "# The complete Lean proof is the task's intended input, not a leaked answer: this is a proof-translation task\n"
            "# (Lean 4 -> structured Isabelle/Isar). Translating it is the work being measured; the grader re-checks every\n"
            "# statement in the Isabelle kernel against a trusted copy. See WRAPUP.md for the paper-reference variant.\n"
        )
        dockerfile = dockerfile.replace(f"COPY {copied} /app/", note + f"COPY {copied} /app/")
    (root / "environment" / "Dockerfile").write_text(dockerfile)

    entries = ",\n".join(f'    ("{n}", @{{prop \\<open>{canonical_prop(headers[n])}\\<close>}})' for n in theorems)
    (root / "tests" / "Canonical.thy").write_text(
        "theory Canonical\n  imports Quantum_Basics\nbegin\n\n"
        "text \\<open>Trusted: the canonical statements, parsed where only \\<open>Quantum_Basics\\<close> is "
        "visible,\n  so a submission cannot change their meaning by shadowing constants.\\<close>\n\n"
        f"ML \\<open>\n  val canonical_statements = [\n{entries}]\n\n"
        "  fun check_theorem name thm =\n    let\n"
        "      val expected = Logic.varify_global (the (AList.lookup (op =) canonical_statements name))\n"
        "    in\n"
        "      if Thm.prop_of thm aconv expected then ()\n"
        '      else error ("Statement of " ^ name ^ " differs from the canonical statement");\n'
        "      if null (Thm_Deps.all_oracles [thm]) then ()\n"
        '      else error (name ^ " depends on an oracle (e.g. sorry or skip_proofs)")\n'
        "    end\n\\<close>\n\nend\n"
    )
    calls = "\n".join(f'  val _ = check_theorem "{n}" @{{thm {theory}.{n}}}' for n in theorems)
    (root / "tests" / "Check.thy").write_text(
        f"theory Check\n  imports Canonical {theory}\nbegin\n\nML \\<open>\n{calls}\n\\<close>\n\nend\n"
    )
    (root / "tests" / "ROOT").write_text(
        "session Verify = HOL +\n"
        "  options [quick_and_dirty = false, skip_proofs = false, timeout = 480]\n  theories\n"
        f"    Quantum_Basics\n    Canonical\n    {theory}\n    Check\n"
    )
    trusted = ("Quantum_Basics.thy", "Canonical.thy", "Check.thy", "ROOT")
    verify = render_verify(theory, {"Complex_Main", "Quantum_Basics"}, trusted, cap, theorems)
    (root / "tests" / "verify.py").write_text(verify)
    shutil.copy(cauchy / "tests" / "test.sh", root / "tests" / "test.sh")
    (root / "solution" / "solve.sh").write_text(f"#!/bin/sh\nset -eu\ncat > /app/{theory}.thy <<'THY'\n{oracle}THY\n")
    (root / "solution" / "solve.sh").chmod(0o755)

    difficulty, evidence = DIFFICULTY[task]
    toml = (cauchy / "task.toml").read_text()
    toml = toml.replace('artifacts = ["/app/Cauchy.thy"]', f'artifacts = ["/app/{theory}.thy"]')
    tags = '"isabelle", "isar", "lean", "quantum", "shor", "first-principles"'
    if lean.suffix == ".pdf":
        tags = tags.replace('"lean", ', "")
    toml = re.sub(r"^tags = .*$", f"tags = [{tags}]", toml, flags=re.MULTILINE)
    toml = re.sub(r"^difficulty(_evidence)? = .*\n", "", toml, flags=re.MULTILINE)
    toml = toml.replace(
        "[metadata]\n", f'[metadata]\ndifficulty = "{difficulty}"\ndifficulty_evidence = "{evidence}"\n', 1
    )
    (root / "task.toml").write_text(toml)

    listed = "\n".join(f"{i}. `{n}`: {DESCRIPTIONS[n]}" for i, n in enumerate(theorems, 1))
    lean_text = (
        f"`/app/{lean.name}` (Fang Xi Lin, \"Shor's Algorithm and the Quantum Fourier Transform\", McGill, 2013;\n"
        "https://www.math.mcgill.ca/darmon/courses/12-13/nt/projects/Fangxi-Lin.pdf) is a human-written exposition of\n"
        "Shor's algorithm (`pdftotext` is installed). It is a reference, not a template: its statements, constants and\n"
        "level of rigour differ from the theorems here. Your only task is to prove the Isabelle theorems below, by any\n"
        "route you like, within the requirements that follow."
        if lean.suffix == ".pdf"
        else f"`/app/{lean.name}` is one Lean 4 (Mathlib) proof of these theorems, over Lean definitions that mirror\n"
        "`Quantum_Basics.thy`. It is a reference, not a template. Your only task is to prove the Isabelle\n"
        "theorems below, by any route you like, within the requirements that follow."
        if lean.exists()
        else "There is no Lean proof to translate; you must find the argument yourself."
    )
    allowed = ALLOWED_TEXT
    (root / "instruction.md").write_text(f"""# Prove {title} in Isabelle/Isar from first principles

`/app/Quantum_Basics.thy` builds finite-dimensional quantum mechanics from scratch on top of
`Complex_Main`: vectors are functions `nat \\<Rightarrow> complex`, with the inner product, states (unit
vectors), the Born rule `prob`, the quantum Fourier transform `qft`, the periodic state
`periodic_state` that Shor's algorithm prepares, the tensor product `tensor`, inner-product-preserving
evolution `preserves_inner`, the multiplicative order `is_order`, and the classical post-processing
`recover`. `Complex_Main` supplies only general mathematics (complex numbers, `cis`, `sqrt`, `sin`,
`pi`, derivatives, finite sums, `gcd`, `dvd`). There is no linear-algebra library.

{lean_text}

`/app/{theory}.thy` states the following theorem(s), each ending in `sorry`. Replace every `sorry`
with a complete proof:

{listed}

Isabelle2025 is installed (`isabelle` is on `PATH`) with a prebuilt `HOL` heap; check your work
from `/app` with:

```sh
timeout 300 isabelle build -o threads=2 -D /app
```

{sandbox_text(theory)}
## Requirements

- Keep the theory name and every `theorem ...: assumes ... shows ...` statement unchanged (you may
  name the assumptions). You may add your own definitions and lemmas before them.
- Allowed imports: `Complex_Main` and `Quantum_Basics` only (no `HOL-Analysis`, `HOL-Library`,
  `HOL-Number_Theory` or AFP entries). Do not modify `/app/Quantum_Basics.thy` or `/app/ROOT`; the
  grader uses its own copies and re-checks each statement against a trusted canonical version.
- `/app/{theory}.thy` must be at most **{cap} lines** in total.
- Write the proofs in structured Isar: `proof ... qed` blocks built from named facts and
  `have`/`show`/`obtain` steps, reading like a textbook argument with the key ideas as lemmas. From
  the first required theorem to the end of the file there must be at least four
  `have`/`show`/`thus`/`hence`/`obtain` steps and a `qed`.
- Forbidden anywhere in the file: {forbidden_text()}. {allowed}
  `auto`, `blast`, `arith`, `unfold`, `.` and `..` are allowed.
""")
    print(f"{task}: {len(oracle.splitlines())} oracle lines, cap {cap}")


def write_group(task: str, theory: str, theorems: list[str], cap: int) -> None:
    root = REPO / task
    trusted = ("Group_Axioms.thy", "Canonical.thy", "Check.thy", "ROOT")
    verify = render_verify(theory, {"Main", "Group_Axioms"}, trusted, cap, theorems)
    (root / "tests" / "verify.py").write_text(verify)
    print(f"{task}: verify.py rendered, cap {cap}")


def main() -> None:
    for task, (theory, theorems, cap) in GROUP.items():
        write_group(task, theory, theorems, cap)
    for task, (theory, theorems, cap, title) in TASKS.items():
        write_quantum(task, theory, theorems, cap, title)


if __name__ == "__main__":
    main()
