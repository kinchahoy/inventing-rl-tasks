theory Shor_Exact
  imports Quantum_Basics
begin

text \<open>Write \<open>N = M r\<close>. The periodic state is \<open>M\<^sup>-\<^sup>1\<^sup>/\<^sup>2 \<Sum>\<^sub>m\<^sub><\<^sub>M |x\<^sub>0 + m r\<rangle>\<close>, so its Fourier amplitude at \<open>j\<close>
  is a phase times \<open>(M N)\<^sup>-\<^sup>1\<^sup>/\<^sup>2 \<Sum>\<^sub>m\<^sub><\<^sub>M \<omega>\<^sup>m\<close> with \<open>\<omega> = e\<^sup>2\<^sup>\<pi>\<^sup>i\<^sup>j\<^sup>/\<^sup>M\<close>. That root-of-unity sum is \<open>M\<close> when
  \<open>M | j\<close> and \<open>0\<close> otherwise, giving probability \<open>M / N = 1 / r\<close> on multiples of \<open>M\<close>.\<close>

section \<open>Sums over a residue class\<close>

lemma residue_class:
  fixes r N M x0 :: nat
  assumes r: "0 < r" and N: "N = M * r" and x0: "x0 < r"
  shows "{k \<in> {..<N}. k mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<M}"
proof (intro equalityI subsetI)
  fix k assume "k \<in> {k \<in> {..<N}. k mod r = x0}"
  hence k: "k < N" "k mod r = x0" by auto
  have "k = x0 + k div r * r"
    using k(2) div_mult_mod_eq [of k r] by simp
  moreover have "k div r < M"
    using k(1) N r by (simp add: less_mult_imp_div_less)
  ultimately show "k \<in> (\<lambda>m. x0 + m * r) ` {..<M}"
    by (intro image_eqI [where x = "k div r"]) auto
next
  fix k assume "k \<in> (\<lambda>m. x0 + m * r) ` {..<M}"
  then obtain m where m: "m < M" and k: "k = x0 + m * r" by auto
  have "Suc m * r \<le> M * r"
    using m by (intro mult_le_mono1) simp
  hence "k < N"
    using k x0 N by simp
  moreover have "k mod r = x0"
    using k x0 by simp
  ultimately show "k \<in> {k \<in> {..<N}. k mod r = x0}" by simp
qed

lemma sum_residue_class:
  fixes r N M x0 :: nat
  assumes r: "0 < r" and N: "N = M * r" and x0: "x0 < r"
  shows "(\<Sum>k<N. if k < N \<and> k mod r = x0 then h k else 0) = (\<Sum>m<M. h (x0 + m * r))"
proof -
  have "(\<Sum>k<N. if k < N \<and> k mod r = x0 then h k else 0) = (\<Sum>k<N. if k mod r = x0 then h k else 0)"
    by (rule sum.cong) auto
  also have "\<dots> = sum h {k \<in> {..<N}. k mod r = x0}"
    by (simp add: sum.inter_filter [symmetric])
  also have "\<dots> = sum h ((\<lambda>m. x0 + m * r) ` {..<M})"
    by (simp only: residue_class [OF r N x0])
  also have "\<dots> = (\<Sum>m<M. h (x0 + m * r))"
    using r by (simp add: sum.reindex inj_on_def)
  finally show ?thesis .
qed

lemma residue_card:
  fixes r N M x0 :: nat
  assumes r: "0 < r" and N: "N = M * r" and x0: "x0 < r"
  shows "card {i. i < N \<and> i mod r = x0} = M"
proof -
  have "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<M}"
    using residue_class [OF r N x0] by auto
  moreover have "inj_on (\<lambda>m. x0 + m * r) {..<M}"
    using r by (auto simp: inj_on_def)
  ultimately show ?thesis
    by (simp add: card_image)
qed

section \<open>Roots of unity\<close>

lemma root_of_unity_sum:
  assumes M: "0 < M"
  shows "(\<Sum>m<M. cis (2 * pi * real j * real m / real M)) = (if M dvd j then of_nat M else 0)"
