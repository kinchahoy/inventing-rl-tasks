theory Shor_General
  imports Quantum_Basics
begin

section \<open>Real analysis: Jordan's inequality and the geometric sum\<close>

lemma sin_cos_aux:
  assumes y0: "0 \<le> y" and yp: "y \<le> pi"
  shows "y * cos y - sin y \<le> 0"
proof -
  have "(\<lambda>x. x * cos x - sin x) y \<le> (\<lambda>x. x * cos x - sin x) 0"
  proof (rule DERIV_nonpos_imp_nonincreasing[OF y0])
    fix x assume hx: "0 \<le> x" "x \<le> y"
    have xpi: "x \<le> pi" using hx yp by linarith
    have sx: "0 \<le> sin x" using sin_ge_zero hx(1) xpi by blast
    have "((\<lambda>x. x * cos x - sin x) has_real_derivative (cos x + x * (- sin x) - cos x)) (at x)"
      by (auto intro!: derivative_eq_intros)
    moreover have "cos x + x * (- sin x) - cos x \<le> 0"
      using hx(1) sx mult_nonneg_nonneg[OF hx(1) sx] by linarith
    ultimately show "\<exists>d. ((\<lambda>x. x * cos x - sin x) has_real_derivative d) (at x) \<and> d \<le> 0"
      by blast
  qed
  then show ?thesis by simp
qed

lemma jordan_sin_aux:
  assumes y0: "0 < y" and yp: "y \<le> pi/2"
  shows "2 / pi \<le> sin y / y"
proof -
  have "(\<lambda>x. sin x / x) (pi/2) \<le> (\<lambda>x. sin x / x) y"
  proof (rule DERIV_nonpos_imp_nonincreasing[OF yp])
    fix x assume hx: "y \<le> x" "x \<le> pi/2"
    have x0: "0 < x" using hx y0 by linarith
    have xne: "x \<noteq> 0" using x0 by simp
    have xpi: "x \<le> pi" using hx(2) pi_gt_zero by linarith
    have num: "x * cos x - sin x \<le> 0" using sin_cos_aux[of x] x0 xpi by linarith
    have "((\<lambda>x. sin x / x) has_real_derivative ((cos x * x - sin x * 1) / x^2)) (at x)"
      using xne by (auto intro!: derivative_eq_intros simp: power2_eq_square)
    moreover have "(cos x * x - sin x * 1) / x^2 \<le> 0"
      using num by (auto intro!: divide_nonpos_nonneg simp: algebra_simps)
    ultimately show "\<exists>d. ((\<lambda>x. sin x / x) has_real_derivative d) (at x) \<and> d \<le> 0"
      by blast
  qed
  moreover have "(\<lambda>x. sin x / x) (pi/2) = 2 / pi" by simp
  ultimately show ?thesis by simp
qed

lemma jordan_sin: "0 \<le> y \<Longrightarrow> y \<le> pi/2 \<Longrightarrow> 2 * y / pi \<le> sin y"
proof -
  assume h0: "0 \<le> y" and h1: "y \<le> pi/2"
  show "2 * y / pi \<le> sin y"
  proof (cases "y = 0")
    case True
    then show ?thesis by simp
  next
    case False
    then have ypos: "0 < y" using h0 by simp
    from jordan_sin_aux[OF ypos h1] have "2 / pi * y \<le> sin y"
      using ypos by (simp add: pos_le_divide_eq)
    then show ?thesis by (simp add: field_simps)
  qed
qed

lemma jordan_cos: "0 \<le> z \<Longrightarrow> z \<le> pi/2 \<Longrightarrow> 1 - 2 * z / pi \<le> cos z"
proof -
  assume h0: "0 \<le> z" and h1: "z \<le> pi/2"
  have "sin (pi/2 - z) = cos z" by (simp add: sin_diff)
  moreover have "2 * (pi/2 - z) / pi = 1 - 2 * z / pi" using pi_gt_zero by (simp add: field_simps)
  moreover have "2 * (pi/2 - z) / pi \<le> sin (pi/2 - z)"
    using jordan_sin[of "pi/2 - z"] h0 h1 by simp
  ultimately show ?thesis by simp
qed

