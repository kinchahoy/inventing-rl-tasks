theory Shor_General
  imports Quantum_Basics
begin

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


section \<open>The periodic state for a general period\<close>

text \<open>For \<open>x\<^sub>0 < r\<close> and \<open>x\<^sub>0 < N\<close>, the indices below \<open>N\<close> congruent to \<open>x\<^sub>0\<close> are \<open>x\<^sub>0 + m r\<close> for \<open>m < L\<close>,
  with \<open>L = (N - 1 - x\<^sub>0) div r + 1\<close>, and \<open>N - r \<le> L r \<le> N + r\<close>.\<close>

lemma residue_set:
  fixes N r x0 :: nat
  assumes r: "0 < r" and x0: "x0 < r" and x0N: "x0 < N"
  shows "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<(N - 1 - x0) div r + 1}"
proof (intro equalityI subsetI)
  fix i assume "i \<in> {i. i < N \<and> i mod r = x0}"
  hence i: "i < N" "i mod r = x0" by auto
  have eq: "i = x0 + i div r * r"
    using i(2) div_mult_mod_eq [of i r] by simp
  have "i div r * r \<le> N - 1 - x0"
    using i(1) eq by linarith
  hence "i div r \<le> (N - 1 - x0) div r"
    using r by (simp add: less_eq_div_iff_mult_less_eq)
  thus "i \<in> (\<lambda>m. x0 + m * r) ` {..<(N - 1 - x0) div r + 1}"
    using eq by (intro image_eqI [where x = "i div r"]) auto
next
  fix i assume "i \<in> (\<lambda>m. x0 + m * r) ` {..<(N - 1 - x0) div r + 1}"
  then obtain m where "m < (N - 1 - x0) div r + 1" and i: "i = x0 + m * r" by auto
  hence m: "m \<le> (N - 1 - x0) div r" by simp
  have "m * r \<le> (N - 1 - x0) div r * r"
    using m by (rule mult_le_mono1)
  also have "\<dots> \<le> N - 1 - x0"
    by (rule div_times_less_eq_dividend)
  finally have "i < N"
    using i x0N by linarith
  moreover have "i mod r = x0"
    using i x0 by simp
  ultimately show "i \<in> {i. i < N \<and> i mod r = x0}" by simp
qed

lemma residue_count:
  fixes N r x0 :: nat
  assumes r: "0 < r" and x0: "x0 < r" and x0N: "x0 < N"
  defines "L \<equiv> card {i. i < N \<and> i mod r = x0}"
  shows "0 < L" and "L * r \<le> N + r" and "N \<le> L * r + r"
    and "(\<Sum>k<N. if k < N \<and> k mod r = x0 then h k else 0) = (\<Sum>m<L. h (x0 + m * r))"
proof -
  define q where "q = (N - 1 - x0) div r"
  have set: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<q + 1}"
    unfolding q_def by (rule residue_set [OF r x0 x0N])
  have inj: "inj_on (\<lambda>m. x0 + m * r) {..<q + 1}"
    using r by (auto simp: inj_on_def)
  have L: "L = q + 1"
    unfolding L_def set using card_image [OF inj] by simp
  show "0 < L" using L by simp
  have "q * r \<le> N - 1 - x0"
    unfolding q_def by (rule div_times_less_eq_dividend)
  thus "L * r \<le> N + r"
    using L by (simp add: algebra_simps)
  have "N - 1 - x0 = q * r + (N - 1 - x0) mod r"
    unfolding q_def by simp
  moreover have "(N - 1 - x0) mod r < r"
    using r by simp
  ultimately have "N - 1 - x0 < q * r + r"
    by linarith
  hence "N - 1 - x0 < L * r"
    using L by (simp add: algebra_simps)
  thus "N \<le> L * r + r"
    using x0 by linarith
  have "(\<Sum>k<N. if k < N \<and> k mod r = x0 then h k else 0) = sum h {i. i < N \<and> i mod r = x0}"
    by (simp add: sum.If_cases Collect_conj_eq lessThan_def Int_commute)
  also have "\<dots> = (\<Sum>m<q + 1. h (x0 + m * r))"
    unfolding set sum.reindex [OF inj] by (simp only: comp_def)
  finally show "(\<Sum>k<N. if k < N \<and> k mod r = x0 then h k else 0) = (\<Sum>m<L. h (x0 + m * r))"
    using L by simp
