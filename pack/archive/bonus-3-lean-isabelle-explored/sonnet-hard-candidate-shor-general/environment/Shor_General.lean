import Mathlib

/-!
# Shor's algorithm for a general period (reference proof)

Definitions mirror `Quantum_Basics.thy`; the three theorems `shor_factor`, `shor_peak` and
`shor_general_success` mirror `Shor_General.thy`.
-/

open Finset ComplexConjugate

noncomputable section

/-! ## Definitions -/

/-- A vector of dimension `n` is a function `ℕ → ℂ`; only its entries below `n` are read. -/
abbrev Vec := ℕ → ℂ

/-- `⟨u|v⟩ = ∑_{i<n} conj (u i) * v i` -/
def qinner (n : ℕ) (u v : Vec) : ℂ := ∑ i ∈ range n, conj (u i) * v i

/-- A state is a unit vector. -/
def is_state (n : ℕ) (v : Vec) : Prop := qinner n v v = 1

/-- Born rule: `|v j|²`. -/
def prob (v : Vec) (j : ℕ) : ℝ := ‖v j‖ ^ 2

/-- `cis θ = cos θ + i sin θ` -/
def cis (θ : ℝ) : ℂ := (Real.cos θ : ℂ) + (Real.sin θ : ℂ) * Complex.I

/-- Quantum Fourier transform on `ℤ_N`: `|k⟩ ↦ N^(-1/2) ∑_j e^(2πi jk/N) |j⟩`. -/
def qft (N : ℕ) (v : Vec) : Vec := fun j =>
  (∑ k ∈ range N, cis (2 * Real.pi * (j : ℝ) * (k : ℝ) / (N : ℝ)) * v k) /
    ((Real.sqrt (N : ℝ) : ℝ) : ℂ)

/-- The uniform superposition over `{x0, x0 + r, x0 + 2r, …} ⊆ ℤ_N`, normalised by the number
of such indices. -/
def periodic_state (N r x0 : ℕ) : Vec := fun k =>
  if k < N ∧ k % r = x0 then
    (((1 / Real.sqrt (((range N).filter (fun i => i % r = x0)).card : ℝ) : ℝ)) : ℂ)
  else 0

/-- `r` is the multiplicative order of `a` modulo `n`. -/
def is_order (n a r : ℕ) : Prop :=
  0 < r ∧ a ^ r % n = 1 ∧ ∀ k, 0 < k → k < r → a ^ k % n ≠ 1

/-- Classical post-processing: the least denominator `b` of a fraction `a / b` within `1 / (2N)`
of the measured `j / N`. -/
def recover (N j : ℕ) : ℕ :=
  sInf {b : ℕ | 0 < b ∧ ∃ a : ℤ, 2 * |(j : ℤ) * b - a * N| ≤ b}

/-- `recover N j` is the least `b` satisfying the defining predicate: this is the characterisation
of `LEAST` used below. -/
lemma recover_eq_of_least {N j r : ℕ} (hmem : 0 < r ∧ ∃ a : ℤ, 2 * |(j : ℤ) * r - a * N| ≤ r)
    (hmin : ∀ b : ℕ, (0 < b ∧ ∃ a : ℤ, 2 * |(j : ℤ) * b - a * N| ≤ b) → r ≤ b) :
    recover N j = r :=
  le_antisymm (Nat.sInf_le hmem) (le_csInf ⟨r, hmem⟩ fun b hb => hmin b hb)

/-! ## The classical step: an even period yields a factor -/

