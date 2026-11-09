theory Shor_General
  imports Quantum_Basics
begin


text \<open>Classical step of Shor's algorithm: from a nontrivial square root of unity @{text x}
  modulo @{text n} (with @{text "x \<noteq> \<plusminus>1"}), @{text "gcd (x - 1) n"} is a nontrivial factor.\<close>

lemma sf_core:
  fixes n x :: nat
  assumes n: "1 < n" and x0: "0 < x" and sq: "(x * x) mod n = 1"
    and x1: "x mod n \<noteq> 1" and xm: "x mod n \<noteq> n - 1"
  shows "1 < gcd (x - 1) n \<and> gcd (x - 1) n < n"
proof -
  have n_pos: "0 < n" using n by simp
  obtain y where hy: "x = y + 1" using x0 by (cases x) auto
  have xm1: "x - 1 = y" using hy by simp
  have h0: "n * ((x * x) div n) + (x * x) mod n = x * x" by (metis div_mult_mod_eq mult.commute)
  have h1: "y * (y + 2) = n * ((x * x) div n)"
  proof -
    have e: "x * x = y * (y + 2) + 1" using hy by (simp add: algebra_simps)
    show ?thesis using h0 e sq by linarith
  qed
  have dvd_y: "n dvd y * (y + 2)" using h1 by simp
  have d_dvd: "gcd y n dvd n" by (rule gcd_dvd2)
  have d_ne0: "gcd y n \<noteq> 0" using d_dvd n_pos by auto
  have d_le: "gcd y n \<le> n" using d_dvd n_pos by (rule dvd_imp_le)
  have d_ne_n: "gcd y n \<noteq> n"
  proof
    assume eq: "gcd y n = n"
    have "n dvd y" using gcd_dvd1[of y n] eq by simp
    then obtain m where ym: "y = n * m" by auto
    have hxe: "x = 1 + m * n" using hy ym by (simp add: add.commute mult.commute)
    have "x mod n = 1 mod n" by (subst hxe) (rule mod_mult_self1)
    moreover have "1 mod n = 1" using n by simp
    ultimately have "x mod n = 1" by simp
    thus False using x1 by simp
  qed
  have d_ne_1: "gcd y n \<noteq> 1"
  proof
    assume g1: "gcd y n = 1"
    have gn1: "gcd n y = 1" by (subst gcd.commute) (rule g1)
    have cop: "coprime n y" by (rule iffD2[OF coprime_iff_gcd_eq_1 gn1])
    have hdvd: "n dvd y + 2" using dvd_y cop coprime_dvd_mult_right_iff by blast
    hence hx: "n dvd x + 1" using hy by simp
    have m1: "(x + 1) mod n = 0" by (rule iffD2[OF mod_eq_0_iff_dvd hx])
    have m2: "(x mod n + 1) mod n = 0" by (rule trans[OF mod_add_left_eq m1])
    have hd: "n dvd x mod n + 1" by (rule iffD2[OF dvd_eq_mod_eq_0 m2])
    have le: "n \<le> x mod n + 1" by (rule dvd_imp_le[OF hd]) arith
    have s_lt: "x mod n < n" by (rule mod_less_divisor[OF n_pos])
    have "x mod n + 1 = n" using le s_lt by arith
    thus False using xm by arith
  qed
  have d_pos: "1 < gcd y n" using d_ne0 d_ne_1 by arith
  have d_lt: "gcd y n < n" using d_le d_ne_n by arith
  show ?thesis using d_pos d_lt xm1 by simp
qed

theorem shor_factor:
  assumes n: "1 < n" and ord: "is_order n a r" and even: "even r"
    and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