lemma cis_sub_one_norm: "cmod (cis a - 1) = 2 * \<bar>sin (a/2)\<bar>"
proof -
  have e: "2 * (a/2) = a" by simp
  have cosA: "cos a = 1 - 2 * (sin (a/2))^2"
  proof -
    have h: "cos (2 * (a/2)) = 1 - 2 * (sin (a/2))^2" using cos_double_sin[of "a/2"] by simp
    show ?thesis using h e by simp
  qed
  have sinA: "sin a = 2 * sin (a/2) * cos (a/2)"
  proof -
    have h: "sin (2 * (a/2)) = 2 * sin (a/2) * cos (a/2)" using sin_double[of "a/2"] by simp
    show ?thesis using h e by simp
  qed
  have pyth: "(sin (a/2))^2 + (cos (a/2))^2 = 1" by simp
  have c2: "(cos (a/2))^2 = 1 - (sin (a/2))^2" by (simp add: cos_squared_eq)
  have sq: "(cos a - 1)^2 + (sin a)^2 = (2 * \<bar>sin (a/2)\<bar>)^2"
    unfolding cosA sinA by (simp add: power_mult_distrib power2_abs c2 algebra_simps)
  have "cmod (cis a - 1) = sqrt ((cos a - 1)^2 + (sin a)^2)"
    by (simp add: cis_def norm_complex_def)
  also have "... = sqrt ((2 * \<bar>sin (a/2)\<bar>)^2)" using sq by simp
  also have "... = 2 * \<bar>sin (a/2)\<bar>"
  proof -
    have hnn: "0 \<le> 2 * \<bar>sin (a/2)\<bar>" by simp
    show ?thesis by (rule real_sqrt_unique[OF refl hnn])
  qed
  finally show ?thesis .
qed

lemma sin_abs_le: "\<bar>sin (x::real)\<bar> \<le> \<bar>x\<bar>"
proof -
  have "(0 \<le> x \<and> \<bar>sin x\<bar> \<le> \<bar>x\<bar>) \<or> (x < 0 \<and> \<bar>sin x\<bar> \<le> \<bar>x\<bar>)"
  proof (rule disjE[OF le_less_linear[of 0 x]])
    assume pos: "0 \<le> x"
    have h1: "sin x \<le> x" using sin_x_le_x[OF pos] .
    have h2: "- x \<le> sin x" using sin_x_ge_neg_x[OF pos] .
    show ?thesis using h1 h2 pos by (auto simp: abs_le_iff)
  next
    assume neg: "x < 0"
    have nx: "0 \<le> -x" using neg by simp
    have h1: "sin (-x) \<le> -x" using sin_x_le_x[OF nx] .
    have h2: "x \<le> sin (-x)" using sin_x_ge_neg_x[OF nx] by simp
    have "sin x = - sin (-x)" by simp
    then show ?thesis using h1 h2 neg by (auto simp: abs_le_iff)
  qed
  then show ?thesis by auto
qed

lemma abs_sin_eq: "\<bar>z::real\<bar> \<le> pi \<Longrightarrow> \<bar>sin z\<bar> = sin \<bar>z\<bar>"
proof -
  assume hz: "\<bar>z\<bar> \<le> pi"
  show "\<bar>sin z\<bar> = sin \<bar>z\<bar>"
  proof (rule disjE[OF le_less_linear[of 0 z]])
    assume pos: "0 \<le> z"
    have "0 \<le> sin z" using sin_ge_zero pos hz by (simp add: abs_of_nonneg)
    then show ?thesis using pos by simp
  next
    assume neg: "z < 0"
    have nz: "0 \<le> -z" using neg by simp
    have hnz: "-z \<le> pi" using hz by linarith
    have "0 \<le> sin (-z)" using sin_ge_zero nz hnz by blast
    have "sin z = - sin (-z)" by simp
    then show ?thesis using neg \<open>0 \<le> sin (-z)\<close> by simp
  qed
qed