qed

section \<open>Its Fourier amplitudes\<close>

lemma qft_periodic_norm:
  fixes N r x0 j :: nat
  assumes r: "0 < r" and x0: "x0 < r" and x0N: "x0 < N"
  defines "L \<equiv> card {i. i < N \<and> i mod r = x0}"
  shows "cmod (qft N (periodic_state N r x0) j)
    = cmod (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N)) / (sqrt (real L) * sqrt (real N))"
proof -
  let ?c = "complex_of_real (1 / sqrt (real L))"
  let ?ph = "cis (2 * pi * real j * real x0 / real N)"
  have phase: "cis (2 * pi * real j * real (x0 + m * r) / real N)
      = ?ph * cis (2 * pi * real j * real r * real m / real N)" for m
  proof -
    have "2 * pi * real j * real (x0 + m * r) / real N
        = 2 * pi * real j * real x0 / real N + 2 * pi * real j * real r * real m / real N"
      by (simp add: algebra_simps add_divide_distrib)
    thus ?thesis by (simp add: cis_mult)
  qed
  have summand: "cis (2 * pi * real j * real (x0 + m * r) / real N) * ?c
      = ?c * ?ph * cis (2 * pi * real j * real r * real m / real N)" for m
    using phase [of m] by (simp add: ac_simps)
  have "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = (\<Sum>k<N. if k < N \<and> k mod r = x0 then cis (2 * pi * real j * real k / real N) * ?c else 0)"
    by (rule sum.cong) (simp_all add: periodic_state_def L_def)
  also have "\<dots> = (\<Sum>m<L. cis (2 * pi * real j * real (x0 + m * r) / real N) * ?c)"
    unfolding L_def by (rule residue_count(4) [OF r x0 x0N])
  also have "\<dots> = ?c * ?ph * (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N))"
    unfolding sum_distrib_left by (rule sum.cong) (simp_all only: summand)
  finally have sum_eq: "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = ?c * ?ph * (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N))" .
  have "cmod (qft N (periodic_state N r x0) j)
      = cmod (?c * ?ph * (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N))) / sqrt (real N)"
  proof -
    have sN: "\<bar>sqrt (real N)\<bar> = sqrt (real N)" by simp
    show ?thesis unfolding qft_def by (simp only: sum_eq norm_divide norm_of_real sN)
  qed
  also have "cmod (?c * ?ph * (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N)))
      = cmod (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N)) / sqrt (real L)"
    by (simp only: norm_mult norm_cis norm_of_real) simp
  also have "cmod (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N)) / sqrt (real L) / sqrt (real N)
      = cmod (\<Sum>m<L. cis (2 * pi * real j * real r * real m / real N)) / (sqrt (real L) * sqrt (real N))"
    by (simp only: divide_divide_eq_left)
  finally show ?thesis .
qed

text \<open>Only the distance \<open>\<delta> = j r - c N\<close> to a multiple of \<open>N\<close> matters.\<close>
lemma phase_shift:
  fixes N r j m :: nat and c :: int
  assumes N: "0 < N"
  shows "cis (2 * pi * real j * real r * real m / real N)
    = cis (real m * (2 * pi * real_of_int (int j * int r - c * int N) / real N))"
proof -
  have "2 * pi * real j * real r * real m / real N
      = real m * (2 * pi * real_of_int (int j * int r - c * int N) / real N) + 2 * pi * real_of_int (c * int m)"
    using N by (simp add: field_simps)
  moreover have "cis (2 * pi * real_of_int (c * int m)) = 1"
    by (rule cis_multiple_2pi) simp
  ultimately show ?thesis
    by (simp add: cis_mult [symmetric])
qed

section \<open>Geometric sums of phases\<close>

