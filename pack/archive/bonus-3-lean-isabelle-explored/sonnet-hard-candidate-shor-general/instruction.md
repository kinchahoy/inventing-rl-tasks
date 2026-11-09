# Prove Shor's algorithm for a general period in Isabelle/Isar from first principles

`/app/Quantum_Basics.thy` builds finite-dimensional quantum mechanics from scratch on top of
`Complex_Main`: vectors are functions `nat \<Rightarrow> complex`, with the inner product, states (unit
vectors), the Born rule `prob`, the quantum Fourier transform `qft`, the periodic state
`periodic_state` that Shor's algorithm prepares, the tensor product `tensor`, inner-product-preserving
evolution `preserves_inner`, the multiplicative order `is_order`, and the classical post-processing
`recover`. `Complex_Main` supplies only general mathematics (complex numbers, `cis`, `sqrt`, `sin`,
`pi`, derivatives, finite sums, `gcd`, `dvd`). There is no linear-algebra library.

`/app/Shor_General.lean` is one Lean 4 (Mathlib) proof of these theorems, over Lean definitions that mirror
`Quantum_Basics.thy`. It is a reference, not a template. Your only task is to prove the Isabelle
theorems below, by any route you like, within the requirements that follow.

`/app/Shor_General.thy` states the following theorem(s), each ending in `sorry`. Replace every `sorry`
with a complete proof:

1. `shor_factor`: **Classical step.** If `r` is the order of `a` modulo `n > 1`, `r` is even and `a^(r/2) mod n != n - 1`, then `gcd (a^(r/2) - 1) n` is a nontrivial factor of `n`.
2. `shor_peak`: **Peaks for a general period.** For any period `0 < r < N` (not necessarily dividing `N`) and offset `x0 < r`, the periodic state is a unit vector, and every outcome `j < N` within `r/2` of a multiple of `N/r` (that is, `2 * |j * r - c * N| <= r` for some integer `c`) has probability at least `4 / (pi^2 * r) * (1 - r/N)^3`.
3. `shor_general_success`: **Period recovery for a general period.** If `r^2 < N`, one run (QFT, measure `j`, output `recover N j`, the least denominator of a fraction within `1/(2N)` of `j/N`) returns `r` with probability at least `4 / pi^2 * phi(r)/r * (1 - r/N)^3`, where `phi(r) = card {c. c < r \<and> coprime c r}`.

Isabelle2025 is installed (`isabelle` is on `PATH`) with a prebuilt `HOL` heap; check your work
from `/app` with:

```sh
timeout 300 isabelle build -o threads=2 -D /app
```

## Working in the sandbox

- Only `/app/Shor_General.thy` is graded; nothing else in the sandbox is kept. Keep your current best
  version there as you go.
- You have 60 minutes.
- `isabelle build` prints nothing until the session finishes, and a looping `simp`/`auto`/`blast` can
  run indefinitely. Wrap builds in `timeout`, e.g. `timeout 300 isabelle build -o threads=2 -D /app`.
  The grader allows 8 minutes for the whole build.
- `isabelle process` may not exit on its own; use `isabelle build`.

## Requirements

- Keep the theory name and every `theorem ...: assumes ... shows ...` statement unchanged (you may
  name the assumptions). You may add your own definitions and lemmas before them.
- Allowed imports: `Complex_Main` and `Quantum_Basics` only (no `HOL-Analysis`, `HOL-Library`,
  `HOL-Number_Theory` or AFP entries). Do not modify `/app/Quantum_Basics.thy` or `/app/ROOT`; the
  grader uses its own copies and re-checks each statement against a trusted canonical version.
- `/app/Shor_General.thy` must be at most **700 lines** in total.
- Write the proofs in structured Isar: `proof ... qed` blocks built from named facts and
  `have`/`show`/`obtain` steps, reading like a textbook argument with the key ideas as lemmas. From
  the first required theorem to the end of the file there must be at least four
  `have`/`show`/`thus`/`hence`/`obtain` steps and a `qed`.
- Forbidden anywhere in the file: `apply`-style scripts (`apply`, `done`, `back`, `defer`, `prefer`), `sorry`, `oops`, `smt`, `sledgehammer`, `nitpick`, `nunchaku`, `quickcheck`, `axiomatization`, `axioms`, `oracle`, `skip_proofs`, `quick_and_dirty`, `tactic`, `raw_tactic`, and every ML, setup, syntax and translation command (`ML`, `ML_*`, `SML_*`, `setup`, `local_setup`, `method_setup`, `attribute_setup`, `simproc_setup`, `declaration`, `syntax_declaration`, `syntax`, `no_syntax`, `translations`, `*_translation`). Comments, cartouches and strings are not scanned. Ordinary methods such as `metis`, `meson`, `rule`, `simp`,
  `auto`, `blast`, `arith`, `unfold`, `.` and `..` are allowed.