lemma sin_ne_zero_aux: "0 < \<bar>\<phi>\<bar> \<Longrightarrow> \<bar>\<phi>\<bar> < 2 * pi \<Longrightarrow> sin (\<phi>/2) \<noteq> 0"
proof -
  assume p0: "0 < \<bar>\<phi>\<bar>" and p1: "\<bar>\<phi>\<bar> < 2 * pi"
  have "0 < \<bar>sin (\<phi>/2)\<bar>"
  proof (rule disjE[OF le_less_linear[of 0 \<phi>]])
    assume pos: "0 \<le> \<phi>"
    then have "0 < \<phi>/2" using p0 by simp
    moreover have "\<phi>/2 < pi" using p1 pos by simp
    ultimately have "0 < sin (\<phi>/2)" using sin_gt_zero by blast
    then show ?thesis by simp
  next
    assume neg: "\<phi> < 0"
    then have "0 < -(\<phi>/2)" using p0 by simp
    moreover have "-(\<phi>/2) < pi" using p1 neg by simp
    ultimately have "0 < sin (-(\<phi>/2))" using sin_gt_zero by blast
    then show ?thesis by simp
  qed
  then show ?thesis by auto
qed

lemma geo_sin:
  fixes \<phi> :: real and M :: nat
  assumes p0: "0 < \<bar>\<phi>\<bar>" and p1: "\<bar>\<phi>\<bar> < 2 * pi"
  shows "cmod (\<Sum>k<M. cis (real k * \<phi>)) * \<bar>sin (\<phi>/2)\<bar> = \<bar>sin (real M * \<phi> / 2)\<bar>"
proof -
  have sne: "sin (\<phi>/2) \<noteq> 0" using sin_ne_zero_aux[OF p0 p1] .
  have w1: "cis \<phi> \<noteq> 1"
  proof
    assume "cis \<phi> = 1"
    then have "cmod (cis \<phi> - 1) = 0" by simp
    then show False using cis_sub_one_norm[of \<phi>] sne by simp
  qed
  have geo: "(\<Sum>k<M. cis (real k * \<phi>)) * (cis \<phi> - 1) = cis (real M * \<phi>) - 1"
  proof -
    have "(\<Sum>k<M. cis (real k * \<phi>)) = (\<Sum>k<M. (cis \<phi>)^k)" by (simp add: DeMoivre)
    also have "... = ((cis \<phi>)^M - 1) / (cis \<phi> - 1)"
      using geometric_sum[OF w1] by simp
    finally have S: "(\<Sum>k<M. cis (real k * \<phi>)) = ((cis \<phi>)^M - 1) / (cis \<phi> - 1)" .
    have "cis \<phi> - 1 \<noteq> 0" using w1 by simp
    then have "(\<Sum>k<M. cis (real k * \<phi>)) * (cis \<phi> - 1) = (cis \<phi>)^M - 1" using S by simp
    also have "(cis \<phi>)^M = cis (real M * \<phi>)" by (simp add: DeMoivre)
    finally show ?thesis .
  qed
  have "cmod (\<Sum>k<M. cis (real k * \<phi>)) * cmod (cis \<phi> - 1) = cmod (cis (real M * \<phi>) - 1)"
    using geo by (metis norm_mult)
  then have "cmod (\<Sum>k<M. cis (real k * \<phi>)) * (2 * \<bar>sin (\<phi>/2)\<bar>) = 2 * \<bar>sin (real M * \<phi> / 2)\<bar>"
    using cis_sub_one_norm[of \<phi>] cis_sub_one_norm[of "real M * \<phi>"] by simp
  then show ?thesis by linarith
qed


section \<open>Classical step\<close>

theorem shor_factor:
  assumes n: "1 < n" and ord: "is_order n a r" and even: "even r"
    and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