lemma cmod_cis_minus_one: "cmod (cis b - 1) = 2 * \<bar>sin (b / 2)\<bar>"
proof (rule power2_eq_imp_eq)
  have c: "cos b = 1 - 2 * (sin (b / 2))\<^sup>2"
    using cos_double_sin [of "b / 2"] by simp
  have "(cmod (cis b - 1))\<^sup>2 = (cos b - 1)\<^sup>2 + (sin b)\<^sup>2"
    by (simp add: cmod_power2)
  also have "\<dots> = 2 - 2 * cos b"
    using sin_cos_squared_add [of b] by (simp add: power2_eq_square algebra_simps)
  also have "\<dots> = (2 * \<bar>sin (b / 2)\<bar>)\<^sup>2"
    unfolding c by (simp add: power_mult_distrib)
  finally show "(cmod (cis b - 1))\<^sup>2 = (2 * \<bar>sin (b / 2)\<bar>)\<^sup>2" .
qed simp_all

lemma cis_sum_norm:
  assumes s: "sin (t / 2) \<noteq> 0"
  shows "cmod (\<Sum>m<L. cis (real m * t)) = \<bar>sin (real L * t / 2)\<bar> / \<bar>sin (t / 2)\<bar>"
proof -
  have pow: "cis (real m * t) = cis t ^ m" for m
    by (simp add: DeMoivre)
  have "cis t ^ L - 1 = (cis t - 1) * (\<Sum>m<L. cis t ^ m)"
    by (rule power_diff_1_eq)
  hence "cmod (cis (real L * t) - 1) = cmod (cis t - 1) * cmod (\<Sum>m<L. cis (real m * t))"
    by (simp add: pow norm_mult)
  hence "2 * \<bar>sin (real L * t / 2)\<bar> = 2 * \<bar>sin (t / 2)\<bar> * cmod (\<Sum>m<L. cis (real m * t))"
    by (simp add: cmod_cis_minus_one)
  thus ?thesis
    using s by (simp add: field_simps)
qed

section \<open>Jordan's inequality\<close>

lemma x_cos_le_sin:
  fixes y :: real
  assumes "0 \<le> y" "y \<le> pi"
  shows "y * cos y \<le> sin y"
proof -
  have "(\<lambda>t. sin t - t * cos t) 0 \<le> (\<lambda>t. sin t - t * cos t) y"
  proof (rule DERIV_nonneg_imp_nondecreasing [OF assms(1)])
    fix t :: real assume t: "0 \<le> t" "t \<le> y"
    have "DERIV (\<lambda>t. sin t - t * cos t) t :> cos t - (1 * cos t + t * - sin t)"
      by (intro derivative_eq_intros) auto
    moreover have "0 \<le> cos t - (1 * cos t + t * - sin t)"
      using t assms(2) by (simp add: sin_ge_zero)
    ultimately show "\<exists>d. DERIV (\<lambda>t. sin t - t * cos t) t :> d \<and> 0 \<le> d" by blast
  qed
  thus ?thesis by simp
qed

lemma jordan:
  fixes x :: real
  assumes x0: "0 \<le> x" and x1: "x \<le> pi / 2"
  shows "2 / pi * x \<le> sin x"
proof (cases "x = 0")
  case True thus ?thesis by simp
next
  case False
  hence x: "0 < x" using x0 by simp
  have "(\<lambda>t. sin t / t) (pi / 2) \<le> (\<lambda>t. sin t / t) x"
  proof (rule DERIV_nonpos_imp_nonincreasing [OF x1])
    fix t :: real assume t: "x \<le> t" "t \<le> pi / 2"
    have t0: "t \<noteq> 0" using t x by simp
    have "DERIV (\<lambda>t. sin t / t) t :> (cos t * t - 1 * sin t) / t ^ Suc (Suc 0)"
      using t0 by (intro DERIV_quotient DERIV_sin DERIV_ident) auto
    moreover have "cos t * t - 1 * sin t \<le> 0"
      using x_cos_le_sin [of t] t x pi_gt_zero by (simp add: mult.commute)
    ultimately show "\<exists>d. DERIV (\<lambda>t. sin t / t) t :> d \<and> d \<le> 0"
      by (intro exI conjI) (auto intro!: divide_nonpos_nonneg)
  qed
  hence "2 / pi \<le> sin x / x" by simp
  thus ?thesis using x by (simp add: field_simps)
