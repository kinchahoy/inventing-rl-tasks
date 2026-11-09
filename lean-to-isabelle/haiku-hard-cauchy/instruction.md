# Prove Cauchy's theorem in Isabelle/Isar from the basic group axioms

`/app/Cauchy.lean` is one Lean 4 (Mathlib) proof of Cauchy's theorem: if a prime `p` divides the
order of a finite group `G`, then `G` has an element of order `p`. It is a reference, not a
template. Your only task is to prove the Isabelle theorem in `/app/Cauchy.thy`, by any route you
like, within the requirements below.

`/app/Group_Axioms.thy` defines a locale `grp` from the basic axioms only: closure, associativity,
a **left** identity `e` and **left** inverses `ginv`. It also defines `prime` (from divisibility)
and natural powers `pow x n` (`pow x 0 = e`, `pow x (Suc n) = x \<cdot> pow x n`). Every other group
fact you need (right identity, right inverses, cancellation, laws of powers, ...) must be derived
from these axioms in your own file. `Main` provides only general mathematics: sets, `finite`,
`card`, lists, natural-number arithmetic, `dvd`, `gcd`, and function iteration `f ^^ n`.

`/app/Cauchy.thy` states the theorem and ends in `sorry`. Replace the `sorry` with a complete proof.
Isabelle2025 is installed (`isabelle` is on `PATH`) with a prebuilt `HOL` heap; check your work
from `/app` with:

```sh
timeout 300 isabelle build -o threads=2 -D /app
```

## Working in the sandbox

- Only `/app/Cauchy.thy` is graded; nothing else in the sandbox is kept. Keep your current best
  version there as you go.
- You have 60 minutes.
- `isabelle build` prints nothing until the session finishes, and a looping `simp`/`auto`/`blast` can
  run indefinitely. Wrap builds in `timeout`, e.g. `timeout 300 isabelle build -o threads=2 -D /app`.
  The grader allows 8 minutes for the whole build.
- `isabelle process` may not exit on its own; use `isabelle build`.

## Requirements

- Keep the theory name and the statement `theorem (in grp) cauchy: assumes ... shows ...`
  unchanged (you may name the assumptions). You may add your own definitions and lemmas before it.
- Allowed imports: `Main` and `Group_Axioms` only. Do not modify `/app/Group_Axioms.thy` or
  `/app/ROOT`; the grader uses its own copies.
- `/app/Cauchy.thy` must be at most **600 lines** in total.
- Write the proof in structured Isar: `proof ... qed` blocks built from named facts and
  `have`/`show`/`obtain` steps (`from`, `with`, `hence`, `thus`, `also`/`finally`, `moreover` are
  all fine), with at least four such steps in the proof of `cauchy` itself. It should read like a
  textbook argument, with the key ideas stated as their own lemmas.
- Forbidden anywhere in the file: `apply`-style scripts (`apply`, `done`, `back`, `defer`, `prefer`), `sorry`, `oops`, `smt`, `sledgehammer`, `nitpick`, `nunchaku`, `quickcheck`, `axiomatization`, `axioms`, `oracle`, `skip_proofs`, `quick_and_dirty`, `tactic`, `raw_tactic`, and every ML, setup, syntax and translation command (`ML`, `ML_*`, `SML_*`, `setup`, `local_setup`, `method_setup`, `attribute_setup`, `simproc_setup`, `declaration`, `syntax_declaration`, `syntax`, `no_syntax`, `translations`, `*_translation`). Comments, cartouches and strings are not scanned.
  Ordinary methods such as `metis`, `meson`, `rule`, `simp`, `auto`, `blast`, `arith`, `unfold`, `.` and `..` are
  allowed.