proof -
  have r_pos: "0 < r" and mod1: "a ^ r mod n = 1"
    and minimal: "\<forall>k. 0 < k \<longrightarrow> k < r \<longrightarrow> a ^ k mod n \<noteq> 1"
    using ord unfolding is_order_def by auto
  obtain k where rk: "r = 2 * k" using even by (rule evenE)
  have hdiv: "r div 2 = k" using rk by simp
  have kpos: "0 < k" using r_pos rk by arith
  have kr: "k < r" using rk kpos by arith
  have sq: "a ^ (r div 2) * a ^ (r div 2) = a ^ r"
  proof -
    have "a ^ r = a ^ k * a ^ k" using rk by (simp add: mult_2 power_add)
    thus ?thesis using hdiv by simp
  qed
  have x_sq: "(a ^ (r div 2) * a ^ (r div 2)) mod n = 1" using sq mod1 by simp
  have x_ne1: "a ^ (r div 2) mod n \<noteq> 1"
  proof -
    have "a ^ k mod n \<noteq> 1" using minimal kpos kr by blast
    thus ?thesis using hdiv by simp
  qed
  have x_pos: "0 < a ^ (r div 2)"
  proof (rule ccontr)
    assume "\<not> 0 < a ^ (r div 2)"
    hence hx0: "a ^ (r div 2) = 0" by simp
    have "(0 * 0 :: nat) mod n = 1" using x_sq hx0 by simp
    thus False by simp
  qed
  show ?thesis using sf_core[OF n x_pos x_sq x_ne1 not_minus_one] .
qed




(* k(t) = sin t - t cos t has derivative t sin t >= 0 on [0, pi], so k >= 0 there. *)
lemma sin_ge_x_cos:
  fixes x :: real
  assumes "0 \<le> x" "x \<le> pi"
  shows "x * cos x \<le> sin x"
proof -
  have d: "\<And>t :: real. DERIV (\<lambda>t. sin t - t * cos t) t :> cos t - (1 * cos t + (- sin t) * t)"
  proof -
    fix t :: real
    have d1: "DERIV sin t :> cos t" by (rule DERIV_sin)
    have d2: "DERIV (\<lambda>z. z * cos z) t :> 1 * cos t + (- sin t) * t"
      by (rule DERIV_mult[OF DERIV_ident DERIV_cos])
    show "DERIV (\<lambda>t. sin t - t * cos t) t :> cos t - (1 * cos t + (- sin t) * t)"
      by (rule DERIV_diff[OF d1 d2])
  qed
  have mono: "(\<lambda>t. sin t - t * cos t) 0 \<le> (\<lambda>t. sin t - t * cos t) x"
  proof (rule DERIV_nonneg_imp_nondecreasing[OF assms(1)])
    fix t :: real assume "0 \<le> t" "t \<le> x"
    have "t \<le> pi" using \<open>t \<le> x\<close> assms(2) by linarith
    have s: "0 \<le> sin t" using \<open>0 \<le> t\<close> \<open>t \<le> pi\<close> sin_ge_zero by blast
    have ts: "0 \<le> t * sin t" using \<open>0 \<le> t\<close> s by (rule mult_nonneg_nonneg)
    have e: "cos t - (1 * cos t + (- sin t) * t) = t * sin t" by (simp add: algebra_simps)
    have "0 \<le> cos t - (1 * cos t + (- sin t) * t)" using ts e by linarith
    then show "\<exists>y. DERIV (\<lambda>t. sin t - t * cos t) t :> y \<and> 0 \<le> y"
      using d[of t] by blast
  qed
  then show ?thesis by simp
qed

(* Jordan-type bound: sin x / x is nonincreasing on (0, pi/2] and equals 2/pi at pi/2. *)
lemma jordan_sin:
  fixes x :: real
  assumes "0 \<le> x" "x \<le> pi/2"
  shows "2 * x / pi \<le> sin x"
proof (cases "x = 0")
  case True
  then show ?thesis by simp