proof -
  define z where "z = cis (2 * pi * real j / real M)"
  have powers: "cis (2 * pi * real j * real m / real M) = z ^ m" for m
    by (simp add: z_def DeMoivre ac_simps)
  show ?thesis
  proof (cases "M dvd j")
    case True
    then obtain q where q: "j = M * q" by blast
    have "z = cis (2 * pi * real q)"
      unfolding z_def q using M by (intro arg_cong [where f = cis]) simp
    also have "\<dots> = 1"
      by (rule cis_multiple_2pi) simp
    finally show ?thesis
      using True by (simp add: powers)
  next
    case False
    have z_period: "z ^ M = 1"
    proof -
      have "z ^ M = cis (2 * pi * real j)"
        using M by (simp add: z_def DeMoivre)
      also have "\<dots> = 1"
        by (rule cis_multiple_2pi) simp
      finally show ?thesis .
    qed
    have z_ne_1: "z \<noteq> 1"
    proof
      assume "z = 1"
      hence "cos (2 * pi * real j / real M) = 1"
        by (simp add: z_def complex_eq_iff)
      then obtain n :: int where "2 * pi * real j / real M = of_int n * 2 * pi"
        by (auto simp: cos_one_2pi_int)
      hence "real j = of_int n * real M"
        using M by (simp add: field_simps)
      hence "(of_int (int j) :: real) = of_int (n * int M)"
        by simp
      hence "int j = n * int M"
        by (simp only: of_int_eq_iff)
      hence "int M dvd int j"
        by (intro dvdI [of _ _ n]) (simp add: mult.commute)
      hence "M dvd j"
        by simp
      with False show False ..
    qed
    have "(\<Sum>m<M. cis (2 * pi * real j * real m / real M)) = (\<Sum>m<M. z ^ m)"
      by (simp add: powers)
    also have "\<dots> = (z ^ M - 1) / (z - 1)"
      by (rule geometric_sum [OF z_ne_1])
    also have "\<dots> = 0"
      by (simp add: z_period)
    finally show ?thesis
      using False by simp
  qed
qed

section \<open>The Fourier amplitudes of a periodic state\<close>

lemma qft_periodic:
  assumes r: "0 < r" and N: "N = M * r" and M: "0 < M" and x0: "x0 < r"
  shows "qft N (periodic_state N r x0) j =
    complex_of_real (1 / (sqrt (real M) * sqrt (real N))) * cis (2 * pi * real j * real x0 / real N)
      * (\<Sum>m<M. cis (2 * pi * real j * real m / real M))"
proof -
  let ?c = "complex_of_real (1 / sqrt (real M))"
  let ?\<phi> = "cis (2 * pi * real j * real x0 / real N)"
  have div: "card {i. i < N \<and> i mod r = x0} = M"
    by (rule residue_card [OF r N x0])
  text \<open>Each term splits into the global phase at \<open>x\<^sub>0\<close> times a power of \<open>\<omega>\<close>, since \<open>r / N = 1 / M\<close>.\<close>
  have phase: "cis (2 * pi * real j * real (x0 + m * r) / real N)
      = ?\<phi> * cis (2 * pi * real j * real m / real M)" for m
  proof -
    have "2 * pi * real j * real (x0 + m * r) / real N
        = 2 * pi * real j * real x0 / real N + 2 * pi * real j * real m / real M"
      using M r by (simp add: N field_simps)
    thus ?thesis
      by (simp add: cis_mult)
  qed
  have summand: "cis (2 * pi * real j * real (x0 + m * r) / real N) * ?c
      = ?c * ?\<phi> * cis (2 * pi * real j * real m / real M)" for m
    using phase [of m] by (simp add: ac_simps)
  have "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = (\<Sum>k<N. if k < N \<and> k mod r = x0 then cis (2 * pi * real j * real k / real N) * ?c else 0)"
    by (rule sum.cong) (simp_all add: periodic_state_def div)
  also have "\<dots> = (\<Sum>m<M. cis (2 * pi * real j * real (x0 + m * r) / real N) * ?c)"
    by (rule sum_residue_class [OF r N x0])
  also have "\<dots> = ?c * ?\<phi> * (\<Sum>m<M. cis (2 * pi * real j * real m / real M))"
    unfolding sum_distrib_left by (rule sum.cong) (simp_all only: summand)
  finally have sum_eq: "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = ?c * ?\<phi> * (\<Sum>m<M. cis (2 * pi * real j * real m / real M))" .
  show ?thesis
    unfolding qft_def sum_eq by (simp add: field_simps)