qed

lemma jordan_both_sides:
  fixes t :: real
  assumes "0 \<le> t" "t \<le> pi"
  shows "2 / pi * min t (pi - t) \<le> sin t"
proof (cases "t \<le> pi / 2")
  case True thus ?thesis using jordan [of t] assms by (simp add: min_def)
next
  case False
  hence "2 / pi * (pi - t) \<le> sin (pi - t)" using jordan [of "pi - t"] assms by simp
  thus ?thesis using False by (simp add: min_def)
qed

section \<open>The peak bound\<close>

lemma peak_arith:
  fixes n s l g :: real
  assumes s: "0 < s" and sn: "s < n" and l: "0 < l" "l * s \<le> n + s"
    and g: "2 / pi * ((n - s) / s) \<le> g"
  shows "4 / (pi\<^sup>2 * s) * (1 - s / n) ^ 3 \<le> g\<^sup>2 / (l * n)"
proof -
  have n: "0 < n" using s sn by simp
  define g0 where "g0 = 2 / pi * ((n - s) / s)"
  have g0: "0 \<le> g0" using s sn unfolding g0_def by simp
  have "g0\<^sup>2 \<le> g\<^sup>2" using g g0 unfolding g0_def by (intro power_mono) auto
  hence "g0\<^sup>2 / (l * n) \<le> g\<^sup>2 / (l * n)" using l n by (simp add: divide_right_mono)
  moreover have "g0\<^sup>2 * s / ((n + s) * n) \<le> g0\<^sup>2 / (l * n)"
  proof -
    have "l \<le> (n + s) / s" using l s by (simp add: field_simps)
    hence "l * n \<le> (n + s) / s * n" by (rule mult_right_mono) (simp add: less_imp_le n)
    moreover have "0 < (n + s) / s * n * (l * n)"
      using l(1) n s by simp
    ultimately have "g0\<^sup>2 / ((n + s) / s * n) \<le> g0\<^sup>2 / (l * n)"
      by (intro divide_left_mono) simp_all
    thus ?thesis using s by (simp add: field_simps)
  qed
  moreover have "4 / (pi\<^sup>2 * s) * (1 - s / n) ^ 3 \<le> g0\<^sup>2 * s / ((n + s) * n)"
  proof -
    have nz: "n \<noteq> 0" "s \<noteq> 0" "pi \<noteq> 0" using n s by simp_all
    have key: "(n - s) * (n + s) \<le> n\<^sup>2" by (simp add: algebra_simps power2_eq_square)
    have r1: "4 / (pi\<^sup>2 * s) * (1 - s / n) ^ 3 * ((n + s) * n)
        = 4 / (pi\<^sup>2 * s) * (n - s)\<^sup>2 * ((n - s) * (n + s) / n\<^sup>2)"
      using nz by (simp add: field_simps power2_eq_square power3_eq_cube)
    have r2: "(n - s) * (n + s) / n\<^sup>2 \<le> 1"
      using key n by (simp add: pos_divide_le_eq)
    have "4 / (pi\<^sup>2 * s) * (n - s)\<^sup>2 * ((n - s) * (n + s) / n\<^sup>2) \<le> 4 / (pi\<^sup>2 * s) * (n - s)\<^sup>2 * 1"
      using r2 s by (intro mult_left_mono) simp_all
    also have "\<dots> = g0\<^sup>2 * s"
      using nz unfolding g0_def by (simp add: field_simps power2_eq_square)
    finally have "4 / (pi\<^sup>2 * s) * (1 - s / n) ^ 3 * ((n + s) * n) \<le> g0\<^sup>2 * s"
      unfolding r1 .
    moreover have "0 < (n + s) * n" using n s by simp
    ultimately show ?thesis by (simp add: pos_le_divide_eq)
  qed
  ultimately show ?thesis by linarith
qed

