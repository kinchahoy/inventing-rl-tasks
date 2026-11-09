theory Shor_General
  imports Quantum_Basics
begin

theorem shor_factor:
  assumes n: "1 < n" and ord: "is_order n a r" and even: "even r"
    and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
  sorry

lemma core_sum_lower:
  fixes M :: nat and a u w :: real
  assumes u: "0 \<le> u" "u < 1"
    and w: "1 - u \<le> w" "w \<le> 1 + u"
    and T: "real M * \<bar>a\<bar> \<le> pi * w / 2"
  shows "4 / pi\<^sup>2 * (1 - u)^3 / w * (real M)\<^sup>2 \<le> (cmod (\<Sum>m<M. cis (2 * a * real m)))\<^sup>2"
  sorry

lemma peak_set:
  fixes N r x0 :: nat
  assumes r: "0 < r" and x0: "x0 < r" and rN: "r < N"
  obtains M where "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
    and "inj_on (\<lambda>m. x0 + r * m) {..<M}"
    and "N \<le> x0 + r * M" and "r * M < N + r"
proof -
  have ex: "\<exists>m. N \<le> x0 + r * m"
  proof -
    have h1: "1 \<le> r" using r by simp
    have "N \<le> r * N" using mult_le_mono1[OF h1, of N] by simp
    then have "N \<le> x0 + r * N" by linarith
    then show ?thesis by blast
  qed
  define M where "M = (LEAST m. N \<le> x0 + r * m)"
  have spec: "N \<le> x0 + r * M"
    unfolding M_def using LeastI_ex[OF ex] by simp
  have below: "\<And>m. m < M \<Longrightarrow> x0 + r * m < N"
  proof -
    fix m assume mM: "m < M"
    have "\<not> (N \<le> x0 + r * m)"
      using mM unfolding M_def by (rule not_less_Least)
    then show "x0 + r * m < N" by simp
  qed
  have mem: "\<And>i. (i < N \<and> i mod r = x0) = (\<exists>m<M. i = x0 + r * m)"
  proof -
    fix i show "(i < N \<and> i mod r = x0) = (\<exists>m<M. i = x0 + r * m)"
    proof
      assume h: "i < N \<and> i mod r = x0"
      have dm: "i div r * r + i mod r = i" by (rule div_mult_mod_eq)
      have i_eq: "i = x0 + r * (i div r)"
        using dm h by (simp add: mult.commute)
      have lt: "i div r < M"
      proof (rule ccontr)
        assume "\<not> i div r < M"
        then have "M \<le> i div r" by simp
        then have "r * M \<le> r * (i div r)" by simp
        with spec i_eq h show False by linarith
      qed
      show "\<exists>m<M. i = x0 + r * m"
        using lt i_eq by (intro exI[of _ "i div r"]) (auto simp: mult.commute)
    next
      assume "\<exists>m<M. i = x0 + r * m"
      then obtain m where mM: "m < M" and i: "i = x0 + r * m" by blast
      have "i < N" using below[OF mM] i by simp
      moreover have "i mod r = x0"
        using x0 by (simp add: i mod_mult_self1)
      ultimately show "i < N \<and> i mod r = x0" by simp
    qed
  qed
  have set_eq: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
  proof (intro set_eqI)
    fix i
    show "i \<in> {i. i < N \<and> i mod r = x0} \<longleftrightarrow> i \<in> (\<lambda>m. x0 + r * m) ` {..<M}"
      using mem[of i] by auto
  qed
  have inj: "inj_on (\<lambda>m. x0 + r * m) {..<M}"
  proof (rule inj_onI)
    fix a b assume "a \<in> {..<M}" "b \<in> {..<M}" "x0 + r * a = x0 + r * b"
    then have "r * a = r * b" by simp
    with r show "a = b" by simp
  qed
  have M_pos: "0 < M"
  proof (rule ccontr)
    assume "\<not> 0 < M"
    then have "M = 0" by simp
    with spec have "N \<le> x0" by simp
    with x0 rN show False by linarith
  qed
  have lt: "r * M < N + r"
  proof -
    obtain M' where M': "M = Suc M'" using M_pos by (cases M) auto
    have "x0 + r * M' < N" using below[of M'] M' by simp
    then show ?thesis using M' by (simp add: algebra_simps)
  qed
  show ?thesis by (rule that[OF set_eq inj spec lt])
qed

lemma peak_sum:
  fixes N r x0 M :: nat and g :: "nat \<Rightarrow> complex"
  assumes set_eq: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
    and inj: "inj_on (\<lambda>m. x0 + r * m) {..<M}"
  shows "(\<Sum>k<N. if k < N \<and> k mod r = x0 then g k else 0) = (\<Sum>m<M. g (x0 + r * m))"
proof -
  let ?F = "(\<lambda>m. x0 + r * m) ` {..<M}"
  have mem2: "\<And>k. (k < N \<and> k mod r = x0) = (k \<in> ?F)"
  proof -
    fix k
    have "k \<in> {i. i < N \<and> i mod r = x0} = (k \<in> ?F)" by (subst set_eq) (rule refl)
    then show "(k < N \<and> k mod r = x0) = (k \<in> ?F)" by (simp add: mem_Collect_eq)
  qed
  have sub: "?F \<subseteq> {..<N}"
  proof
    fix k assume kF: "k \<in> ?F"
    have "k < N \<and> k mod r = x0" using mem2[of k] kF by blast
    then show "k \<in> {..<N}" by simp
  qed
  have "(\<Sum>k<N. if k < N \<and> k mod r = x0 then g k else 0) = (\<Sum>k\<in>?F. g k)"
  proof (rule sum.mono_neutral_cong_right)
    show "finite {..<N}" by simp
  next
    show "?F \<subseteq> {..<N}" by (rule sub)
  next
    show "\<forall>k\<in>{..<N} - ?F. (if k < N \<and> k mod r = x0 then g k else 0) = 0"
    proof
      fix k assume kd: "k \<in> {..<N} - ?F"
      then have kn: "k \<notin> ?F" by simp
      have notP: "\<not> (k < N \<and> k mod r = x0)" using mem2[of k] kn by blast
      show "(if k < N \<and> k mod r = x0 then g k else 0) = 0" using notP by auto
    qed
  next
    fix k assume kF: "k \<in> ?F"
    have P: "k < N \<and> k mod r = x0" using mem2[of k] kF by blast
    show "(if k < N \<and> k mod r = x0 then g k else 0) = g k" using P by auto
  qed
  also have "\<dots> = (\<Sum>m<M. g (x0 + r * m))"
    by (subst sum.reindex[OF inj]) (simp add: comp_def)
  finally show ?thesis .
qed

lemma peak_psi:
  fixes N r x0 M :: nat
  assumes set_eq: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
    and inj: "inj_on (\<lambda>m. x0 + r * m) {..<M}"
  shows "periodic_state N r x0 = (\<lambda>k. if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real M)) else 0)"
proof -
  have card_M: "card {i. i < N \<and> i mod r = x0} = M"
    by (simp add: set_eq card_image inj)
  show ?thesis unfolding periodic_state_def card_M by (rule refl)
qed

lemma peak_cnj_if:
  "cnj (if P then c else 0) * (if P then c else 0) = (if P then cnj c * c else (0::complex))"
  by (cases P) simp_all

lemma peak_state:
  fixes N r x0 M :: nat
  assumes set_eq: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
    and inj: "inj_on (\<lambda>m. x0 + r * m) {..<M}" and M_pos: "0 < M"
  shows "is_state N (periodic_state N r x0)"
proof -
  have psi: "periodic_state N r x0 = (\<lambda>k. if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real M)) else 0)"
    by (rule peak_psi[OF set_eq inj])
  have hs: "sqrt (real M) * sqrt (real M) = real M" by (simp add: real_sqrt_mult_self)
  have sq: "complex_of_real (1 / sqrt (real M)) * complex_of_real (1 / sqrt (real M)) = complex_of_real (1 / real M)"
  proof -
    have "(1 / sqrt (real M)) * (1 / sqrt (real M)) = 1 / real M"
      using hs by (simp add: field_simps)
    then show ?thesis by (simp only: of_real_mult[symmetric])
  qed
  have sq': "cnj (complex_of_real (1 / sqrt (real M))) * complex_of_real (1 / sqrt (real M)) = complex_of_real (1 / real M)"
    by (simp only: complex_cnj_complex_of_real sq)
  have psi_term: "\<And>i. cnj (periodic_state N r x0 i) * periodic_state N r x0 i
      = (if i < N \<and> i mod r = x0 then complex_of_real (1 / real M) else 0)"
  proof -
    fix i
    show "cnj (periodic_state N r x0 i) * periodic_state N r x0 i
      = (if i < N \<and> i mod r = x0 then complex_of_real (1 / real M) else 0)"
      unfolding psi by (simp only: peak_cnj_if sq')
  qed
  have "inner N (periodic_state N r x0) (periodic_state N r x0)
      = (\<Sum>i<N. if i < N \<and> i mod r = x0 then complex_of_real (1 / real M) else 0)"
    unfolding inner_def by (intro sum.cong) (simp_all add: psi_term)
  also have "\<dots> = (\<Sum>m<M. complex_of_real (1 / real M))"
    by (rule peak_sum[where g = "\<lambda>_. complex_of_real (1 / real M)", OF set_eq inj])
  also have "\<dots> = 1"
    using M_pos by (simp add: field_simps)
  finally show ?thesis unfolding is_state_def by simp
qed

lemma peak_qft:
  fixes N r x0 M j :: nat and c :: int and a :: real
  assumes set_eq: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
    and inj: "inj_on (\<lambda>m. x0 + r * m) {..<M}"
    and hN: "0 < N"
    and ha: "a = pi * real_of_int (int j * int r - c * int N) / real N"
  shows "qft N (periodic_state N r x0) j =
    complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real x0 / real N) *
      (\<Sum>m<M. cis (2 * a * real m)) / complex_of_real (sqrt (real N))"
proof -
  have psi: "periodic_state N r x0 = (\<lambda>k. if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real M)) else 0)"
    by (rule peak_psi[OF set_eq inj])
  have hN' : "real N \<noteq> 0" using hN by simp
  have step1: "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = (\<Sum>m<M. complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real (x0 + r * m) / real N))"
  proof -
    have "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
        = (\<Sum>k<N. if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real k / real N) else 0)"
      unfolding psi by (intro sum.cong) (simp_all add: mult.commute)
    also have "\<dots> = (\<Sum>m<M. complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real (x0 + r * m) / real N))"
      by (rule peak_sum[OF set_eq inj])
    finally show ?thesis .
  qed
  have arg: "\<And>m. 2 * pi * real j * real (x0 + r * m) / real N
      = (2 * pi * real j * real x0 / real N + 2 * a * real m) + 2 * pi * real_of_int (c * int m)"
  proof -
    fix m
    show "2 * pi * real j * real (x0 + r * m) / real N
      = (2 * pi * real j * real x0 / real N + 2 * a * real m) + 2 * pi * real_of_int (c * int m)"
      unfolding ha using hN' by (simp add: field_simps)
  qed
  have cis_eq: "\<And>m. cis (2 * pi * real j * real (x0 + r * m) / real N)
      = cis (2 * pi * real j * real x0 / real N) * cis (2 * a * real m)"
  proof -
    fix m
    have z: "cis (2 * pi * real_of_int (c * int m)) = 1"
      by (rule cis_multiple_2pi) (rule Ints_of_int)
    have "cis (2 * pi * real j * real (x0 + r * m) / real N)
        = cis ((2 * pi * real j * real x0 / real N + 2 * a * real m) + 2 * pi * real_of_int (c * int m))"
      using arg[of m] by simp
    also have "\<dots> = cis (2 * pi * real j * real x0 / real N + 2 * a * real m) * cis (2 * pi * real_of_int (c * int m))"
      by (rule cis_mult[symmetric])
    also have "\<dots> = cis (2 * pi * real j * real x0 / real N + 2 * a * real m)"
      using z by simp
    also have "\<dots> = cis (2 * pi * real j * real x0 / real N) * cis (2 * a * real m)"
      by (rule cis_mult[symmetric])
    finally show "cis (2 * pi * real j * real (x0 + r * m) / real N)
        = cis (2 * pi * real j * real x0 / real N) * cis (2 * a * real m)" .
  qed
  have step2: "(\<Sum>m<M. complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real (x0 + r * m) / real N))
      = complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real x0 / real N) * (\<Sum>m<M. cis (2 * a * real m))"
  proof -
    have "(\<Sum>m<M. complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real (x0 + r * m) / real N))
        = (\<Sum>m<M. complex_of_real (1 / sqrt (real M)) * (cis (2 * pi * real j * real x0 / real N) * cis (2 * a * real m)))"
      by (simp only: cis_eq)
    also have "\<dots> = complex_of_real (1 / sqrt (real M)) * (cis (2 * pi * real j * real x0 / real N) * (\<Sum>m<M. cis (2 * a * real m)))"
      by (simp only: sum_distrib_left mult.assoc)
    also have "\<dots> = complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real x0 / real N) * (\<Sum>m<M. cis (2 * a * real m))"
      by (simp only: mult.assoc)
    finally show ?thesis .
  qed
  show ?thesis
    unfolding qft_def
    by (simp only: step1 step2)