next
  case False
  then have xpos: "0 < x" using assms(1) by simp
  have hpi: "0 < pi" by simp
  have der: "\<And>y :: real. 0 < y \<Longrightarrow> DERIV (\<lambda>t. sin t / t) y :> (cos y * y - sin y * 1) / (y * y)"
  proof -
    fix y :: real assume "0 < y"
    then show "DERIV (\<lambda>t. sin t / t) y :> (cos y * y - sin y * 1) / (y * y)"
      by (rule_tac DERIV_divide[OF DERIV_sin DERIV_ident]) simp
  qed
  have mono: "(\<lambda>t. sin t / t) (pi/2) \<le> (\<lambda>t. sin t / t) x"
  proof (rule DERIV_nonpos_imp_nonincreasing[OF assms(2)])
    fix y :: real assume hy: "x \<le> y" "y \<le> pi/2"
    then have ypos: "0 < y" using xpos by linarith
    have yle: "y \<le> pi" using hy(2) hpi by linarith
    have kc: "y * cos y \<le> sin y" using sin_ge_x_cos[of y] ypos yle by linarith
    have num: "cos y * y - sin y * 1 \<le> 0" using kc mult.commute[of y "cos y"] by simp
    have den: "0 < y * y" using ypos by (simp add: zero_less_mult_iff)
    have "(cos y * y - sin y * 1) / (y * y) \<le> 0"
      by (rule divide_nonpos_pos[OF num den])
    then show "\<exists>d. DERIV (\<lambda>t. sin t / t) y :> d \<and> d \<le> 0"
      using der[OF ypos] by blast
  qed
  have g_pi: "(\<lambda>t. sin t / t) (pi/2) = 2 / pi" by (simp add: field_simps)
  have ineq: "2 / pi \<le> sin x / x" using mono g_pi by simp
  have e: "sin x / x * x = sin x" using xpos by simp
  have "2 / pi * x \<le> sin x / x * x" by (rule mult_right_mono[OF ineq]) (use xpos in linarith)
  then show ?thesis using e by (simp add: field_simps)
qed

lemma sin_div_lower:
  fixes t q :: real
  assumes "0 < t" "t \<le> pi * q / 2" "0 < q" "q < 2"
  shows "2 / pi * min 1 ((2 - q) / q) \<le> sin t / t"
proof (cases "t \<le> pi/2")
  case True
  have hpi: "0 < pi" by simp
  have j: "2 * t / pi \<le> sin t" using jordan_sin[of t] assms(1) True by simp
  have h1: "2 / pi * t \<le> sin t" using j by (simp add: field_simps)
  have h2: "2 / pi \<le> sin t / t"
    using h1 assms(1) by (simp add: pos_le_divide_eq)
  have m1: "min 1 ((2 - q) / q) \<le> 1" by simp
  have "2 / pi * min 1 ((2 - q) / q) \<le> 2 / pi * 1"
    by (rule mult_left_mono[OF m1]) simp
  then show ?thesis using h2 by simp
next
  case False
  have hpi: "0 < pi" by simp
  have tpi: "t < pi"
  proof -
    have "t \<le> pi * q / 2" using assms(2) by simp
    moreover have "pi * q / 2 < pi" using hpi assms(4) by simp
    ultimately show ?thesis by linarith
  qed
  have ht_half: "pi/2 < t" using False by simp
  have s_nonneg: "0 \<le> pi - t" using tpi by linarith
  have s_le: "pi - t \<le> pi/2" using ht_half by linarith
  have j: "2 * (pi - t) / pi \<le> sin (pi - t)" using jordan_sin[of "pi - t"] s_nonneg s_le by simp
  have sin_eq: "sin (pi - t) = sin t" by (simp add: sin_diff)
  have j2: "2 * (pi - t) / pi \<le> sin t" using j sin_eq by linarith
  have tne: "t \<noteq> 0" using assms(1) by simp
  have qne: "q \<noteq> 0" using assms(3) by simp
  have hm: "min 1 ((2 - q) / q) \<le> (pi - t) / t"
  proof -
    have "min 1 ((2 - q) / q) \<le> (2 - q) / q" by simp
    also have "(2 - q) / q \<le> (pi - t) / t"
    proof -
      have iden: "(pi - t) / t - (2 - q) / q = (q * pi - 2 * t) / (q * t)"
        using tne qne by (simp add: field_simps)
      have num: "0 \<le> q * pi - 2 * t" using assms(2) mult.commute[of q pi] by linarith
      have qt: "0 < q * t" using assms(1) assms(3) by (simp add: zero_less_mult_iff)
      have "0 \<le> (q * pi - 2 * t) / (q * t)"
        by (rule divide_nonneg_nonneg[OF num qt[THEN less_imp_le]])
      then show ?thesis using iden by linarith
    qed
    finally show ?thesis .
  qed
  have "2 / pi * min 1 ((2 - q) / q) \<le> 2 / pi * ((pi - t) / t)"
    by (rule mult_left_mono[OF hm]) (use hpi in simp)
  also have "2 / pi * ((pi - t) / t) = (2 * (pi - t) / pi) / t"
    using hpi tne by (simp add: field_simps)
  also have "\<dots> \<le> sin t / t"
    by (rule divide_right_mono[OF j2]) (use assms(1) in simp)
  finally show ?thesis .