/-- With `b = a^(r/2)`: `n ∣ b² - 1 = (b - 1)(b + 1)`, but `n` divides neither factor, so
`gcd (b - 1) n` is a proper divisor of `n` other than `1`. -/
theorem shor_factor {n a r : ℕ} (hn : 1 < n) (hord : is_order n a r) (heven : Even r)
    (hneg : a ^ (r / 2) % n ≠ n - 1) :
    1 < Nat.gcd (a ^ (r / 2) - 1) n ∧ Nat.gcd (a ^ (r / 2) - 1) n < n := by
  obtain ⟨hr, har, hmin⟩ := hord
  obtain ⟨s, hs⟩ := heven
  have hs' : r / 2 = s := by omega
  have hs0 : 0 < s := by omega
  have hsr : s < r := by omega
  rw [hs'] at hneg ⊢
  have hn0 : NeZero n := ⟨by omega⟩
  have ha : 0 < a := by
    rcases Nat.eq_zero_or_pos a with rfl | h
    · simp [hr.ne'] at har
    · exact h
  have hpos : 1 ≤ a ^ s := Nat.one_le_pow _ _ ha
  -- work in the ring ZMod n with x = a^s
  set x : ZMod n := ((a ^ s : ℕ) : ZMod n) with hx
  have hx2 : x * x = 1 := by
    have : x * x = ((a ^ r : ℕ) : ZMod n) := by
      rw [hx, ← Nat.cast_mul, ← pow_add, ← hs]
    rw [this, ← ZMod.natCast_mod, har]; simp
  have hx1 : x ≠ 1 := by
    intro h
    have : ((a ^ s : ℕ) : ZMod n) = ((1 : ℕ) : ZMod n) := by rw [Nat.cast_one]; exact h
    rw [ZMod.natCast_eq_natCast_iff'] at this
    exact hmin s hs0 hsr (by rwa [Nat.mod_eq_of_lt hn] at this)
  have hxm1 : x ≠ -1 := by
    intro h
    apply hneg
    have : ((a ^ s : ℕ) : ZMod n) = ((n - 1 : ℕ) : ZMod n) := by
      rw [Nat.cast_sub hn.le, ZMod.natCast_self, Nat.cast_one, zero_sub]; exact h
    rw [ZMod.natCast_eq_natCast_iff'] at this
    rwa [Nat.mod_eq_of_lt (by omega : n - 1 < n)] at this
  -- x - 1 is nonzero and not a unit
  have hcast : ((a ^ s - 1 : ℕ) : ZMod n) = x - 1 := by
    rw [Nat.cast_sub hpos]; simp [hx]
  have hne : x - 1 ≠ 0 := sub_ne_zero.mpr hx1
  have hnu : ¬ IsUnit (x - 1) := by
    intro hu
    have : (x - 1) * (x + 1) = 0 := by linear_combination hx2
    exact hxm1 (eq_neg_of_add_eq_zero_left (hu.mul_right_eq_zero.mp this))
  have hncop : ¬ Nat.Coprime (a ^ s - 1) n := by
    rw [← ZMod.isUnit_iff_coprime, hcast]; exact hnu
  -- translate back to gcd
  refine ⟨?_, ?_⟩
  · have h0 : Nat.gcd (a ^ s - 1) n ≠ 0 := (Nat.gcd_pos_of_pos_right _ (by omega)).ne'
    have h1 : Nat.gcd (a ^ s - 1) n ≠ 1 := hncop
    omega
  · have hle : Nat.gcd (a ^ s - 1) n ≤ n := Nat.le_of_dvd (by omega) (Nat.gcd_dvd_right _ _)
    refine lt_of_le_of_ne hle fun h => hne ?_
    rw [← hcast, ZMod.natCast_eq_zero_iff]
    exact h ▸ Nat.gcd_dvd_left _ _

/-! ## The periodic state for a general period -/

/-- For `x0 < r` and `x0 < N`, the indices below `N` congruent to `x0` are `x0 + m r` for
`m < L`, with `L = (N - 1 - x0) / r + 1`. -/
lemma residue_set {N r x0 : ℕ} (hr : 0 < r) (hx0 : x0 < r) (hx0N : x0 < N) :
    (range N).filter (fun i => i % r = x0)
      = (range ((N - 1 - x0) / r + 1)).image (fun m => x0 + m * r) := by
  ext i
  simp only [mem_filter, mem_range, mem_image]
  constructor
  · rintro ⟨hi, hmod⟩
    have heq : x0 + i / r * r = i := by
      have := Nat.mod_add_div i r
      rw [hmod, Nat.mul_comm r] at this; exact this
    have h1 : i / r * r ≤ N - 1 - x0 := by omega
    have h2 : i / r ≤ (N - 1 - x0) / r := (Nat.le_div_iff_mul_le hr).mpr h1
    exact ⟨i / r, by omega, heq⟩
  · rintro ⟨m, hm, rfl⟩
    have h1 : m ≤ (N - 1 - x0) / r := by omega
    have h2 : m * r ≤ N - 1 - x0 := le_trans (Nat.mul_le_mul_right r h1) (Nat.div_mul_le_self _ _)
    refine ⟨by omega, ?_⟩
    simp [Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hx0]

/-- Size of the residue class, and its enumeration as a sum. -/
lemma residue_count {N r x0 : ℕ} (hr : 0 < r) (hx0 : x0 < r) (hx0N : x0 < N) (h : ℕ → ℂ) :
    0 < ((range N).filter (fun i => i % r = x0)).card ∧
    ((range N).filter (fun i => i % r = x0)).card * r ≤ N + r ∧
    N ≤ ((range N).filter (fun i => i % r = x0)).card * r + r ∧
    ∑ k ∈ range N, (if k < N ∧ k % r = x0 then h k else 0)
      = ∑ m ∈ range ((range N).filter (fun i => i % r = x0)).card, h (x0 + m * r) := by
  set q := (N - 1 - x0) / r with hq
  have hset := residue_set hr hx0 hx0N
  have hinj : Set.InjOn (fun m => x0 + m * r) (range (q + 1) : Set ℕ) := by
    intro a _ b _ hab
    exact Nat.eq_of_mul_eq_mul_right hr (Nat.add_left_cancel hab)
  have hL : ((range N).filter (fun i => i % r = x0)).card = q + 1 := by
    rw [hset, card_image_of_injOn hinj, card_range]
  have h1 : q * r ≤ N - 1 - x0 := Nat.div_mul_le_self _ _
  have h2 : N - 1 - x0 < r * (q + 1) := Nat.lt_mul_div_succ _ hr
  have e : (q + 1) * r = q * r + r := by ring
  have e' : r * (q + 1) = q * r + r := by ring
  rw [hL]
  refine ⟨Nat.succ_pos _, ?_, ?_, ?_⟩
  · omega
  · omega
  · calc ∑ k ∈ range N, (if k < N ∧ k % r = x0 then h k else 0)
        = ∑ k ∈ (range N).filter (fun i => i % r = x0), h k := by
          rw [sum_filter]
          exact sum_congr rfl fun k hk => by simp [mem_range.mp hk]
      _ = ∑ m ∈ range (q + 1), h (x0 + m * r) := by rw [hset, sum_image hinj]

/-! ## Its Fourier amplitudes -/

lemma cis_eq_exp (θ : ℝ) : cis θ = Complex.exp (Complex.I * θ) := by
  rw [mul_comm, Complex.exp_mul_I, cis, ← Complex.ofReal_cos, ← Complex.ofReal_sin]

lemma cis_add (a b : ℝ) : cis (a + b) = cis a * cis b := by
  simp only [cis_eq_exp, Complex.ofReal_add, mul_add, Complex.exp_add]

lemma norm_cis (θ : ℝ) : ‖cis θ‖ = 1 := by
  rw [cis_eq_exp, mul_comm]; exact Complex.norm_exp_ofReal_mul_I θ

/-- The amplitude of `qft N (periodic_state N r x0)` at `j` has the modulus of a sum of `L`
phases over `√L √N`, where `L` is the size of the residue class of `x0`. -/
lemma qft_periodic_norm {N r x0 : ℕ} (hr : 0 < r) (hx0 : x0 < r) (hx0N : x0 < N) (j : ℕ) :
    ‖qft N (periodic_state N r x0) j‖
      = ‖∑ m ∈ range ((range N).filter (fun i => i % r = x0)).card,
          cis (2 * Real.pi * j * r * m / N)‖
        / (Real.sqrt (((range N).filter (fun i => i % r = x0)).card : ℝ) * Real.sqrt N) := by
  set L := ((range N).filter (fun i => i % r = x0)).card with hL
  set c : ℂ := ((1 / Real.sqrt (L : ℝ) : ℝ) : ℂ) with hc
  set ph : ℂ := cis (2 * Real.pi * j * x0 / N) with hph
  -- each retained term factors as (constant) * (phase depending on m)
  have phase : ∀ m : ℕ, cis (2 * Real.pi * j * ((x0 + m * r : ℕ) : ℝ) / N) * c
      = c * ph * cis (2 * Real.pi * j * r * m / N) := by
    intro m
    have : 2 * Real.pi * j * ((x0 + m * r : ℕ) : ℝ) / N
        = 2 * Real.pi * j * x0 / N + 2 * Real.pi * j * r * m / N := by
      push_cast; ring
    rw [this, cis_add]; ring
  have sum_eq : ∑ k ∈ range N, cis (2 * Real.pi * j * k / N) * periodic_state N r x0 k
      = c * ph * ∑ m ∈ range L, cis (2 * Real.pi * j * r * m / N) := by
    have h1 : ∑ k ∈ range N, cis (2 * Real.pi * j * k / N) * periodic_state N r x0 k
        = ∑ k ∈ range N, (if k < N ∧ k % r = x0 then cis (2 * Real.pi * j * k / N) * c else 0) := by
      refine sum_congr rfl fun k _ => ?_
      by_cases hk : k < N ∧ k % r = x0 <;> simp [periodic_state, hk, hc, hL]
    rw [h1, (residue_count hr hx0 hx0N (fun k => cis (2 * Real.pi * j * k / N) * c)).2.2.2,
      mul_sum]
    exact sum_congr rfl fun m _ => phase m
  have hnc : ‖c‖ = 1 / Real.sqrt L := by
    rw [hc, Complex.norm_real, Real.norm_eq_abs, abs_of_nonneg (by positivity)]
  rw [qft, norm_div, sum_eq, norm_mul, norm_mul, hnc, hph, norm_cis, Complex.norm_real,
    Real.norm_eq_abs, abs_of_nonneg (Real.sqrt_nonneg _)]
  field_simp

/-- Only the distance `δ = j r - c N` to a multiple of `N` matters. -/
lemma phase_shift {N : ℕ} (hN : 0 < N) (j r m : ℕ) (c : ℤ) :
    cis (2 * Real.pi * j * r * m / N)
      = cis (m * (2 * Real.pi * (((j : ℤ) * r - c * N : ℤ) : ℝ) / N)) := by
  have hN' : (N : ℝ) ≠ 0 := by positivity
  have hsplit : 2 * Real.pi * j * r * m / N
      = m * (2 * Real.pi * (((j : ℤ) * r - c * N : ℤ) : ℝ) / N) + 2 * Real.pi * ((c * m : ℤ) : ℝ) := by
    push_cast; field_simp; ring
  have hone : cis (2 * Real.pi * ((c * m : ℤ) : ℝ)) = 1 := by
    rw [cis_eq_exp]
    have : Complex.I * ((2 * Real.pi * ((c * m : ℤ) : ℝ) : ℝ) : ℂ)
        = ((c * m : ℤ) : ℂ) * (2 * Real.pi * Complex.I) := by push_cast; ring
    rw [this]; exact Complex.exp_int_mul_two_pi_mul_I _
  rw [hsplit, cis_add, hone, mul_one]

/-! ## Geometric sums of phases -/

lemma norm_cis_sub_one (b : ℝ) : ‖cis b - 1‖ = 2 * |Real.sin (b / 2)| := by
  rw [cis_eq_exp, Complex.norm_exp_I_mul_ofReal_sub_one, norm_mul, Real.norm_eq_abs]
  simp

lemma cis_sum_norm (L : ℕ) {t : ℝ} (hs : Real.sin (t / 2) ≠ 0) :
    ‖∑ m ∈ range L, cis (m * t)‖ = |Real.sin (L * t / 2)| / |Real.sin (t / 2)| := by
  have hpow : ∀ m : ℕ, cis (m * t) = cis t ^ m := by
    intro m
    rw [cis_eq_exp, cis_eq_exp, ← Complex.exp_nat_mul]
    congr 1; push_cast; ring
  have hgeom : (∑ m ∈ range L, cis t ^ m) * (cis t - 1) = cis (L * t) - 1 := by
    rw [geom_sum_mul, hpow]
  simp_rw [hpow]
  have h1 : ‖cis (L * t) - 1‖ = ‖∑ m ∈ range L, cis t ^ m‖ * ‖cis t - 1‖ := by
    rw [← hgeom, norm_mul]
  rw [norm_cis_sub_one, norm_cis_sub_one] at h1
  have hpos : 0 < |Real.sin (t / 2)| := abs_pos.mpr hs
  rw [eq_div_iff hpos.ne']
  nlinarith [h1]

/-! ## Jordan's inequality on both sides of `π / 2` -/

lemma jordan_both_sides {t : ℝ} (h0 : 0 ≤ t) (hpi : t ≤ Real.pi) :
    2 / Real.pi * min t (Real.pi - t) ≤ Real.sin t := by
  rcases le_total t (Real.pi / 2) with h | h
  · calc 2 / Real.pi * min t (Real.pi - t) ≤ 2 / Real.pi * t := by
          gcongr; exact min_le_left _ _
      _ ≤ Real.sin t := Real.mul_le_sin h0 h
  · have h' := Real.mul_le_sin (x := Real.pi - t) (by linarith) (by linarith)
    rw [Real.sin_pi_sub] at h'
    calc 2 / Real.pi * min t (Real.pi - t) ≤ 2 / Real.pi * (Real.pi - t) := by
          gcongr; exact min_le_right _ _
      _ ≤ Real.sin t := h'

/-! ## The peak bound -/

/-- Pure real arithmetic behind the peak bound. -/
lemma peak_arith {n s l g : ℝ} (hs : 0 < s) (hsn : s < n) (hl : 0 < l) (hls : l * s ≤ n + s)
    (hg : 2 / Real.pi * ((n - s) / s) ≤ g) :
    4 / (Real.pi ^ 2 * s) * (1 - s / n) ^ 3 ≤ g ^ 2 / (l * n) := by
  have hn : 0 < n := hs.trans hsn
  have hpi := Real.pi_pos
  set g0 := 2 / Real.pi * ((n - s) / s) with hg0
  have hg0nn : 0 ≤ g0 := by
    have : 0 ≤ n - s := by linarith
    positivity
  -- step 1: replace g0 by g
  have step1 : g0 ^ 2 / (l * n) ≤ g ^ 2 / (l * n) := by
    gcongr
  -- step 2: l ≤ (n + s) / s
  have step2 : g0 ^ 2 * s / ((n + s) * n) ≤ g0 ^ 2 / (l * n) := by
    rw [div_le_div_iff₀ (by positivity) (by positivity)]
    have := mul_le_mul_of_nonneg_left hls (by positivity : 0 ≤ g0 ^ 2 * n)
    nlinarith [this]
  -- step 3: the explicit constant
  have step3 : 4 / (Real.pi ^ 2 * s) * (1 - s / n) ^ 3 ≤ g0 ^ 2 * s / ((n + s) * n) := by
    have key : 4 / (Real.pi ^ 2 * s) * (1 - s / n) ^ 3
        = g0 ^ 2 * s / ((n + s) * n) * ((n - s) * (n + s) / n ^ 2) := by
      rw [hg0]; field_simp; ring
    have r2 : (n - s) * (n + s) / n ^ 2 ≤ 1 := by
      rw [div_le_one (by positivity)]; nlinarith
    rw [key]
    exact mul_le_of_le_one_right (by positivity) r2
  linarith

/-- For any period `0 < r < N`, an outcome `j` within `r / 2` of a multiple `c N / r` has
probability at least `4 / (π² r) (1 - r/N)³`. Write `δ = j r - c N` and `φ = π δ / N`; the
amplitude is `|sin (L φ)| / |sin φ|` over `√(L N)`, and Jordan's inequality bounds it below. -/
theorem shor_peak {N r x0 j : ℕ} {c : ℤ} (hr : 0 < r) (hrN : r < N) (hx0 : x0 < r) (hj : j < N)
    (near : 2 * |(j : ℤ) * r - c * N| ≤ r) :
    is_state N (periodic_state N r x0) ∧
      4 / (Real.pi ^ 2 * r) * (1 - (r : ℝ) / N) ^ 3 ≤ prob (qft N (periodic_state N r x0)) j := by
  have hx0N : x0 < N := hx0.trans hrN
  have hN : 0 < N := hr.trans hrN
  set L := ((range N).filter (fun i => i % r = x0)).card with hL
  obtain ⟨hL0, hL1, hL2, -⟩ := residue_count hr hx0 hx0N (fun _ => 0)
  have hLpos : (0 : ℝ) < L := by exact_mod_cast hL0
  have hpi := Real.pi_pos
  have hrR : (0 : ℝ) < r := by exact_mod_cast hr
  have hrNR : (r : ℝ) < N := by exact_mod_cast hrN
  have hNR : (0 : ℝ) < N := by exact_mod_cast hN
  have hLr : (L : ℝ) * r ≤ N + r := by exact_mod_cast hL1
  have hNLr : (N : ℝ) - r ≤ L * r := by
    have : (N : ℝ) ≤ L * r + r := by exact_mod_cast hL2
    linarith
  constructor
  · -- the state is normalised
    set c0 : ℂ := ((1 / Real.sqrt (L : ℝ) : ℝ) : ℂ) with hc0
    have hcc : conj c0 * c0 = ((1 / (L : ℝ) : ℝ) : ℂ) := by
      have : 1 / Real.sqrt (L : ℝ) * (1 / Real.sqrt (L : ℝ)) = 1 / (L : ℝ) := by
        rw [div_mul_div_comm, one_mul, Real.mul_self_sqrt hLpos.le]
      rw [hc0, Complex.conj_ofReal, ← Complex.ofReal_mul, this]
    have h1 : qinner N (periodic_state N r x0) (periodic_state N r x0)
        = ∑ k ∈ range N, (if k < N ∧ k % r = x0 then conj c0 * c0 else 0) := by
      refine sum_congr rfl fun k _ => ?_
      by_cases hk : k < N ∧ k % r = x0 <;> simp [periodic_state, hk, hc0, hL]
    rw [is_state, h1, (residue_count hr hx0 hx0N (fun _ => conj c0 * c0)).2.2.2, ← hL]
    simp only [hcc, sum_const, card_range, nsmul_eq_mul]
    rw [← Complex.ofReal_natCast, ← Complex.ofReal_mul, mul_one_div_cancel hLpos.ne']
    simp
  · -- the peak probability
    set d : ℤ := (j : ℤ) * r - c * N with hd
    set φ : ℝ := Real.pi * (d : ℝ) / N with hφ
    set G : ℂ := ∑ m ∈ range L, cis (m * (2 * φ)) with hG
    have hnormG : ‖qft N (periodic_state N r x0) j‖ = ‖G‖ / (Real.sqrt L * Real.sqrt N) := by
      rw [qft_periodic_norm hr hx0 hx0N j, ← hL]
      congr 2
      refine sum_congr rfl fun m _ => ?_
      rw [phase_shift hN j r m c, ← hd]
      congr 2
      rw [hφ]; ring
    have hprob : prob (qft N (periodic_state N r x0)) j = ‖G‖ ^ 2 / (L * N) := by
      rw [prob, hnormG, div_pow, mul_pow, Real.sq_sqrt hLpos.le, Real.sq_sqrt hNR.le]
    -- lower bound on the modulus of the geometric sum of phases
    have lower : 2 / Real.pi * (((N : ℝ) - r) / r) ≤ ‖G‖ := by
      by_cases hd0 : d = 0
      · have hφ0 : φ = 0 := by simp [hφ, hd0]
        have hG' : G = (L : ℂ) := by simp [hG, hφ0, cis]
        rw [hG', Complex.norm_natCast]
        have h1 : ((N : ℝ) - r) / r ≤ L := by rw [div_le_iff₀ hrR]; exact hNLr
        have h2 : 2 / Real.pi ≤ 1 := by
          rw [div_le_one hpi]; linarith [Real.pi_gt_three]
        have h3 : 0 ≤ ((N : ℝ) - r) / r := by
          apply div_nonneg <;> linarith
        calc 2 / Real.pi * (((N : ℝ) - r) / r) ≤ 1 * (((N : ℝ) - r) / r) := by gcongr
          _ ≤ L := by linarith
      · have hdr : 2 * |(d : ℝ)| ≤ r := by exact_mod_cast near
        have hφle : |φ| ≤ Real.pi * r / (2 * N) := by
          rw [hφ, abs_div, abs_mul, abs_of_pos hpi, abs_of_pos hNR, div_le_div_iff₀ hNR (by positivity)]
          nlinarith [mul_le_mul_of_nonneg_right (mul_le_mul_of_nonneg_left hdr hpi.le) hNR.le]
        have hφpos : 0 < |φ| := by
          rw [hφ]; positivity
        have hsmall : |φ| < Real.pi / 2 := by
          refine lt_of_le_of_lt hφle ?_
          rw [div_lt_div_iff₀ (by positivity) (by norm_num)]
          nlinarith
        -- `sin |φ|` is positive and `|sin φ| = sin |φ| ≤ |φ|`
        have hsinpos : 0 < Real.sin |φ| :=
          Real.sin_pos_of_pos_of_lt_pi hφpos (by linarith)
        have hbd : -Real.pi < φ ∧ φ < Real.pi := abs_lt.mp (lt_trans hsmall (by linarith))
        have habs_sin : |Real.sin φ| = Real.sin |φ| := by
          rcases le_total 0 φ with h | h
          · rw [abs_of_nonneg h, abs_of_nonneg (Real.sin_nonneg_of_nonneg_of_le_pi h hbd.2.le)]
          · have hs := Real.sin_nonneg_of_nonneg_of_le_pi (x := -φ) (by linarith) (by linarith)
            rw [Real.sin_neg] at hs
            rw [abs_of_nonpos h, Real.sin_neg, abs_of_nonpos (by linarith : Real.sin φ ≤ 0)]
        have hsin1 : 0 < |Real.sin φ| := habs_sin ▸ hsinpos
        have hsin2 : |Real.sin φ| ≤ |φ| := habs_sin ▸ Real.sin_le hφpos.le
        set t : ℝ := L * |φ| with ht
        have ht0 : 0 ≤ t := by positivity
        have htpi : t ≤ Real.pi := by
          calc t ≤ L * (Real.pi * r / (2 * N)) := by rw [ht]; gcongr
            _ = Real.pi / 2 * (L * r / N) := by field_simp
            _ ≤ Real.pi / 2 * 2 := by
              gcongr
              rw [div_le_iff₀ hNR]; linarith
            _ = Real.pi := by ring
        have hsinL : |Real.sin (L * φ)| = Real.sin t := by
          rcases le_total 0 φ with h | h
          · have e : t = L * φ := by rw [ht, abs_of_nonneg h]
            rw [← e]; exact abs_of_nonneg (Real.sin_nonneg_of_nonneg_of_le_pi ht0 htpi)
          · have e : t = -(L * φ) := by rw [ht, abs_of_nonpos h]; ring
            have hst := Real.sin_nonneg_of_nonneg_of_le_pi ht0 htpi
            rw [e, Real.sin_neg] at hst ⊢
            exact abs_of_nonpos (by linarith)
        have hnorm : ‖G‖ = Real.sin t / |Real.sin φ| := by
          have hs : Real.sin (2 * φ / 2) ≠ 0 := by
            rw [mul_div_cancel_left₀ _ two_ne_zero]; exact (abs_pos.mp hsin1)
          have := cis_sum_norm L hs
          rw [mul_div_cancel_left₀ _ (two_ne_zero' ℝ)] at this
          rw [hG, this, ← hsinL]; congr 2; ring_nf
        -- Jordan's inequality, applied on whichever side of `π / 2` the angle `L φ` lies
        have hmin : 2 / Real.pi * (((N : ℝ) - r) / r) * |φ| ≤ 2 / Real.pi * min t (Real.pi - t) := by
          have hA : ((N : ℝ) - r) / r * |φ| ≤ t := by
            rw [ht]; gcongr
            rw [div_le_iff₀ hrR]; exact hNLr
          have hB : ((N : ℝ) - r) / r * |φ| ≤ Real.pi - t := by
            have hsum : (L : ℝ) + ((N : ℝ) - r) / r ≤ 2 * N / r := by
              have : (L : ℝ) + ((N : ℝ) - r) / r = (L * r + (N - r)) / r := by field_simp
              rw [this]; gcongr; linarith
            have : ((L : ℝ) + ((N : ℝ) - r) / r) * |φ| ≤ (2 * N / r) * (Real.pi * r / (2 * N)) := by
              gcongr
            have h2 : (2 * (N : ℝ) / r) * (Real.pi * r / (2 * N)) = Real.pi := by field_simp
            rw [ht]; nlinarith
          have := le_min hA hB
          rw [mul_assoc]; gcongr
        have hsin_t := jordan_both_sides ht0 htpi
        have h5 : 2 / Real.pi * (((N : ℝ) - r) / r) ≤ Real.sin t / |φ| := by
          rw [le_div_iff₀ hφpos]; exact hmin.trans hsin_t
        rw [hnorm]
        exact h5.trans (div_le_div_of_nonneg_left (Real.sin_nonneg_of_nonneg_of_le_pi ht0 htpi) hsin1 hsin2)
    rw [hprob]
    exact peak_arith hrR hrNR hLpos hLr lower

/-! ## Recovering the period -/

/-- If `j/N` is within `1/(2N)` of `c/r` with `c` coprime to `r` and `r² < N`, no fraction with a
smaller denominator is that close: two such fractions `c/r ≠ a/b` would differ by at least
`1/(r b) > 1/N`. -/
lemma recover_period {N r j : ℕ} {c : ℤ} (hr : 0 < r) (hrr : r * r < N) (hcop : IsCoprime c (r : ℤ))
    (near : 2 * |(j : ℤ) * r - c * N| ≤ r) : recover N j = r := by
  refine recover_eq_of_least ⟨hr, c, near⟩ ?_
  rintro b ⟨hb, a, hab⟩
  by_contra hrb
  have hbr : b < r := not_le.mp hrb
  -- N |b c - a r| = |r (j b - a N) - b (j r - c N)| ≤ r b
  have hid : (N : ℤ) * |(b : ℤ) * c - a * r|
      = |(r : ℤ) * ((j : ℤ) * b - a * N) - b * ((j : ℤ) * r - c * N)| := by
    have : (r : ℤ) * ((j : ℤ) * b - a * N) - b * ((j : ℤ) * r - c * N)
        = N * ((b : ℤ) * c - a * r) := by ring
    rw [this, abs_mul, Nat.abs_cast]
  have hle : (N : ℤ) * |(b : ℤ) * c - a * r| ≤ r * b := by
    have htri : |(r : ℤ) * ((j : ℤ) * b - a * N) - b * ((j : ℤ) * r - c * N)|
        ≤ r * |(j : ℤ) * b - a * N| + b * |(j : ℤ) * r - c * N| := by
      refine (abs_sub _ _).trans ?_
      rw [abs_mul, abs_mul, Nat.abs_cast, Nat.abs_cast]
    have h1 : (r : ℤ) * (2 * |(j : ℤ) * b - a * N|) ≤ r * b :=
      mul_le_mul_of_nonneg_left hab (by positivity)
    have h2 : (b : ℤ) * (2 * |(j : ℤ) * r - c * N|) ≤ b * r :=
      mul_le_mul_of_nonneg_left near (by positivity)
    rw [hid]; nlinarith
  have hlt : (r : ℤ) * b < N := by
    have : r * b < N := lt_of_le_of_lt (Nat.mul_le_mul_left r hbr.le) (by nlinarith)
    exact_mod_cast this
  -- hence b c = a r
  have hzero : |(b : ℤ) * c - a * r| < 1 := by
    by_contra h
    push Not at h
    nlinarith
  have heq : (b : ℤ) * c = a * r := by
    have := abs_lt.mp hzero
    omega
  -- so r divides b, contradicting 0 < b < r
  have hdvd : (r : ℤ) ∣ (b : ℤ) * c := ⟨a, by rw [heq]; ring⟩
  have hdvd' : (r : ℤ) ∣ b := hcop.symm.dvd_of_dvd_mul_right hdvd
  have : r ∣ b := Int.natCast_dvd_natCast.mp hdvd'
  exact absurd (Nat.le_of_dvd hb this) (not_le.mpr hbr)

/-- One run of Shor's algorithm (QFT, measure `j`, output `recover N j`) returns the period with
probability at least `4/π² · φ(r)/r · (1 - r/N)³`: each `c < r` coprime to `r` has its own nearest
outcome `j_c = round (c N / r)`, these are distinct, and each is recovered and has the peak
probability. -/
theorem shor_general_success {N r x0 : ℕ} (hr : 0 < r) (hrr : r * r < N) (hx0 : x0 < r) :
    4 / Real.pi ^ 2 * ((((range r).filter (fun c => Nat.Coprime c r)).card : ℝ) / r)
        * (1 - (r : ℝ) / N) ^ 3
      ≤ ∑ j ∈ (range N).filter (fun j => recover N j = r),
          prob (qft N (periodic_state N r x0)) j := by
  have hrN : r < N := lt_of_le_of_lt (Nat.le_mul_self r) hrr
  set C := (range r).filter (fun c => Nat.Coprime c r) with hC
  set jc : ℕ → ℕ := fun c => (2 * c * N + r) / (2 * r) with hjc
  set bound : ℝ := 4 / (Real.pi ^ 2 * r) * (1 - (r : ℝ) / N) ^ 3 with hbound
  -- `jc c` is the integer nearest to `c N / r`
  have near : ∀ c : ℕ, 2 * |((jc c : ℕ) : ℤ) * r - (c : ℤ) * N| ≤ r := by
    intro c
    have lo : jc c * (2 * r) ≤ 2 * c * N + r := Nat.div_mul_le_self _ _
    have hi : 2 * c * N + r < r * (jc c + 1) * 2 := by
      have := Nat.lt_mul_div_succ (2 * c * N + r) (by omega : 0 < 2 * r)
      show _ < r * ((2 * c * N + r) / (2 * r) + 1) * 2
      linarith
    have lo' : (2 * ((jc c : ℤ) * r)) ≤ 2 * ((c : ℤ) * N) + r := by
      have : ((jc c * (2 * r) : ℕ) : ℤ) ≤ ((2 * c * N + r : ℕ) : ℤ) := by exact_mod_cast lo
      push_cast at this; linarith
    have hi' : 2 * ((c : ℤ) * N) + r < 2 * ((jc c : ℤ) * r) + 2 * r := by
      have : ((2 * c * N + r : ℕ) : ℤ) < ((r * (jc c + 1) * 2 : ℕ) : ℤ) := by
        exact_mod_cast hi
      push_cast at this; linarith
    rcases abs_cases ((jc c : ℤ) * r - (c : ℤ) * N) with ⟨h, _⟩ | ⟨h, _⟩ <;> rw [h] <;> linarith
  have jc_lt : ∀ c : ℕ, c < r → jc c < N := by
    intro c hc
    have h1 : (c + 1) * N ≤ r * N := Nat.mul_le_mul_right N hc
    show (2 * c * N + r) / (2 * r) < N
    rw [Nat.div_lt_iff_lt_mul (by omega)]
    nlinarith
  -- every `jc c` is an outcome from which the period is recovered
  have hit : C.image jc ⊆ (range N).filter (fun j => recover N j = r) := by
    intro j hj
    obtain ⟨c, hcC, rfl⟩ := mem_image.mp hj
    obtain ⟨hcr, hcop⟩ := mem_filter.mp hcC
    have hcop' : IsCoprime (c : ℤ) (r : ℤ) := Nat.isCoprime_iff_coprime.mpr hcop
    exact mem_filter.mpr ⟨mem_range.mpr (jc_lt c (mem_range.mp hcr)),
      recover_period hr hrr hcop' (near c)⟩
  -- distinct `c` give distinct outcomes
  have hinj : Set.InjOn jc (C : Set ℕ) := by
    intro c _ c' _ heq
    have h1 := near c
    have h2 := near c'
    rw [heq] at h1
    have h3 : |((c : ℤ) - c') * N| ≤ r := by
      have : (c - c') * (N : ℤ) = (((jc c' : ℕ) : ℤ) * r - c' * N) - (((jc c' : ℕ) : ℤ) * r - c * N) := by
        ring
      rw [this]
      refine (abs_sub _ _).trans ?_
      rw [abs_sub_comm (((jc c' : ℕ) : ℤ) * r) (c * N)] at h1 ⊢
      linarith [abs_nonneg (((jc c' : ℕ) : ℤ) * r - c' * N)]
    have h4 : |(c : ℤ) - c'| < 1 := by
      by_contra h
      push Not at h
      rw [abs_mul, Nat.abs_cast] at h3
      nlinarith
    have := abs_lt.mp h4
    omega
  have peak : ∀ c ∈ C, bound ≤ prob (qft N (periodic_state N r x0)) (jc c) := by
    intro c hc
    have hcr := mem_range.mp (mem_filter.mp hc).1
    exact (shor_peak hr hrN hx0 (jc_lt c hcr) (near c)).2
  calc 4 / Real.pi ^ 2 * (((C.card : ℝ)) / r) * (1 - (r : ℝ) / N) ^ 3
      = ∑ _c ∈ C, bound := by
        rw [sum_const, nsmul_eq_mul, hbound]; field_simp
    _ ≤ ∑ c ∈ C, prob (qft N (periodic_state N r x0)) (jc c) := sum_le_sum peak
    _ = ∑ j ∈ C.image jc, prob (qft N (periodic_state N r x0)) j := (sum_image hinj).symm
    _ ≤ ∑ j ∈ (range N).filter (fun j => recover N j = r),
          prob (qft N (periodic_state N r x0)) j :=
        sum_le_sum_of_subset_of_nonneg hit fun _ _ _ => by unfold prob; positivity