qed

lemma peak_prob:
  fixes N r x0 M j :: nat and c :: int and a :: real
  assumes set_eq: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
    and inj: "inj_on (\<lambda>m. x0 + r * m) {..<M}"
    and hN: "0 < N" and hM: "0 < M"
    and ha: "a = pi * real_of_int (int j * int r - c * int N) / real N"
  shows "prob (qft N (periodic_state N r x0)) j = (cmod (\<Sum>m<M. cis (2 * a * real m)))\<^sup>2 / (real M * real N)"
proof -
  have hq: "qft N (periodic_state N r x0) j =
    complex_of_real (1 / sqrt (real M)) * cis (2 * pi * real j * real x0 / real N) *
      (\<Sum>m<M. cis (2 * a * real m)) / complex_of_real (sqrt (real N))"
    by (rule peak_qft[OF set_eq inj hN ha])
  have sM: "sqrt (real M) ^ 2 = real M" by simp
  have sN: "sqrt (real N) ^ 2 = real N" by simp
  have "cmod (qft N (periodic_state N r x0) j) = (1 / sqrt (real M)) * cmod (\<Sum>m<M. cis (2 * a * real m)) / sqrt (real N)"
    unfolding hq by (simp add: norm_divide norm_mult)
  then show ?thesis
    unfolding prob_def
    by (simp add: power_divide power_mult_distrib sM sN)
