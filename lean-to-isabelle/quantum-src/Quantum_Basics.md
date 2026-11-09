# Quantum_Basics: reference

What each definition in [`Quantum_Basics.thy`](Quantum_Basics.thy) means mathematically, and how the
Lean reference proofs (`lean-drafts/*.lean`) mirror it. The Lean files copy the Isabelle
definitions, so every Lean theorem states exactly the same thing as its Isabelle counterpart.

A vector is a function `nat ⇒ complex` (Lean: `ℕ → ℂ`). Only the entries below the stated dimension
are ever read, so a dimension-`n` vector is a vector $v \in \mathbb{C}^n$ with entries $v_0, \dots, v_{n-1}$.

## Definitions

### Inner product

```isabelle
inner n u v = (∑i<n. cnj (u i) * v i)
```

$$\langle u, v\rangle = \sum_{i=0}^{n-1} \overline{u_i}\, v_i$$

This is the standard Hermitian inner product, conjugate-linear in the first argument. In particular
$\langle v, v\rangle = \sum_i |v_i|^2$. Lean calls it `qinner` to avoid clashing with Mathlib's `inner`.

### State

```isabelle
is_state n v ⟷ inner n v v = 1
```

$v$ is a unit vector: $\sum_{i<n} |v_i|^2 = 1$ (total probability 1).

### Basis ket

```isabelle
ket k = (λi. if i = k then 1 else 0)
```

$|k\rangle = e_k$, the $k$-th standard basis vector. For example, in dimension 4, $|2\rangle = (0, 0, 1, 0)^T$.

### Tensor product

```isabelle
tensor n u v = (λi. u (i div n) * v (i mod n))
```

`n` is the dimension of the **second** factor. For $u \in \mathbb{C}^m$ and $v \in \mathbb{C}^n$:

$$(u \otimes v)_{a n + b} = u_a\, v_b \qquad (0 \le a < m,\ 0 \le b < n)$$

So $(a, b)^T \otimes (c, d)^T = (ac, ad, bc, bd)^T$. On two qubits (`tensor 2`), index $i$ encodes the
pair (first qubit $= \lfloor i/2 \rfloor$, second $= i \bmod 2$).

### Inner-product preservation

```isabelle
preserves_inner n U ⟷ (∀u v. inner n (U u) (U v) = inner n u v)
```

$\langle Uu, Uv\rangle = \langle u, v\rangle$ for all $u, v$. This is the only property of evolution
the no-cloning theorem assumes. $U$ is not required to be linear. For a linear $U$ it is equivalent
to unitarity, $U^\dagger U = I$.

### Measurement probability

```isabelle
prob v j = (cmod (v j))²
```

Born rule: $P(j) = |v_j|^2$. For example, $v = \tfrac{1}{\sqrt 2}(1, i)^T$ gives $P(0) = P(1) = \tfrac12$.
Lean writes `‖v j‖ ^ 2`, which is the same quantity.

### Quantum Fourier transform

```isabelle
qft N v = (λj. (∑k<N. cis (2 * pi * real j * real k / real N) * v k) / complex_of_real (sqrt (real N)))
```

$$(F_N v)_j = \frac{1}{\sqrt N} \sum_{k=0}^{N-1} e^{2\pi i\, jk/N}\, v_k$$

This is the unitary DFT with the positive-exponent convention. Isabelle's
`cis θ = Complex (cos θ) (sin θ)` $= \cos\theta + i\sin\theta = e^{i\theta}$. Lean Mathlib v4.35.0 has
no `Complex.cis`, so the Lean files define `cis θ := cos θ + sin θ * I` and prove `cis θ = exp (θ I)`.

### Periodic state

```isabelle
periodic_state N r x0 = (λk. if k < N ∧ k mod r = x0
  then complex_of_real (1 / sqrt (real (card {i. i < N ∧ i mod r = x0}))) else 0)
```

This is the uniform superposition over the residue class $x_0 \bmod r$ inside $\{0, \dots, N-1\}$:

$$|\psi\rangle = \frac{1}{\sqrt{L}} \sum_{\substack{0 \le k < N \\ k \equiv x_0 \ (\mathrm{mod}\ r)}} |k\rangle,
\qquad L = \lvert\{k < N : k \equiv x_0 \ (\mathrm{mod}\ r)\}\rvert$$

It is the register's state after Shor's algorithm measures $a^x \bmod n$. Example: $N = 12$,
$r = 3$, $x_0 = 1$ gives $\tfrac12(|1\rangle + |4\rangle + |7\rangle + |10\rangle)$.