text \<open>For any period \<open>0 < r < N\<close>, an outcome \<open>j\<close> within \<open>r / 2\<close> of a multiple \<open>c N / r\<close> has probability at least
  \<open>4 / (\<pi>\<^sup>2 r) (1 - r/N)\<^sup>3\<close>. Write \<open>\<delta> = j r - c N\<close> and \<open>\<phi> = \<pi> \<delta> / N\<close>; the amplitude is
  \<open>|sin (L \<phi>)| / |sin \<phi>|\<close> over \<open>\<surd>(L N)\<close>, and Jordan's inequality bounds it below.\<close>
theorem shor_peak:
  assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r" and j: "j < N"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "is_state N (periodic_state N r x0) \<and>
    4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
proof
  have x0N: "x0 < N" using x0 rN by simp
  have N: "0 < N" using rN by simp
  define L where "L = card {i. i < N \<and> i mod r = x0}"
  have L: "0 < L" "L * r \<le> N + r" "N \<le> L * r + r"
    using residue_count(1-3) [OF r x0 x0N] by (simp_all add: L_def)
  let ?v = "periodic_state N r x0"
  let ?c = "complex_of_real (1 / sqrt (real L))"
  have cc: "cnj ?c * ?c = complex_of_real (1 / real L)"
  proof -
    have "1 / sqrt (real L) * (1 / sqrt (real L)) = 1 / real L"
      using L(1) by (simp add: field_simps)
    thus ?thesis by (simp only: complex_cnj_complex_of_real of_real_mult [symmetric])
  qed
  have "inner N ?v ?v = (\<Sum>k<N. if k < N \<and> k mod r = x0 then cnj ?c * ?c else 0)"
    unfolding inner_def by (rule sum.cong) (simp_all add: periodic_state_def L_def)
  also have "\<dots> = (\<Sum>m<L. cnj ?c * ?c)"
    unfolding L_def by (rule residue_count(4) [OF r x0 x0N])
  also have "\<dots> = (\<Sum>m<L. complex_of_real (1 / real L))"
    by (simp only: cc)
  also have "\<dots> = 1"
    using L(1) by simp
  finally show "is_state N ?v" by (simp add: is_state_def)

  define d where "d = int j * int r - c * int N"
  define phi where "phi = pi * real_of_int d / real N"
  let ?G = "\<Sum>m<L. cis (real m * (2 * phi))"
  have G: "cmod (qft N ?v j) = cmod ?G / (sqrt (real L) * sqrt (real N))"
    using qft_periodic_norm [OF r x0 x0N, of j] phase_shift [OF N, of j r _ c]
    by (simp add: L_def d_def phi_def mult.assoc)
  have prob: "prob (qft N ?v) j = (cmod ?G)\<^sup>2 / (real L * real N)"
    using G L(1) N by (simp add: prob_def power_divide real_sqrt_mult [symmetric])
  have n: "real r < real N" "0 < real r" using rN r by simp_all
  have Lr: "real L * real r \<le> real N + real r" "real N - real r \<le> real L * real r"
    using L(2,3) by (simp_all only: of_nat_mult [symmetric] of_nat_add [symmetric] of_nat_le_iff)
  have lower: "2 / pi * ((real N - real r) / real r) \<le> cmod ?G"
  proof (cases "d = 0")
    case True
    hence "?G = of_nat L" by (simp add: phi_def)
    hence "cmod ?G = real L" by simp
    moreover have "(real N - real r) / real r \<le> real L"
      using Lr n by (simp add: field_simps)
    moreover have "2 / pi * ((real N - real r) / real r) \<le> (real N - real r) / real r"
    proof (rule mult_left_le_one_le)
      show "0 \<le> (real N - real r) / real r" using n by simp
      show "0 \<le> 2 / pi" by simp
      show "2 / pi \<le> 1" using pi_ge_two by simp
    qed
    ultimately show ?thesis by linarith
  next
    case False
    have dr: "2 * \<bar>real_of_int d\<bar> \<le> real r" using near unfolding d_def by linarith
    have phi_le: "\<bar>phi\<bar> \<le> pi * real r / (2 * real N)"
      using dr N unfolding phi_def by (simp add: abs_mult field_simps)
    have phi_pos: "0 < \<bar>phi\<bar>" using False N unfolding phi_def by simp
    have "pi * real r < pi * real N" using n(1) pi_gt_zero by (rule mult_strict_left_mono)
    hence "pi * real r / (2 * real N) < pi / 2" using n by (simp add: field_simps)
    hence phi_small: "\<bar>phi\<bar> < pi / 2" using phi_le by linarith
    have "0 < sin \<bar>phi\<bar>" using phi_pos phi_small pi_gt_zero by (intro sin_gt_zero) simp_all
    moreover have "\<bar>sin phi\<bar> = \<bar>sin \<bar>phi\<bar>\<bar>" by (cases "0 \<le> phi") simp_all
    ultimately have sin_phi: "0 < \<bar>sin phi\<bar>" "\<bar>sin phi\<bar> \<le> \<bar>phi\<bar>"
      using abs_sin_x_le_abs_x [of phi] by simp_all
    define t where "t = real L * \<bar>phi\<bar>"
    have t0: "0 \<le> t" unfolding t_def by simp
    have tpi: "t \<le> pi"
    proof -
      have "t \<le> real L * (pi * real r / (2 * real N))"
        unfolding t_def using phi_le by (rule mult_left_mono) simp
      also have "\<dots> = pi / 2 * (real L * real r / real N)" by (simp add: field_simps)
      also have "\<dots> \<le> pi / 2 * 2"
        using Lr n by (intro mult_left_mono) (simp_all add: field_simps)
      finally show ?thesis by simp
    qed
    have sinL: "\<bar>sin (real L * phi)\<bar> = sin t"
      using sin_ge_zero [OF t0 tpi] unfolding t_def by (cases "0 \<le> phi") (simp_all add: abs_if)
    have norm: "cmod ?G = sin t / \<bar>sin phi\<bar>"
      using cis_sum_norm [of "2 * phi" L] sin_phi(1) sinL by simp
    have "2 / pi * ((real N - real r) / real r) * \<bar>phi\<bar> \<le> 2 / pi * min t (pi - t)"
    proof -
      have "(real N - real r) / real r * \<bar>phi\<bar> \<le> t"
        unfolding t_def using Lr n by (intro mult_right_mono) (simp_all add: field_simps)
      moreover have "(real N - real r) / real r * \<bar>phi\<bar> \<le> pi - t"
      proof -
        have Lsum: "real L + (real N - real r) / real r \<le> 2 * real N / real r"
        proof -
          have "real L * real r + (real N - real r) \<le> 2 * real N" using Lr by linarith
          hence "(real L * real r + (real N - real r)) / real r \<le> 2 * real N / real r"
            using n by (intro divide_right_mono) simp_all
          moreover have "real L + (real N - real r) / real r = (real L * real r + (real N - real r)) / real r"
            using n by (simp add: field_simps)
          ultimately show ?thesis by simp
        qed
        have "(real L + (real N - real r) / real r) * \<bar>phi\<bar> \<le> (2 * real N / real r) * (pi * real r / (2 * real N))"
          by (rule mult_mono [OF Lsum phi_le]) simp_all
        also have "\<dots> = pi" using n by (simp add: field_simps)
        finally show ?thesis unfolding t_def by (simp add: algebra_simps)
      qed
      ultimately have "(real N - real r) / real r * \<bar>phi\<bar> \<le> min t (pi - t)" by simp
      hence "2 / pi * ((real N - real r) / real r * \<bar>phi\<bar>) \<le> 2 / pi * min t (pi - t)"
        by (rule mult_left_mono) simp
      thus ?thesis by (simp only: mult.assoc)
    qed
    also have "\<dots> \<le> sin t" by (rule jordan_both_sides [OF t0 tpi])
    finally have "2 / pi * ((real N - real r) / real r) * \<bar>phi\<bar> \<le> sin t" .
    hence "2 / pi * ((real N - real r) / real r) \<le> sin t / \<bar>phi\<bar>"
      using phi_pos by (simp add: field_simps)
    also have "\<dots> \<le> sin t / \<bar>sin phi\<bar>"
      using sin_phi sin_ge_zero [OF t0 tpi] by (intro divide_left_mono) auto
    finally show ?thesis using norm by simp
  qed
  show "4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N ?v) j"
    unfolding prob using peak_arith [OF n(2) n(1) _ Lr(1) lower] L(1) by simp