qed

lemma peak_key:
  fixes X N M r p :: real
  assumes "N \<noteq> 0" "M \<noteq> 0" "r \<noteq> 0" "p \<noteq> 0"
  shows "4 / p\<^sup>2 * X / (M * r / N) * M\<^sup>2 = 4 / (p\<^sup>2 * r) * X * (M * N)"
  using assms by (simp add: field_simps, algebra)

theorem shor_peak:
  assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r" and j: "j < N"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "is_state N (periodic_state N r x0) \<and>
    4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
proof -
  obtain M where set_eq: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<M}"
    and inj: "inj_on (\<lambda>m. x0 + r * m) {..<M}"
    and spec: "N \<le> x0 + r * M" and top: "r * M < N + r"
    using peak_set[OF r x0 rN] by blast
  have hN: "0 < N" using rN r by simp
  have M_pos: "0 < M"
  proof (rule ccontr)
    assume "\<not> 0 < M"
    then have "M = 0" by simp
    with spec have "N \<le> x0" by simp
    with x0 rN show False by linarith
  qed
  have state: "is_state N (periodic_state N r x0)"
    by (rule peak_state[OF set_eq inj M_pos])
  define a where a_def: "a = pi * real_of_int (int j * int r - c * int N) / real N"
  have prob_eq: "prob (qft N (periodic_state N r x0)) j = (cmod (\<Sum>m<M. cis (2 * a * real m)))\<^sup>2 / (real M * real N)"
    by (rule peak_prob[OF set_eq inj hN M_pos a_def])
  define D where D_def: "D = real_of_int (int j * int r - c * int N)"
  have rN_real: "real r < real N" using rN by simp
  have x0_real: "real x0 < real r" using x0 by simp
  have hN_real: "(0::real) < real N" using hN by simp
  have hN_ne: "real N \<noteq> 0" using hN_real by simp
  have hM_ne: "real M \<noteq> 0" using M_pos by simp
  have hr_ne: "real r \<noteq> 0" using r by simp
  have hpi_ne: "pi \<noteq> 0" using pi_gt_zero by simp
  have hM_real: "(0::real) < real M" using M_pos by simp
  have hr_real: "(0::real) < real r" using r by simp
  have spec_r: "real N \<le> real x0 + real r * real M"
    using spec by (metis of_nat_add of_nat_le_iff of_nat_mult)
  have top_r: "real r * real M < real N + real r"
    using top by (metis of_nat_add of_nat_less_iff of_nat_mult)
  have u0: "0 \<le> real r / real N" by simp
  have u1: "real r / real N < 1" using rN_real hN_real by (simp add: divide_less_eq_1)
  have w1: "1 - real r / real N \<le> real M * real r / real N"
  proof -
    have e: "real r * real M = real M * real r" by (rule mult.commute)
    have "real N - real r \<le> real M * real r" using spec_r x0_real e by linarith
    then have "(real N - real r) / real N \<le> (real M * real r) / real N"
      by (rule divide_right_mono) (simp add: less_imp_le hN_real)
    moreover have "1 - real r / real N = (real N - real r) / real N"
    proof -
      have a1: "(real N - real r) / real N = real N / real N - real r / real N"
        by (rule diff_divide_distrib)
      have a2: "real N / real N = 1" by (rule div_self[OF hN_ne])
      show ?thesis using a1 a2 by linarith
    qed
    ultimately show ?thesis by simp
  qed
  have w2: "real M * real r / real N \<le> 1 + real r / real N"
  proof -
    have e: "real r * real M = real M * real r" by (rule mult.commute)
    have "real M * real r \<le> real N + real r" using top_r e by linarith
    then have "(real M * real r) / real N \<le> (real N + real r) / real N"
      by (rule divide_right_mono) (simp add: less_imp_le hN_real)
    moreover have "1 + real r / real N = (real N + real r) / real N"
    proof -
      have a1: "(real N + real r) / real N = real N / real N + real r / real N"
        by (rule add_divide_distrib)
      have a2: "real N / real N = 1" by (rule div_self[OF hN_ne])
      show ?thesis using a1 a2 by linarith
    qed
    ultimately show ?thesis by simp
  qed
  have near_r: "2 * \<bar>D\<bar> \<le> real r"
  proof -
    have "real_of_int (2 * \<bar>int j * int r - c * int N\<bar>) \<le> real_of_int (int r)"
      using near by (subst of_int_le_iff) (rule near)
    then show ?thesis unfolding D_def by simp
  qed
  have pmn: "0 \<le> pi * real M / real N"
    using pi_gt_zero by (intro divide_nonneg_nonneg mult_nonneg_nonneg) auto
  have hT: "real M * \<bar>a\<bar> \<le> pi * (real M * real r / real N) / 2"
  proof -
    have absa: "\<bar>a\<bar> = pi * \<bar>D\<bar> / real N"
      unfolding a_def D_def by (simp add: abs_divide abs_mult pi_gt_zero)
    have "real M * \<bar>a\<bar> = (pi * real M / real N) * \<bar>D\<bar>"
      using absa by (simp add: field_simps)
    also have "\<dots> \<le> (pi * real M / real N) * (real r / 2)"
    proof (rule mult_left_mono)
      show "\<bar>D\<bar> \<le> real r / 2" using near_r by linarith
    next
      show "0 \<le> pi * real M / real N" using pmn .
    qed
    also have "\<dots> = pi * (real M * real r / real N) / 2"
      by (simp add: field_simps)
    finally show ?thesis .
  qed
  have core: "4 / pi\<^sup>2 * (1 - real r / real N)^3 / (real M * real r / real N) * (real M)\<^sup>2
      \<le> (cmod (\<Sum>m<M. cis (2 * a * real m)))\<^sup>2"
    by (rule core_sum_lower[OF u0 u1 w1 w2 hT])
  have key: "4 / pi\<^sup>2 * (1 - real r / real N)^3 / (real M * real r / real N) * (real M)\<^sup>2
      = 4 / (pi\<^sup>2 * real r) * (1 - real r / real N)^3 * (real M * real N)"
    by (rule peak_key[OF hN_ne hM_ne hr_ne hpi_ne])
  have pos: "0 < real M * real N" using hM_real hN_real by simp
  have BS: "4 / (pi\<^sup>2 * real r) * (1 - real r / real N)^3 * (real M * real N) \<le> (cmod (\<Sum>m<M. cis (2 * a * real m)))\<^sup>2"
    by (subst key[symmetric]) (rule core)
  have ineq: "4 / (pi\<^sup>2 * real r) * (1 - real r / real N)^3 \<le> (cmod (\<Sum>m<M. cis (2 * a * real m)))\<^sup>2 / (real M * real N)"
    by (subst pos_le_divide_eq[OF pos]) (rule BS)
  have fin: "4 / (pi\<^sup>2 * real r) * (1 - real r / real N)^3 \<le> prob (qft N (periodic_state N r x0)) j"
    using ineq prob_eq by simp
  show ?thesis using state fin by blast
qed


theorem shor_general_success:
  assumes r: "0 < r" and rr: "r * r < N" and x0: "x0 < r"
  shows "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
    \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
  sorry

end
