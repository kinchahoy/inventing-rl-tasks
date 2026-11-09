import Mathlib.GroupTheory.Sylow

/-- Cauchy's theorem: if a prime `p` divides the order of a finite group, some element has
order `p`. -/
theorem cauchy (G : Type*) [Group G] [Fintype G] (p : ℕ) [hp : Fact p.Prime]
    (hdvd : p ∣ Fintype.card G) : ∃ x : G, orderOf x = p := by
  have hcard0 : Fintype.card G ≠ 0 := Fintype.card_ne_zero
  -- write |G| = p^e * m with p ∤ m
  obtain ⟨e, m, hm, hem⟩ := Nat.exists_eq_pow_mul_and_not_dvd hcard0 p hp.out.ne_one
  have he : e ≠ 0 := by
    rintro rfl
    simp only [pow_zero, one_mul] at hem
    exact hm (hem ▸ hdvd)
  -- a subgroup of order p^e
  have hpe : p ^ e ∣ Nat.card G := by
    rw [Nat.card_eq_fintype_card, hem]; exact Dvd.intro _ rfl
  obtain ⟨K, hK⟩ := Sylow.exists_subgroup_card_pow_prime p hpe
  -- K is nontrivial, so it has an element x ≠ 1
  have hKnt : Nontrivial K := by
    rw [← Finite.one_lt_card_iff_nontrivial, hK]
    exact Nat.one_lt_pow he hp.out.one_lt
  obtain ⟨x, hx⟩ := exists_ne (1 : K)
  -- its order is a power p^j of p, with j ≥ 1
  have hdiv : orderOf x ∣ p ^ e := hK ▸ orderOf_dvd_natCard x
  obtain ⟨j, hj, hxj⟩ := (Nat.dvd_prime_pow hp.out).mp hdiv
  have hj0 : j ≠ 0 := by
    rintro rfl
    exact hx (orderOf_eq_one_iff.mp (by simpa using hxj))
  -- y = x^(p^(j-1)) has order p
  have hpdvd : p ∣ orderOf x := by
    rw [hxj]; exact dvd_pow_self p hj0
  have hord : orderOf (x ^ (orderOf x / p)) = p :=
    orderOf_pow_orderOf_div (orderOf_pos x).ne' hpdvd
  refine ⟨((x ^ (orderOf x / p) : K) : G), ?_⟩
  rw [Subgroup.orderOf_coe, hord]

#print axioms cauchy