qed

section \<open>Recovering the period\<close>

text \<open>If \<open>j/N\<close> is within \<open>1/(2N)\<close> of \<open>c/r\<close> with \<open>c\<close> coprime to \<open>r\<close> and \<open>r\<^sup>2 < N\<close>, no fraction with a smaller
  denominator is that close: two such fractions \<open>c/r \<noteq> a/b\<close> would differ by at least \<open>1/(r b) > 1/N\<close>.\<close>
lemma recover_period:
  fixes N r j :: nat and c :: int
  assumes r: "0 < r" and rr: "r * r < N" and cop: "coprime c (int r)"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "recover N j = r"
  unfolding recover_def
proof (rule Least_equality)
  show "0 < r \<and> (\<exists>a::int. 2 * \<bar>int j * int r - a * int N\<bar> \<le> int r)" using r near by blast
next
  fix b assume "0 < b \<and> (\<exists>a::int. 2 * \<bar>int j * int b - a * int N\<bar> \<le> int b)"
  then obtain a where b: "0 < b" and ab: "2 * \<bar>int j * int b - a * int N\<bar> \<le> int b" by blast
  show "r \<le> b"
  proof (rule ccontr)
    assume "\<not> r \<le> b"
    hence br: "b < r" by simp
    have "int N * \<bar>int b * c - a * int r\<bar>
        = \<bar>int r * (int j * int b - a * int N) - int b * (int j * int r - c * int N)\<bar>"
    proof -
      have "int r * (int j * int b - a * int N) - int b * (int j * int r - c * int N)
          = int N * (int b * c - a * int r)" by (simp add: algebra_simps)
      thus ?thesis by (simp add: abs_mult)
    qed
    also have "\<dots> \<le> int r * \<bar>int j * int b - a * int N\<bar> + int b * \<bar>int j * int r - c * int N\<bar>"
      by (rule order_trans [OF abs_triangle_ineq4]) (simp add: abs_mult)
    also have "2 * \<dots> \<le> 2 * (int r * int b)"
    proof -
      have "int r * (2 * \<bar>int j * int b - a * int N\<bar>) \<le> int r * int b"
        using ab by (rule mult_left_mono) simp
      moreover have "int b * (2 * \<bar>int j * int r - c * int N\<bar>) \<le> int b * int r"
        using near by (rule mult_left_mono) simp
      ultimately show ?thesis by (simp add: algebra_simps)
    qed
    finally have le: "int N * \<bar>int b * c - a * int r\<bar> \<le> int r * int b" by simp
    have lt: "int r * int b < int N"
    proof -
      have "r * b < r * r" using br r by (rule mult_strict_left_mono)
      hence "r * b < N" using rr by linarith
      thus ?thesis by (simp only: of_nat_mult [symmetric] of_nat_less_iff)
    qed
    have "\<bar>int b * c - a * int r\<bar> < 1"
    proof (rule ccontr)
      assume "\<not> \<bar>int b * c - a * int r\<bar> < 1"
      hence "int N * 1 \<le> int N * \<bar>int b * c - a * int r\<bar>" by (intro mult_left_mono) simp_all
      thus False using le lt by linarith
    qed
    hence "int b * c = a * int r" by simp
    hence "int r dvd int b * c" by simp
    hence "int r dvd int b" using cop by (simp add: coprime_dvd_mult_left_iff coprime_commute)
    hence "r dvd b" by simp
    thus False using b br by (simp add: nat_dvd_not_less)
  qed
