/-
Exact-case Shor: Lean 4 + Mathlib counterpart of `Shor_Exact.thy`.
The definitions mirror `Quantum_Basics.thy`; the theorems `shor_core`, `shor_factor`
and `shor_success` state exactly what their Isabelle namesakes state.
-/
import Mathlib

open Complex ComplexConjugate Finset Real

noncomputable section

abbrev Vec := ℕ → ℂ

/-- `⟨u|v⟩ = ∑_{i<n} conj (u i) * v i` -/
def qinner (n : ℕ) (u v : Vec) : ℂ := ∑ i ∈ range n, conj (u i) * v i

def is_state (n : ℕ) (v : Vec) : Prop := qinner n v v = 1

/-- `cis θ = cos θ + i sin θ` -/
def cis (θ : ℝ) : ℂ := (Real.cos θ : ℂ) + (Real.sin θ : ℂ) * I

lemma cis_eq_exp (θ : ℝ) : cis θ = exp (θ * I) := by
  rw [exp_mul_I, cis, ← ofReal_cos, ← ofReal_sin]

lemma cis_add (a b : ℝ) : cis (a + b) = cis a * cis b := by
  simp only [cis_eq_exp, ofReal_add, add_mul, Complex.exp_add]

lemma norm_cis (θ : ℝ) : ‖cis θ‖ = 1 := by
  rw [cis_eq_exp]; exact norm_exp_ofReal_mul_I θ

/-- Computational basis state `|k⟩`. -/
def ket (k : ℕ) : Vec := fun i => if i = k then 1 else 0

/-- `u ⊗ v` with `v` of dimension `n`, indexed as `i = n * a + b`. -/
def tensor (n : ℕ) (u v : Vec) : Vec := fun i => u (i / n) * v (i % n)

/-- `|v j|²` -/
def prob (v : Vec) (j : ℕ) : ℝ := ‖v j‖ ^ 2

/-- Quantum Fourier transform on `ℤ_N`. -/
def qft (N : ℕ) (v : Vec) : Vec := fun j =>
  (∑ k ∈ range N, cis (2 * π * (j : ℝ) * (k : ℝ) / (N : ℝ)) * v k) / ((√(N : ℝ) : ℝ) : ℂ)

/-- Uniform superposition over `{x0, x0 + r, x0 + 2r, …} ⊆ ℤ_N`, normalised by the number of
such indices (which is `N / r` when `r ∣ N`). -/
def periodic_state (N r x0 : ℕ) : Vec := fun k =>
  if k < N ∧ k % r = x0
  then (((1 / √(((range N).filter (fun i => i % r = x0)).card : ℝ) : ℝ)) : ℂ) else 0

/-- `r` is the multiplicative order of `a` modulo `n`. -/
def is_order (n a r : ℕ) : Prop :=
  0 < r ∧ a ^ r % n = 1 ∧ ∀ k, 0 < k → k < r → a ^ k % n ≠ 1

/-- The residue class `x0 mod r` below `N = M * r` is `{x0 + m * r | m < M}`. -/
lemma residue_class {M r x0 : ℕ} (hx : x0 < r) :
    (range (M * r)).filter (fun k => k % r = x0) = (range M).image (fun m => x0 + m * r) := by
  ext k
  simp only [mem_filter, mem_range, mem_image]
  constructor
  · rintro ⟨hk, hmod⟩
    refine ⟨k / r, Nat.div_lt_of_lt_mul (by rwa [mul_comm]), ?_⟩
    have := Nat.mod_add_div k r
    rw [hmod, Nat.mul_comm r] at this; exact this
  · rintro ⟨m, hm, rfl⟩
    refine ⟨?_, ?_⟩
    · nlinarith
    · simp [Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hx]

lemma residue_injOn {M r x0 : ℕ} (hr : 0 < r) :
    Set.InjOn (fun m => x0 + m * r) (range M : Set ℕ) := by
  intro a _ b _ hab
  exact Nat.eq_of_mul_eq_mul_right hr (Nat.add_left_cancel hab)