qed

lemma peak_real:
  fixes rho q :: real
  assumes "0 < rho" "rho < 1" "1 - rho \<le> q" "q \<le> 1 + rho"
  shows "(1 - rho)^3 \<le> q * (min 1 ((2 - q) / q))^2"
proof (cases "q \<le> 1")
  case True
  have qpos: "0 < q" using assms by linarith
  have m: "min 1 ((2 - q) / q) = 1"
  proof -
    have "1 \<le> (2 - q) / q"
      by (subst pos_le_divide_eq[OF qpos]) (use True in linarith)
    then show ?thesis by simp
  qed
  have a: "0 \<le> 1 - rho" using assms(2) by linarith
  have b: "1 - rho \<le> 1" using assms(1) by linarith
  have sq: "(1 - rho)^2 \<le> 1" using a b
    by (simp add: power2_eq_square) (rule mult_le_one[OF b a b])
  have "(1 - rho)^3 \<le> (1 - rho)"
  proof -
    have "(1 - rho)^3 = (1 - rho) * (1 - rho)^2" by (simp add: power3_eq_cube power2_eq_square algebra_simps)
    also have "\<dots> \<le> (1 - rho) * 1" by (rule mult_left_mono[OF sq a])
    finally show ?thesis by simp
  qed
  then have "(1 - rho)^3 \<le> q" using assms(3) by linarith
  then show ?thesis using m by simp
next
  case False
  then have q1: "1 < q" by simp
  have qpos: "0 < q" using q1 by linarith
  have m: "min 1 ((2 - q) / q) = (2 - q) / q"
  proof -
    have "(2 - q) / q \<le> 1"
      by (subst pos_divide_le_eq[OF qpos]) (use q1 in linarith)
    then show ?thesis by simp
  qed
  have rhs: "q * ((2 - q) / q)^2 = (2 - q)^2 / q"
    using qpos by (simp add: field_simps power2_eq_square)
  have key: "(1 - rho)^3 * q \<le> (2 - q)^2"
  proof -
    have a: "0 \<le> 1 - rho" using assms(2) by linarith
    have s: "(1 - rho)^3 * q \<le> (1 - rho)^3 * (1 + rho)"
      by (rule mult_left_mono[OF assms(4) zero_le_power[OF a]])
    have t: "(1 - rho)^3 * (1 + rho) \<le> (1 - rho)^2"
    proof -
      have eq: "(1 - rho)^3 * (1 + rho) = (1 - rho)^2 * (1 - rho^2)" by (simp add: power2_eq_square power3_eq_cube algebra_simps)
      have r2: "0 \<le> rho^2" by (rule zero_le_power) (use assms(1) in linarith)
      have "1 - rho^2 \<le> 1" using r2 by simp
      then have "(1 - rho)^2 * (1 - rho^2) \<le> (1 - rho)^2 * 1"
        by (rule mult_left_mono) simp
      then show ?thesis using eq by simp
    qed
    have h1: "1 - rho \<le> 2 - q" using assms(4) by linarith
    have u: "(1 - rho)^2 \<le> (2 - q)^2" using power_mono[OF h1 a, of 2] by simp
    show ?thesis using s t u by linarith
  qed
  have "(1 - rho)^3 \<le> (2 - q)^2 / q"
    by (subst pos_le_divide_eq[OF qpos]) (rule key)
  then show ?thesis using m rhs by simp
qed




lemma sg_ineq:
  fixes N r b u v w :: int
  assumes e: "N * w = r * u - b * v" and hu: "2 * \<bar>u\<bar> \<le> b" and hv: "2 * \<bar>v\<bar> \<le> r"
    and hN: "0 \<le> N" and hr: "0 \<le> r" and hb: "0 \<le> b"
  shows "N * \<bar>w\<bar> \<le> r * b"