qed

section \<open>Shor's quantum core\<close>

theorem shor_core:
  assumes N0: "0 < N" and r: "0 < r" and dvd: "r dvd N" and x0: "x0 < r"
  shows "is_state N (periodic_state N r x0) \<and>
    (\<forall>j<N. prob (qft N (periodic_state N r x0)) j = (if (N div r) dvd j then 1 / real r else 0))"
proof -
  define M where "M = N div r"
  have N: "N = M * r"
    using dvd by (simp add: M_def)
  have M: "0 < M"
    using N0 N by (cases "M = 0") simp_all
  let ?v = "periodic_state N r x0"
  let ?c = "complex_of_real (1 / sqrt (real M))"
  text \<open>The input is a unit vector: \<open>M\<close> entries of squared magnitude \<open>1 / M\<close>.\<close>
  have cc: "cnj ?c * ?c = complex_of_real (1 / real M)"
  proof -
    have "sqrt (real M) * sqrt (real M) = real M" and "sqrt (real M) \<noteq> 0"
      using M by simp_all
    hence "1 / sqrt (real M) * (1 / sqrt (real M)) = 1 / real M"
      by (simp add: field_simps)
    thus ?thesis
      by (simp only: complex_cnj_complex_of_real of_real_mult [symmetric])
  qed
  have "inner N ?v ?v = (\<Sum>k<N. if k < N \<and> k mod r = x0 then cnj ?c * ?c else 0)"
    unfolding inner_def by (rule sum.cong) (simp_all add: periodic_state_def residue_card [OF r N x0])
  also have "\<dots> = (\<Sum>m<M. cnj ?c * ?c)"
    by (rule sum_residue_class [OF r N x0])
  also have "\<dots> = (\<Sum>m<M. complex_of_real (1 / real M))"
    by (simp only: cc)
  also have "\<dots> = 1"
    using M by simp
  finally have state: "is_state N ?v"
    by (simp add: is_state_def)
  text \<open>Each outcome: amplitude \<open>M / \<surd>(M N)\<close> on multiples of \<open>M\<close>, and \<open>0\<close> elsewhere.\<close>
  have outcome: "prob (qft N ?v) j = (if M dvd j then 1 / real r else 0)" for j
  proof (cases "M dvd j")
    case True
    have "prob (qft N ?v) j = (real M / (sqrt (real M) * sqrt (real N)))\<^sup>2"
      using M N0 True by (simp add: prob_def qft_periodic [OF r N M x0] root_of_unity_sum [OF M]
          norm_mult norm_divide abs_of_nonneg)
    also have "\<dots> = (real M)\<^sup>2 / (real M * real N)"
      by (simp add: power_divide power_mult_distrib)
    also have "\<dots> = real M / real N"
      using M by (simp add: power2_eq_square)
    also have "\<dots> = 1 / real r"
      using M by (simp add: N)
    finally show ?thesis
      using True by simp
  next
    case False
    thus ?thesis
      by (simp add: prob_def qft_periodic [OF r N M x0] root_of_unity_sum [OF M])
  qed
  show ?thesis
    using state outcome by (simp add: M_def)
qed

section \<open>The classical step: an even period yields a factor\<close>