/-- When `r ∣ N`, the residue class has exactly `N / r` elements. -/
lemma residue_card {M r x0 : ℕ} (hr : 0 < r) (hx : x0 < r) :
    ((range (M * r)).filter (fun i => i % r = x0)).card = M := by
  rw [residue_class hx, card_image_of_injOn (residue_injOn hr), card_range]

/-- Sum of a function over the residue class `x0 mod r` below `N = M * r`. -/
lemma sum_residue_class {M r x0 : ℕ} (hr : 0 < r) (hx : x0 < r) (h : ℕ → ℂ) :
    ∑ k ∈ range (M * r), (if k < M * r ∧ k % r = x0 then h k else 0)
      = ∑ m ∈ range M, h (x0 + m * r) := by
  calc _ = ∑ k ∈ (range (M * r)).filter (fun k => k % r = x0), h k := by
        rw [sum_filter]
        exact sum_congr rfl fun k hk => by simp [mem_range.mp hk]
    _ = _ := by rw [residue_class hx, sum_image (residue_injOn hr)]

/-- Orthogonality of additive characters on `ℤ_M`. -/
lemma root_of_unity_sum (M j : ℕ) [NeZero M] :
    ∑ m ∈ range M, cis (2 * π * (j : ℝ) * (m : ℝ) / (M : ℝ))
      = if M ∣ j then (M : ℂ) else 0 := by
  have hchar : ∀ m : ℕ, cis (2 * π * (j : ℝ) * (m : ℝ) / (M : ℝ))
      = ZMod.stdAddChar ((m : ZMod M) * (j : ZMod M)) := by
    intro m
    have := ZMod.stdAddChar_coe (N := M) ((j * m : ℕ) : ℤ)
    push_cast at this
    rw [mul_comm (m : ZMod M), this, cis_eq_exp]
    congr 1
    push_cast; ring
  simp_rw [hchar]
  have hsum : ∑ m ∈ range M, ZMod.stdAddChar ((m : ZMod M) * (j : ZMod M))
      = ∑ x : ZMod M, ZMod.stdAddChar (x * (j : ZMod M)) :=
    Finset.sum_nbij' (fun m : ℕ => (m : ZMod M)) (fun x : ZMod M => x.val)
      (fun m hm => mem_univ _) (fun x _ => mem_range.mpr (ZMod.val_lt x))
      (fun m hm => ZMod.val_natCast_of_lt (mem_range.mp hm))
      (fun x _ => ZMod.natCast_zmod_val x) (fun _ _ => rfl)
  rw [hsum]
  rw [AddChar.sum_mulShift (j : ZMod M) (ZMod.isPrimitive_stdAddChar M)]
  simp [ZMod.natCast_eq_zero_iff]

lemma cis_split (M r x0 j m : ℕ) (hM : 0 < M) (hr : 0 < r) :
    cis (2 * π * (j : ℝ) * ((x0 + m * r : ℕ) : ℝ) / ((M * r : ℕ) : ℝ))
      = cis (2 * π * (j : ℝ) * (x0 : ℝ) / ((M * r : ℕ) : ℝ))
        * cis (2 * π * (j : ℝ) * (m : ℝ) / (M : ℝ)) := by
  rw [← cis_add]
  congr 1
  have : (M : ℝ) ≠ 0 := by positivity
  have : (r : ℝ) ≠ 0 := by positivity
  push_cast
  field_simp