proof -
  from ord have r0: "0 < r" and rpow: "a ^ r mod n = 1"
    and minimal: "\<And>k. 0 < k \<Longrightarrow> k < r \<Longrightarrow> a ^ k mod n \<noteq> 1"
    unfolding is_order_def by blast+
  obtain k where rk: "r = 2 * k" using even by (auto elim: evenE)
  have hk: "r div 2 = k" using rk by simp
  have kpos: "0 < k" using r0 rk by simp
  have kr: "k < r" using rk kpos by simp
  obtain z where zdef: "z = a ^ k" by blast
  have hz1: "z mod n \<noteq> 1" using minimal[OF kpos kr] zdef by simp
  have hnm: "z mod n \<noteq> n - 1" using not_minus_one hk zdef by simp
  have arz: "a ^ r = z * z"
  proof -
    have "a ^ r = a ^ (k + k)" using rk by (simp add: mult_2)
    also have "... = a ^ k * a ^ k" by (rule power_add)
    finally show ?thesis using zdef by simp
  qed
  have zmod: "z * z mod n = 1" using rpow arz by simp
  have rne: "r \<noteq> 0" using r0 by simp
  have a_ne0: "a \<noteq> 0"
  proof
    assume a00: "a = 0"
    have h1: "a ^ r = 0" using a00 r0 by (simp add: zero_power)
    show False using rpow h1 by simp
  qed
  have a0: "0 < a" using a_ne0 by (simp add: neq0_conv)
  have zpos: "0 < z" using a0 zdef by simp
  obtain m where zm: "z = m + 1" using zpos by (cases z) auto
  have key: "(z - 1) * (z + 1) + 1 = z * z" using zm by (simp add: algebra_simps)
  have dvd_n: "n dvd (z - 1) * (z + 1)"
  proof -
    have dm: "z * z div n * n + z * z mod n = z * z" by (rule div_mult_mod_eq)
    have e1: "z * z div n * n + 1 = z * z" using dm zmod by simp
    have e2: "(z - 1) * (z + 1) + 1 = z * z div n * n + 1" using key e1 by simp
    have e3: "(z - 1) * (z + 1) = z * z div n * n" using e2 by simp
    have "(z - 1) * (z + 1) = n * (z * z div n)" using e3 by (simp add: mult.commute)
    then show ?thesis by (rule dvdI)
  qed
  have npos: "0 < n" using n by simp
  have gcd_dvd: "gcd (z - 1) n dvd n" by simp
  have gle: "gcd (z - 1) n \<le> n" using gcd_dvd npos by (rule dvd_imp_le)
  have gne0: "gcd (z - 1) n \<noteq> 0" using gcd_dvd npos by auto
  have gne_n: "gcd (z - 1) n \<noteq> n"
  proof
    assume eq: "gcd (z - 1) n = n"
    have "n dvd z - 1" using eq gcd_dvd1[of "z - 1" n] by simp
    then obtain q where q: "z - 1 = n * q" by (auto elim: dvdE)
    have zq: "z = n * q + 1" using q zpos by linarith
    have zq2: "z = 1 + q * n" using zq by (simp add: ac_simps)
    have "z mod n = 1 mod n" by (subst zq2) (rule mod_mult_self1)
    also have "... = 1" using mod_less[of 1 n] n by simp
    finally show False using hz1 by simp
  qed
  have glt: "gcd (z - 1) n < n" using gle gne_n by auto
  have g1: "gcd (z - 1) n \<noteq> 1"
  proof
    assume g1: "gcd (z - 1) n = 1"
    have cop: "coprime n (z - 1)" using g1 by (simp add: gcd.commute coprime_iff_gcd_eq_1)
    have nz: "n dvd z + 1" using dvd_n cop by (metis add.commute coprime_dvd_mult_right_iff mult.commute)
    have e: "z + 1 = (z mod n + 1) + n * (z div n)"
      using div_mult_mod_eq[of z n] by (simp add: mult.commute)
    have nw: "n dvd (z mod n + 1)"
    proof -
      have "n dvd (z mod n + 1) + n * (z div n)" using nz e by (simp add: add.commute)
      then show ?thesis using dvd_add_left_iff[of n "n * (z div n)" "z mod n + 1"] by simp
    qed
    have wlt: "z mod n < n" using npos by simp
    have "n \<le> z mod n + 1" using nw by (rule dvd_imp_le) simp
    then have "z mod n = n - 1" using wlt by linarith
    then show False using hnm by simp
  qed
  have ggt: "1 < gcd (z - 1) n"
  proof -
    have h1: "0 < gcd (z - 1) n" using gne0 by (simp add: neq0_conv)
    show ?thesis using h1 g1 by arith
  qed
  have "a ^ (r div 2) = z" using hk zdef by simp
  then show ?thesis using ggt glt by simp
qed

theorem shor_peak:
  assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r" and j: "j < N"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "is_state N (periodic_state N r x0) \<and>
    4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
  sorry

theorem shor_general_success:
  assumes r: "0 < r" and rr: "r * r < N" and x0: "x0 < r"
  shows "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
    \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
  sorry

end