proof -
  have A: "N * \<bar>w\<bar> = \<bar>r * u - b * v\<bar>"
    by (simp add: e[symmetric] abs_mult abs_of_nonneg hN)
  have B: "\<bar>r * u - b * v\<bar> \<le> r * \<bar>u\<bar> + b * \<bar>v\<bar>"
  proof -
    have "\<bar>r * u - b * v\<bar> \<le> \<bar>r * u\<bar> + \<bar>b * v\<bar>" by (rule abs_triangle_ineq4)
    also have "\<dots> = r * \<bar>u\<bar> + b * \<bar>v\<bar>" by (simp add: abs_mult abs_of_nonneg hr hb)
    finally show ?thesis .
  qed
  have C: "r * (2 * \<bar>u\<bar>) \<le> r * b" by (rule mult_left_mono[OF hu hr])
  have D: "b * (2 * \<bar>v\<bar>) \<le> b * r" by (rule mult_left_mono[OF hv hb])
  have E1: "r * (2 * \<bar>u\<bar>) = 2 * (r * \<bar>u\<bar>)" by (simp add: algebra_simps)
  have E2: "b * (2 * \<bar>v\<bar>) = 2 * (b * \<bar>v\<bar>)" by (simp add: algebra_simps)
  have E3: "b * r = r * b" by (simp add: mult.commute)
  show ?thesis using A B C D E1 E2 E3 by linarith
qed

lemma sg_no_smaller:
  fixes N r b j c :: nat and a :: int
  assumes rr: "r * r < N" and r: "0 < r" and bpos: "0 < b" and bl: "b < r"
    and cop: "coprime c r"
    and hb: "2 * \<bar>int j * int b - a * int N\<bar> \<le> int b"
    and hc: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r"
  shows False
proof -
  have id: "int N * (int b * int c - int r * a) = int r * (int j * int b - a * int N) - int b * (int j * int r - int c * int N)"
    by (simp add: algebra_simps)
  have bound1: "int N * \<bar>int b * int c - int r * a\<bar> \<le> int r * int b"
    by (rule sg_ineq[OF id _ _ _ _ _]) (use hb hc in auto)
  have rb_lt: "int r * int b < int N"
  proof -
    have "int r * int b < int r * int r" using r bl by (simp add: mult_strict_left_mono)
    moreover have "int r * int r < int N" using rr by (metis of_nat_less_iff of_nat_mult)
    ultimately show ?thesis by linarith
  qed
  have Npos: "(0::int) < int N" using rb_lt bpos r by (meson le_less_trans linorder_not_less mult_le_0_iff zero_le_numeral zero_less_mult_iff of_nat_0_less_iff mult_pos_pos of_nat_0_le_iff)
  have absw: "\<bar>int b * int c - int r * a\<bar> < 1"
  proof -
    have "int N * \<bar>int b * int c - int r * a\<bar> < int N * 1" using bound1 rb_lt by linarith
    then show ?thesis using Npos by (simp only: mult_less_cancel_left_pos)
  qed
  have w0: "int b * int c - int r * a = 0"
  proof -
    have "-1 < int b * int c - int r * a" and "int b * int c - int r * a < 1"
      using absw by (simp_all add: abs_less_iff)
    then show ?thesis by linarith
  qed
  have dvd1: "int r dvd int (b * c)"
    using w0 by (simp add: dvd_def) (metis mult.commute mult.left_commute mult_of_nat_commute of_nat_mult)
  have dvd2: "r dvd b * c" using dvd1 by (metis int_dvd_int_iff)
  have cop': "coprime r c" using cop by (simp add: coprime_commute)
  have dvd3: "r dvd b" using dvd2 cop' by (metis coprime_dvd_mult_nat mult.commute)
  have "r \<le> b" using dvd3 bpos by (rule dvd_imp_le)
  with bl show False by simp
qed

lemma sg_recover:
  fixes N r c j :: nat
  assumes rr: "r * r < N" and r: "0 < r" and cop: "coprime c r"
    and hc: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r"
  shows "recover N j = r"