text \<open>With \<open>b = a\<^sup>r\<^sup>/\<^sup>2\<close>: \<open>n | b\<^sup>2 - 1 = (b - 1)(b + 1)\<close>, but \<open>n\<close> divides neither factor (minimality of
  \<open>r\<close>, and \<open>b \<not>\<equiv> -1\<close>), so \<open>gcd (b - 1) n\<close> is a proper divisor of \<open>n\<close> other than \<open>1\<close>.\<close>
theorem shor_factor:
  assumes n: "1 < n" and ord: "is_order n a r" and even: "even r"
    and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
proof -
  have r0: "0 < r" and ar: "a ^ r mod n = 1"
    and min: "\<And>k. 0 < k \<Longrightarrow> k < r \<Longrightarrow> a ^ k mod n \<noteq> 1"
    using ord by (auto simp: is_order_def)
  obtain s where s: "r = 2 * s"
    using even by (rule evenE)
  have half: "r div 2 = s" and s0: "0 < s" and s_lt: "s < r"
    using s r0 by simp_all
  define b where "b = a ^ s"
  have a0: "a \<noteq> 0"
  proof
    assume a: "a = 0"
    from a ar r0 n show False by (simp add: power_0_left)
  qed
  have b0: "0 < b"
    using a0 by (simp add: b_def)
  have bb: "b * b = a ^ r"
    unfolding b_def s by (simp add: mult_2 power_add)
  have prod_dvd: "n dvd (b - 1) * (b + 1)"
  proof -
    have "(b - 1) * (b + 1) = b * b - 1"
      using b0 by (cases b) (simp_all add: algebra_simps)
    moreover have "n dvd b * b - 1"
    proof -
      have "1 \<le> a ^ r"
        using a0 by (simp add: Suc_le_eq)
      thus ?thesis
        using mod_eq_dvd_iff_nat [of 1 "b * b" n] bb ar n by simp
    qed
    ultimately show ?thesis by simp
  qed
  have not_minus: "\<not> n dvd b - 1"
  proof
    assume "n dvd b - 1"
    hence "b mod n = 1 mod n"
      using mod_eq_dvd_iff_nat [of 1 b n] b0 by simp
    with n have "a ^ s mod n = 1"
      by (simp add: b_def)
    with min [OF s0 s_lt] show False ..
  qed
  have not_plus: "\<not> n dvd b + 1"
  proof
    assume "n dvd b + 1"
    hence "Suc b mod n = 0"
      by (simp add: dvd_eq_mod_eq_0)
    hence "Suc (b mod n) = n"
      by (simp add: mod_Suc split: if_splits)
    hence "b mod n = n - 1" by simp
    with not_minus_one show False
      by (simp add: half b_def)
  qed
  define d where "d = gcd (b - 1) n"
  have "d \<noteq> 1"
  proof
    assume "d = 1"
    hence "coprime n (b - 1)"
      by (simp add: d_def coprime_iff_gcd_eq_1 gcd.commute)
    from this prod_dvd have "n dvd b + 1"
      by (simp only: coprime_dvd_mult_right_iff)
    with not_plus show False ..
  qed
  moreover have "d \<noteq> 0"
    using n by (simp add: d_def)
  moreover have "d \<noteq> n"
  proof
    assume "d = n"
    hence "n dvd b - 1"
      using gcd_dvd1 [of "b - 1" n] by (simp add: d_def)
    with not_minus show False ..
  qed
  moreover have "d \<le> n"
    using n by (simp add: d_def dvd_imp_le)
  ultimately have "1 < d \<and> d < n" by simp
  thus ?thesis
    by (simp add: d_def b_def half)
qed

section \<open>Recovering the period from one measurement\<close>

text \<open>An outcome \<open>j = k M\<close> gives \<open>N / gcd j N = r / gcd k r\<close>, which is \<open>r\<close> iff \<open>k\<close> is coprime to \<open>r\<close>.\<close>
lemma period_recovered:
  fixes k r M :: nat
  assumes M: "0 < M" and r: "0 < r"
  shows "(M * r) div gcd (M * k) (M * r) = r \<longleftrightarrow> coprime k r"