/-- Born-rule statistics of the Fourier transform of a periodic state. -/
theorem shor_core {N r x0 : ℕ} (N0 : 0 < N) (r0 : 0 < r) (hdvd : r ∣ N) (hx : x0 < r) :
    is_state N (periodic_state N r x0) ∧
      ∀ j < N, prob (qft N (periodic_state N r x0)) j
        = if (N / r) ∣ j then 1 / (r : ℝ) else 0 := by
  obtain ⟨M, rfl⟩ : ∃ M, N = M * r := by obtain ⟨M, h⟩ := hdvd; exact ⟨M, by rw [h, mul_comm]⟩
  have hM : 0 < M := Nat.pos_of_ne_zero (by rintro rfl; simp at N0)
  have : NeZero M := ⟨hM.ne'⟩
  have hdiv : M * r / r = M := Nat.mul_div_cancel M r0
  have hcard := residue_card (M := M) (x0 := x0) r0 hx
  have hMr : (0 : ℝ) < M := by exact_mod_cast hM
  have hrr : (0 : ℝ) < r := by exact_mod_cast r0
  set c : ℂ := (((1 / √(M : ℝ) : ℝ)) : ℂ) with hc
  have hcc : conj c * c = ((1 / (M : ℝ) : ℝ) : ℂ) := by
    rw [hc, conj_ofReal, ← ofReal_mul]
    congr 1
    rw [div_mul_div_comm, one_mul, Real.mul_self_sqrt hMr.le]
  have hv : periodic_state (M * r) r x0 = fun k => if k < M * r ∧ k % r = x0 then c else 0 := by
    funext k; simp only [periodic_state, hcard, hc]
  refine ⟨?_, fun j hj => ?_⟩
  · -- unit norm
    unfold is_state qinner
    rw [hv]
    have : ∀ k : ℕ, conj (if k < M * r ∧ k % r = x0 then c else 0)
        * (if k < M * r ∧ k % r = x0 then c else 0)
        = if k < M * r ∧ k % r = x0 then conj c * c else 0 := by
      intro k; split_ifs <;> simp
    simp_rw [this]
    rw [sum_residue_class r0 hx (fun _ => conj c * c), hcc]
    simp
  · -- outcome probabilities
    have hamp : qft (M * r) (periodic_state (M * r) r x0) j
        = c * cis (2 * π * (j : ℝ) * (x0 : ℝ) / ((M * r : ℕ) : ℝ))
          * (∑ m ∈ range M, cis (2 * π * (j : ℝ) * (m : ℝ) / (M : ℝ)))
          / ((√((M * r : ℕ) : ℝ) : ℝ) : ℂ) := by
      simp only [qft, hv]
      have : ∀ k : ℕ, cis (2 * π * (j : ℝ) * (k : ℝ) / ((M * r : ℕ) : ℝ))
          * (if k < M * r ∧ k % r = x0 then c else 0)
          = if k < M * r ∧ k % r = x0
            then cis (2 * π * (j : ℝ) * (k : ℝ) / ((M * r : ℕ) : ℝ)) * c else 0 := by
        intro k; split_ifs <;> simp
      simp_rw [this]
      rw [sum_residue_class r0 hx
        (fun k => cis (2 * π * (j : ℝ) * (k : ℝ) / ((M * r : ℕ) : ℝ)) * c)]
      simp_rw [cis_split M r x0 j _ hM r0, Finset.mul_sum, Finset.sum_div]
      refine sum_congr rfl fun m _ => by ring
    rw [hdiv]
    by_cases hj' : M ∣ j
    · rw [prob, hamp, root_of_unity_sum]
      simp only [hj', ite_true]
      simp only [norm_div, norm_mul, norm_cis, mul_one, hc, norm_real, Real.norm_eq_abs,
        Complex.norm_natCast]
      rw [div_pow, mul_pow, div_pow, abs_of_nonneg (by positivity), sq_abs]
      push_cast
      rw [Real.sq_sqrt (by positivity), sq_abs, Real.sq_sqrt (by positivity)]
      field_simp
    · rw [prob, hamp, root_of_unity_sum]
      simp only [hj', ite_false]
      simp

/-- An even period with `a^(r/2) ≢ -1` yields a nontrivial factor of `n`. -/
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

/-- For `j = M * k` with `N = M * r`, the outcome `j` reveals the period iff `k` is coprime to `r`. -/
lemma period_recovered {M r : ℕ} (hM : 0 < M) (hr : 0 < r) (k : ℕ) :
    M * r / Nat.gcd (M * k) (M * r) = r ↔ Nat.Coprime k r := by
  rw [Nat.gcd_mul_left, Nat.mul_div_mul_left _ _ hM, Nat.div_eq_self]
  simp [hr.ne', Nat.Coprime]

/-- The probability of observing an outcome that determines the period `r` is `φ(r) / r`. -/
theorem shor_success {N r x0 : ℕ} (N0 : 0 < N) (r0 : 0 < r) (hdvd : r ∣ N) (hx : x0 < r) :
    ∑ j ∈ (range N).filter (fun j => N / Nat.gcd j N = r),
        prob (qft N (periodic_state N r x0)) j
      = (((range r).filter (fun k => Nat.Coprime k r)).card : ℝ) / (r : ℝ) := by
  obtain ⟨M, rfl⟩ : ∃ M, N = M * r := by obtain ⟨M, h⟩ := hdvd; exact ⟨M, by rw [h, mul_comm]⟩
  have hM : 0 < M := Nat.pos_of_ne_zero (by rintro rfl; simp at N0)
  have : NeZero r := ⟨r0.ne'⟩
  have hdiv : M * r / r = M := Nat.mul_div_cancel M r0
  have hcore := (shor_core N0 r0 hdvd hx).2
  set J := (range (M * r)).filter (fun j => M * r / Nat.gcd j (M * r) = r) with hJ
  -- only multiples of `M` contribute, each with probability `1 / r`
  have hsum : ∑ j ∈ J, prob (qft (M * r) (periodic_state (M * r) r x0)) j
      = ∑ j ∈ J, if M ∣ j then 1 / (r : ℝ) else 0 :=
    sum_congr rfl fun j hj => by rw [hcore j (mem_range.mp (mem_filter.mp hj).1), hdiv]
  -- successful outcomes correspond to units of `ℤ_r`
  have hcard : (J.filter (fun j => M ∣ j)).card = Fintype.card (ZMod r)ˣ := by
    symm
    refine Finset.card_bij (fun (u : (ZMod r)ˣ) _ => M * (u : ZMod r).val) ?_ ?_ ?_
    · intro u _
      have hv : (u : ZMod r).val < r := ZMod.val_lt _
      have hcop : Nat.Coprime (u : ZMod r).val r := by
        rw [← ZMod.isUnit_iff_coprime, ZMod.natCast_zmod_val]; exact u.isUnit
      simp only [hJ, mem_filter, mem_range]
      exact ⟨⟨by nlinarith, (period_recovered hM r0 _).mpr hcop⟩, dvd_mul_right _ _⟩
    · intro a _ b _ h
      exact Units.ext (ZMod.val_injective r (Nat.eq_of_mul_eq_mul_left hM h))
    · intro j hj
      simp only [hJ, mem_filter, mem_range] at hj
      obtain ⟨⟨hjN, hjr⟩, k, rfl⟩ := hj
      have hk : k < r := Nat.lt_of_mul_lt_mul_left hjN
      have hcop : Nat.Coprime k r := (period_recovered hM r0 k).mp hjr
      refine ⟨ZMod.unitOfCoprime k hcop, mem_univ _, ?_⟩
      rw [ZMod.coe_unitOfCoprime, ZMod.val_natCast, Nat.mod_eq_of_lt hk]
  have hfinal : (J.filter (fun j => M ∣ j)).card = ((range r).filter (fun k => Nat.Coprime k r)).card := by
    rw [hcard, ZMod.card_units_eq_totient, Nat.totient_eq_card_coprime]
    congr 1
    ext k
    simp [Nat.coprime_comm]
  rw [hsum, ← sum_filter, sum_const, nsmul_eq_mul, mul_one_div, hfinal]