proof -
  let ?P = "\<lambda>b. 0 < b \<and> (\<exists>a::int. 2 * \<bar>int j * int b - a * int N\<bar> \<le> int b)"
  have P_r: "?P r" using r hc by auto
  have le_r: "recover N j \<le> r"
    unfolding recover_def by (rule Least_le[of ?P r]) (rule P_r)
  have P_ex: "\<exists>x. ?P x" using P_r by blast
  have P_rec: "?P (recover N j)"
    unfolding recover_def by (rule LeastI_ex[OF P_ex])
  have ge_r: "r \<le> recover N j"
  proof (rule ccontr)
    assume "\<not> r \<le> recover N j"
    then have bl: "recover N j < r" by simp
    then obtain a where ha: "2 * \<bar>int j * int (recover N j) - a * int N\<bar> \<le> int (recover N j)"
      using P_rec by blast
    have bpos: "0 < recover N j" using P_rec by blast
    show False using sg_no_smaller[OF rr r bpos bl cop ha hc] by blast
  qed
  from le_r ge_r show ?thesis by simp
qed

lemma sg_round:
  fixes N r c :: nat
  assumes r: "0 < r" and rr: "r * r < N" and cr: "c < r"
  shows "(2 * c * N + r) div (2 * r) < N \<and>
    2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int r - int c * int N\<bar> \<le> int r"
proof -
  obtain j where jdef: "j = (2 * c * N + r) div (2 * r)" by blast
  obtain m where mdef: "m = (2 * c * N + r) mod (2 * r)" by blast
  have dm: "2 * r * j + m = 2 * c * N + r"
    using div_mult_mod_eq[of "2 * c * N + r" "2 * r"] jdef mdef by (simp add: mult.commute)
  have mlt: "m < 2 * r" using mdef r by simp
  have ei: "2 * int r * int j + int m = 2 * int c * int N + int r"
    using dm by (metis of_nat_add of_nat_mult of_nat_numeral mult.commute mult.left_commute)
  have mlt': "int m < 2 * int r" using mlt by simp
  have hX: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r"
  proof -
    have "\<bar>2 * (int j * int r - int c * int N)\<bar> = 2 * \<bar>int j * int r - int c * int N\<bar>"
      by (simp add: abs_mult)
    moreover have "\<bar>2 * (int j * int r - int c * int N)\<bar> \<le> int r"
      unfolding abs_le_iff using ei mlt' by linarith
    ultimately show ?thesis by linarith
  qed
  have jN: "j < N"
  proof (rule ccontr)
    assume "\<not> j < N"
    then have "N \<le> j" by simp
    then have "r * N \<le> r * j" by simp
    then have "2 * r * N \<le> 2 * r * j" by simp
    moreover have "(c + 1) * N \<le> r * N" using cr by (intro mult_right_mono) auto
    moreover have "r < 2 * N" using rr r by (metis One_nat_def le_mult_self_eq less_le_trans mult_le_mono2 nat_less_le not_less_eq one_le_numeral)
    ultimately have "2 * c * N + 2 * N \<le> 2 * r * j" by (simp add: algebra_simps)
    then show False using dm by linarith
  qed
  from jN hX jdef show ?thesis by simp
qed

lemma sg_inj:
  fixes N r c c' j :: nat
  assumes rN: "r < N"
    and h1: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r"
    and h2: "2 * \<bar>int j * int r - int c' * int N\<bar> \<le> int r"
  shows "c = c'"