**Normalised for every period.** The state is normalised by the size $L$ of the residue class, so it
is a unit vector whenever $0 < r$ and $x_0 < \min(r, N)$, whether or not $r$ divides $N$. When
$r \mid N$, $L = N/r$; for example, $N = 10$, $r = 3$, $x_0 = 0$ gives $L = 4$ (indices
$\{0, 3, 6, 9\}$), not $\lfloor 10/3 \rfloor = 3$. In general $N - r \le L r \le N + r$.

### Multiplicative order

```isabelle
is_order n a r ⟷ 0 < r ∧ a ^ r mod n = 1 ∧ (∀k. 0 < k ⟶ k < r ⟶ a ^ k mod n ≠ 1)
```

$r$ is the least positive exponent with $a^r \equiv 1 \pmod n$. Example: the order of 2 mod 15 is 4.
Coprimality of $a$ and $n$ is not assumed separately. It follows, since $a^r \bmod n = 1$ forces
$\gcd(a, n) = 1$ when $n > 1$.

### Period recovery

```isabelle
recover N j = (LEAST b. 0 < b ∧ (∃a::int. 2 * ¦int j * int b - a * int N¦ ≤ int b))
```

The least denominator $b > 0$ of a fraction $a/b$ within $1/(2N)$ of the measured $j/N$:
$\lvert j/N - a/b\rvert \le 1/(2N)$. The continued-fraction expansion of $j/N$ computes it
efficiently; the definition only specifies the result. (`¦·¦` is `\<bar>·\<bar>`, absolute value.)

## Theorems

| Isabelle theorem | Task(s) | Statement |
| --- | --- | --- |
| `shor_core` | shor-exact | For $0 < N$, $0 < r$, $r \mid N$, $x_0 < r$, the periodic state is a state, and $P_{F_N\psi}(j) = 1/r$ if $(N/r) \mid j$, else 0. Exact, with no "peaks near" approximation. |
| `shor_factor` | shor-exact, shor-general | If $1 < n$, `is_order n a r`, $r$ is even and $a^{r/2} \bmod n \ne n-1$, then $1 < \gcd(a^{r/2}-1, n) < n$. |
| `shor_success` | shor-exact | The total probability of outcomes $j < N$ with $N / \gcd(j, N) = r$ is $\lvert\{k < r : \gcd(k, r) = 1\}\rvert / r = \varphi(r)/r$. |
| `shor_peak` | shor-general | For $0 < r < N$, $x_0 < r$, $j < N$ and $2\lvert jr - cN\rvert \le r$: the periodic state is a state and $P_{F_N\psi}(j) \ge \frac{4}{\pi^2 r}(1 - r/N)^3$. |
| `shor_general_success` | shor-general | If $0 < r$, $r^2 < N$ and $x_0 < r$, the total probability of outcomes $j < N$ with `recover N j = r` is at least $\frac{4}{\pi^2} \cdot \frac{\varphi(r)}{r} \cdot (1 - r/N)^3$. |

In `shor_success`, an outcome $j = kN/r$ reveals $r$ exactly when $j/N = k/r$ is already in lowest
terms. In the exact case, that replaces the continued-fraction step of the general algorithm. In
`shor_general_success`, each $c < r$ coprime to $r$ has its own nearest outcome
$j_c = \mathrm{round}(cN/r)$; `recover` returns $r$ on it because two distinct fractions with
denominators at most $r$ differ by more than $1/N$ when $r^2 < N$. No-cloning and the shor-core and
shor-gcd tasks are archived.

## Lean correspondence

| Isabelle | Lean draft | Note |
| --- | --- | --- |
| `inner` | `qinner` | renamed only |
| `is_state`, `ket`, `preserves_inner`, `is_order` | same names | identical bodies |
| `tensor` | `tensor` | ℕ `/` and `%` agree with `div` and `mod`, including `n = 0` |
| `prob` | `prob` | `‖·‖ ^ 2` equals `cmod² ` |
| `qft`, `cis` | `qft`, local `cis` | same real casts, same normalisation |
| `periodic_state` | `periodic_state` | normalised by the card of the residue class; the drafts in `../lean-drafts/` still use `N / r` and must be updated |
| `{k. k < r ∧ coprime k r}` | `(range r).filter (Nat.Coprime · r)` | same set |
| `even r` | `Even r` | same predicate |

Both systems define division by zero as 0, so edge cases agree too. The comparison was done by
reading, since no tool checks a Lean statement against an Isabelle one. A faithful translation would
also copy any mistake in the specification, so check the definitions themselves against the
mathematics above, not just against each other.