proof -
  have "(M * r) div gcd (M * k) (M * r) = r div gcd k r"
    using M by (simp add: gcd_mult_distrib_nat [symmetric])
  moreover have "r div gcd k r = r \<longleftrightarrow> gcd k r = 1"
  proof
    assume eq: "r div gcd k r = r"
    show "gcd k r = 1"
    proof (rule ccontr)
      assume ne: "gcd k r \<noteq> 1"
      have pos: "0 < gcd k r"
        using r by simp
      from ne pos have "1 < gcd k r" by arith
      hence "r div gcd k r < r"
        using r by simp
      with eq show False by simp
    qed
  qed simp
  ultimately show ?thesis
    by (simp add: coprime_iff_gcd_eq_1)
qed

text \<open>One run of exact-case Shor (QFT, measure \<open>j\<close>, output \<open>N / gcd j N\<close>) returns the period with
  probability exactly \<open>\<phi>(r) / r\<close>, where \<open>\<phi>(r) = #{k < r. coprime k r}\<close>.\<close>
theorem shor_success:
  assumes N0: "0 < N" and r: "0 < r" and dvd: "r dvd N" and x0: "x0 < r"
  shows "(\<Sum>j \<in> {j. j < N \<and> N div gcd j N = r}. prob (qft N (periodic_state N r x0)) j)
    = real (card {k. k < r \<and> coprime k r}) / real r"
proof -
  define M where "M = N div r"
  have N: "N = M * r"
    using dvd by (simp add: M_def)
  have M: "0 < M"
    using N0 N by (cases "M = 0") simp_all
  let ?v = "periodic_state N r x0"
  let ?J = "{j. j < N \<and> N div gcd j N = r}"
  have probs: "\<forall>j<N. prob (qft N ?v) j = (if M dvd j then 1 / real r else 0)"
    using shor_core [OF N0 r dvd x0] by (simp add: M_def)
  have hits: "{j \<in> ?J. M dvd j} = (\<lambda>k. M * k) ` {k. k < r \<and> coprime k r}"
  proof (intro equalityI subsetI)
    fix j assume "j \<in> {j \<in> ?J. M dvd j}"
    hence j: "j < N" "N div gcd j N = r" "M dvd j" by auto
    then obtain k where k: "j = M * k" by (auto elim: dvdE)
    have "k < r"
      using k N j(1) M by simp
    moreover have "coprime k r"
      using k N j(2) period_recovered [OF M r, of k] by simp
    ultimately show "j \<in> (\<lambda>k. M * k) ` {k. k < r \<and> coprime k r}"
      using k by auto
  next
    fix j assume "j \<in> (\<lambda>k. M * k) ` {k. k < r \<and> coprime k r}"
    then obtain k where k: "k < r" "coprime k r" and j: "j = M * k" by auto
    have "j < N"
      using j N k(1) M by simp
    moreover have "N div gcd j N = r"
      using j N period_recovered [OF M r, of k] k(2) by simp
    ultimately show "j \<in> {j \<in> ?J. M dvd j}"
      using j by auto
  qed
  have inj: "inj_on (\<lambda>k. M * k) {k. k < r \<and> coprime k r}"
    using M by (simp add: inj_on_def)
  have fin: "finite ?J" by simp
  have "(\<Sum>j\<in>?J. prob (qft N ?v) j) = (\<Sum>j\<in>?J. if M dvd j then 1 / real r else 0)"
    by (rule sum.cong) (auto simp: probs)
  also have "\<dots> = real (card {j \<in> ?J. M dvd j}) * (1 / real r)"
    by (simp only: sum.inter_filter [OF fin, symmetric] sum_constant)
  also have "card {j \<in> ?J. M dvd j} = card {k. k < r \<and> coprime k r}"
    by (simp only: hits card_image [OF inj])
  finally show ?thesis by simp
qed

end