qed

text \<open>One run of Shor's algorithm (QFT, measure \<open>j\<close>, output \<open>recover N j\<close>) returns the period with probability
  at least \<open>4/\<pi>\<^sup>2 \<cdot> \<phi>(r)/r \<cdot> (1 - r/N)\<^sup>3\<close>: each \<open>c < r\<close> coprime to \<open>r\<close> has its own nearest outcome
  \<open>j\<^sub>c = round (c N / r)\<close>, these are distinct, and each is recovered and has the peak probability.\<close>
theorem shor_general_success:
  assumes r: "0 < r" and rr: "r * r < N" and x0: "x0 < r"
  shows "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
    \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
proof -
  have rN: "r < N" using le_square [of r] rr by linarith
  define C where "C = {c. c < r \<and> coprime c r}"
  define jc where "jc c = (2 * c * N + r) div (2 * r)" for c :: nat
  define bound where "bound = 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3"
  let ?v = "periodic_state N r x0"
  have near: "2 * \<bar>int (jc c) * int r - int c * int N\<bar> \<le> int r" for c
  proof -
    have "jc c * (2 * r) \<le> 2 * c * N + r" unfolding jc_def by (rule div_times_less_eq_dividend)
    hence lo: "2 * (jc c * r) \<le> 2 * (c * N) + r" by (simp add: algebra_simps)
    have "2 * c * N + r < 2 * r + 2 * r * jc c" unfolding jc_def
      using r by (intro dividend_less_times_div) simp
    hence hi: "2 * (c * N) + r < 2 * (jc c * r) + 2 * r" by (simp add: algebra_simps)
    have "2 * \<bar>int (jc c * r) - int (c * N)\<bar> \<le> int r" using lo hi by arith
    thus ?thesis by simp
  qed
  have jc_lt: "jc c < N" if "c < r" for c
  proof -
    have "Suc c * N \<le> r * N" using that by (intro mult_le_mono1) simp
    hence "2 * c * N + r < 2 * r * N" using rN by (simp add: algebra_simps)
    thus ?thesis unfolding jc_def using r by (simp add: div_less_iff_less_mult mult.commute)
  qed
  have hit: "jc ` C \<subseteq> {j. j < N \<and> recover N j = r}"
  proof
    fix j assume "j \<in> jc ` C"
    then obtain c where c: "c < r" "coprime c r" and j: "j = jc c" by (auto simp: C_def)
    have "coprime (int c) (int r)" using c(2) by simp
    thus "j \<in> {j. j < N \<and> recover N j = r}"
      using recover_period [OF r rr _ near [of c]] jc_lt [OF c(1)] j by simp
  qed
  have inj: "inj_on jc C"
  proof
    fix c c' assume cc: "c \<in> C" "c' \<in> C" and eq: "jc c = jc c'"
    have "2 * \<bar>int (jc c') * int r - int c * int N\<bar> \<le> int r"
      using near [of c] eq by simp
    hence "2 * \<bar>int c * int N - int c' * int N\<bar> \<le> 2 * int r"
      using near [of c'] by arith
    hence "\<bar>int c * int N - int c' * int N\<bar> \<le> int r" by simp
    hence "\<bar>(int c - int c') * int N\<bar> \<le> int r" by (simp only: left_diff_distrib)
    hence "\<bar>int c - int c'\<bar> * int N \<le> int r" by (simp add: abs_mult)
    have "\<bar>int c - int c'\<bar> < 1"
    proof (rule ccontr)
      assume "\<not> \<bar>int c - int c'\<bar> < 1"
      hence "1 * int N \<le> \<bar>int c - int c'\<bar> * int N" by (intro mult_right_mono) simp_all
      thus False using \<open>\<bar>int c - int c'\<bar> * int N \<le> int r\<close> rN by linarith
    qed
    thus "c = c'" by simp
  qed
  have peak: "bound \<le> prob (qft N ?v) (jc c)" if "c \<in> C" for c
    using shor_peak [OF r rN x0 jc_lt near] that by (simp add: C_def bound_def)
  have "4 / pi\<^sup>2 * (real (card C) / real r) * (1 - real r / real N) ^ 3 = (\<Sum>c\<in>C. bound)"
    using r by (simp add: bound_def field_simps)
  also have "\<dots> \<le> (\<Sum>c\<in>C. prob (qft N ?v) (jc c))"
    by (rule sum_mono) (rule peak)
  also have "\<dots> = (\<Sum>j\<in>jc ` C. prob (qft N ?v) j)"
    by (simp add: sum.reindex [OF inj])
  also have "\<dots> \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N ?v) j)"
    by (rule sum_mono2) (simp_all add: hit prob_def)
  finally show ?thesis by (simp add: C_def)
qed

end