proof -
  have id: "int N * (int c' - int c) = (int j * int r - int c * int N) - (int j * int r - int c' * int N)"
    by (simp add: algebra_simps)
  have "int N * \<bar>int c' - int c\<bar> = \<bar>int N * (int c' - int c)\<bar>" by (simp add: abs_mult)
  also have "\<dots> = \<bar>(int j * int r - int c * int N) - (int j * int r - int c' * int N)\<bar>" using id by simp
  also have "\<dots> \<le> \<bar>int j * int r - int c * int N\<bar> + \<bar>int j * int r - int c' * int N\<bar>" by (rule abs_triangle_ineq4)
  finally have bnd: "int N * \<bar>int c' - int c\<bar> \<le> int r" using h1 h2 by linarith
  have Npos: "(0::int) < int N" using rN by simp
  have "int N * \<bar>int c' - int c\<bar> < int N * 1" using bnd rN by linarith
  then have lt1: "\<bar>int c' - int c\<bar> < 1" using Npos by (simp only: mult_less_cancel_left_pos)
  then have "int c' - int c = 0" by (simp add: abs_less_iff) linarith
  then show ?thesis by simp
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
proof -
  have rle: "r * 1 \<le> r * r" using r by (intro mult_le_mono2) auto
  have rN: "r < N" using rr rle by linarith
  let ?C = "{c. c < r \<and> coprime c r}"
  let ?T = "{j. j < N \<and> recover N j = r}"
  have finC: "finite ?C" by (rule finite_subset[of _ "{..<r}"]) auto
  have finT: "finite ?T" by (rule finite_subset[of _ "{..<N}"]) auto
  define f where "f c = (2 * c * N + r) div (2 * r)" for c
  have f_spec: "\<forall>c\<in>?C. f c < N \<and> 2 * \<bar>int (f c) * int r - int c * int N\<bar> \<le> int r"
    using sg_round[OF r rr] unfolding f_def by (auto simp: less_imp_le)
  have f_rec: "\<forall>c\<in>?C. recover N (f c) = r"
  proof (intro ballI)
    fix c assume hc: "c \<in> ?C"
    then have cop: "coprime c r" by simp
    show "recover N (f c) = r"
      using f_spec hc cop sg_recover[OF rr r cop] by auto
  qed
  have bnd: "\<forall>c\<in>?C. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) (f c)"
  proof (intro ballI)
    fix c assume hc: "c \<in> ?C"
    then have cr: "c < r" by simp
    have "f c < N" using f_spec hc by auto
    moreover have "2 * \<bar>int (f c) * int r - int c * int N\<bar> \<le> int r" using f_spec hc by auto
    ultimately show "4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) (f c)"
      using shor_peak[OF r rN x0, of "f c" "int c"] by auto
  qed
  have inj: "inj_on f ?C"
  proof (rule inj_onI)
    fix c c' assume hc: "c \<in> ?C" and hc': "c' \<in> ?C" and eq: "f c = f c'"
    have h1: "2 * \<bar>int (f c') * int r - int c * int N\<bar> \<le> int r"
      using f_spec hc eq by auto
    have h2: "2 * \<bar>int (f c') * int r - int c' * int N\<bar> \<le> int r"
      using f_spec hc' by auto
    show "c = c'" using sg_inj[OF rN h1 h2] by simp
  qed
  have sub: "f ` ?C \<subseteq> ?T"
  proof
    fix x assume "x \<in> f ` ?C"
    then obtain c where hc: "c \<in> ?C" and "x = f c" by blast
    then show "x \<in> ?T" using f_spec f_rec by auto
  qed
  have sum1: "(\<Sum>c\<in>?C. prob (qft N (periodic_state N r x0)) (f c)) = (\<Sum>j\<in>f ` ?C. prob (qft N (periodic_state N r x0)) j)"
    by (simp add: sum.reindex[OF inj])
  have sum2: "(\<Sum>j\<in>f ` ?C. prob (qft N (periodic_state N r x0)) j) \<le> (\<Sum>j\<in>?T. prob (qft N (periodic_state N r x0)) j)"
    by (rule sum_mono2[OF finT sub]) (auto simp: prob_def)
  have sum3: "real (card ?C) * (4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3) \<le> (\<Sum>c\<in>?C. prob (qft N (periodic_state N r x0)) (f c))"
  proof -
    have "(\<Sum>c\<in>?C. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3) \<le> (\<Sum>c\<in>?C. prob (qft N (periodic_state N r x0)) (f c))"
      by (rule sum_mono) (use bnd in auto)
    then show ?thesis by (simp add: sum_constant)
  qed
  have eq: "4 / pi\<^sup>2 * (real (card ?C) / real r) * (1 - real r / real N) ^ 3
      = real (card ?C) * (4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3)"
    by (simp add: field_simps)
  show ?thesis using eq sum3 sum1 sum2 by linarith
qed

end
