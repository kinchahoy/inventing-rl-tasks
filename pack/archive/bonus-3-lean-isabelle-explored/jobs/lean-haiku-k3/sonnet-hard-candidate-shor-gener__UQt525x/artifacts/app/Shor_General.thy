theory Shor_General
  imports Quantum_Basics
begin
lemma shor_xcos_le: "0 \<le> x \<Longrightarrow> x \<le> pi/2 \<Longrightarrow> x * cos x \<le> sin x"
proof -
  assume x0: "0 \<le> x" and x1: "x \<le> pi/2"
  have "(\<lambda>y. y * cos y - sin y) x \<le> (\<lambda>y. y * cos y - sin y) 0"
  proof (rule DERIV_nonpos_imp_nonincreasing[where a=0 and b=x])
    show "0 \<le> x" using x0 .
  next
    fix y assume hy: "0 \<le> y" "y \<le> x"
    have ypi: "y \<le> pi" using hy x1 pi_gt_zero by linarith
    have s0: "0 \<le> sin y" using sin_ge_zero[OF hy(1) ypi] .
    have d: "DERIV (\<lambda>y. y * cos y - sin y) y :> (1 * cos y + y * (- sin y)) - cos y" by (auto intro!: derivative_eq_intros)
    show "\<exists>z. DERIV (\<lambda>y. y * cos y - sin y) y :> z \<and> z \<le> 0" using d s0 hy(1) by (intro exI[where x="(1 * cos y + y * (- sin y)) - cos y"]) (auto intro!: mult_nonneg_nonneg simp: algebra_simps)
  qed
  thus ?thesis by simp
qed
lemma shor_jordan: "0 \<le> x \<Longrightarrow> x \<le> pi/2 \<Longrightarrow> 2/pi * x \<le> sin x"
proof -
  assume x0: "0 \<le> x" and x1: "x \<le> pi/2"
  show ?thesis
  proof (cases "x = 0")
    case True then show ?thesis by simp
  next
    case False
    then have xp: "0 < x" using x0 by simp
    have "(\<lambda>y. sin y / y) (pi/2) \<le> (\<lambda>y. sin y / y) x"
    proof (rule DERIV_nonpos_imp_nonincreasing[where a=x and b="pi/2"])
      show "x \<le> pi/2" using x1 .
    next
      fix y assume hy: "x \<le> y" "y \<le> pi/2"
      then have yp: "0 < y" using xp by linarith
      have yne: "y \<noteq> 0" using yp by simp
      have d: "DERIV (\<lambda>y. sin y / y) y :> (cos y * y - sin y * 1) / y^2" by (auto intro!: derivative_eq_intros simp: power2_eq_square yne)
      have "(cos y * y - sin y * 1) / y^2 \<le> 0"
      proof (rule divide_nonpos_pos)
        show "cos y * y - sin y * 1 \<le> 0" using shor_xcos_le[of y] hy yp by (simp add: algebra_simps)
        show "0 < y^2" using yp by simp
      qed
      then show "\<exists>z. DERIV (\<lambda>y. sin y / y) y :> z \<and> z \<le> 0" using d by blast
    qed
    then have "2 / pi \<le> sin x / x" by simp
    then have "2/pi * x \<le> sin x / x * x" using xp by (intro mult_right_mono) auto
    then show ?thesis using xp by simp
  qed
qed
lemma shor_key_real:
  fixes P N r T d :: real
  assumes P0: "0 \<le> P" and d0: "0 < d" and N0: "0 < N" and r0: "0 < r" and rN: "r < N" and T0: "0 < T"
    and Tlo: "N - r \<le> T * r" and Thi: "T * r < N + r" and dN: "2 * N * d \<le> r" and rel: "P * \<bar>sin (pi * d)\<bar> = \<bar>sin (pi * T * d)\<bar>"
  shows "4 * (1 - r / N) ^ 3 * (N * T) \<le> P^2 * (pi^2 * r)"
proof -
  have pi0: "0 < pi" by simp
  have pine: "pi \<noteq> 0" using pi0 by simp
  obtain x where xdef: "x = pi * T * d" by blast
  have x0: "0 < x" using xdef d0 T0 pi0 by (simp add: mult_pos_pos)
  have x_le: "2 * N * x \<le> pi * T * r" proof -
    have "2 * N * x = pi * T * (2 * N * d)" using xdef by (simp add: algebra_simps)
    also have "\<dots> \<le> pi * T * r" using dN pi0 T0 by (intro mult_left_mono) (auto)
    finally show ?thesis .
  qed
  have xpi: "x < pi" proof -
    have A: "2 * (N * x) \<le> pi * (T * r)" using x_le by (simp add: algebra_simps)
    have B0: "pi * (T * r) < pi * (N + r)" using Thi pi0 by (intro mult_strict_left_mono) auto
    have B: "pi * (T * r) < pi * N + pi * r" using B0 by (simp add: algebra_simps)
    have C: "pi * r < pi * N" using rN pi0 by (intro mult_strict_left_mono) auto
    have D: "N * x < pi * N" using A B C by linarith
    have "N * x < N * pi" using D by (simp add: mult.commute)
    then show ?thesis using N0 by (simp only: mult_less_cancel_left_pos)
  qed
  have sx: "0 \<le> sin x" using x0 xpi by (intro sin_ge_zero) auto
  have rel': "P * \<bar>sin (pi * d)\<bar> = sin x" using rel xdef sx by simp
  have sd: "\<bar>sin (pi * d)\<bar> \<le> pi * d" using abs_sin_x_le_abs_x[of "pi * d"] d0 pi0 by simp
  have H1: "T * sin x \<le> P * x" proof -
    have "T * sin x = T * (P * \<bar>sin (pi * d)\<bar>)" using rel' by simp
    also have "\<dots> \<le> T * (P * (pi * d))" using sd P0 T0 by (intro mult_left_mono mult_left_mono) auto
    also have "\<dots> = P * x" using xdef by (simp add: algebra_simps)
    finally show ?thesis .
  qed
  obtain u where udef: "u = 1 - r / N" by blast
  have rN1: "r / N < 1" using rN N0 by (simp add: pos_divide_less_eq)
  have rN0: "0 \<le> r / N" using r0 N0 by simp
  have uN: "N * u = N - r" proof -
    have "N * u = N * (1 - r / N)" using udef by simp
    also have "\<dots> = N - r" using N0 by (simp add: right_diff_distrib')
    finally show ?thesis .
  qed
  have u0: "0 < u" using udef rN1 by linarith
  have u1: "u \<le> 1" using udef rN0 by linarith
  have Tr_ge: "N * u \<le> T * r" using uN Tlo by linarith
  have u2: "u^2 \<le> 1" proof -
    have "u^2 = u * u" by (simp add: power2_eq_square)
    also have "\<dots> \<le> 1 * 1" using u1 u0 by (intro mult_mono) auto
    finally show ?thesis by simp
  qed
  have u3: "u^3 \<le> u" proof -
    have "u^3 = u * u^2" by (simp add: power3_eq_cube power2_eq_square algebra_simps)
    also have "\<dots> \<le> u * 1" using u2 u0 by (intro mult_left_mono) auto
    finally show ?thesis by simp
  qed
  have k1: "u^3 * N \<le> T * r" proof -
    have "u^3 * N \<le> u * N" using u3 N0 by (intro mult_right_mono) auto
    also have "\<dots> = N * u" by (simp add: mult.commute)
    also have "\<dots> \<le> T * r" using Tr_ge by simp
    finally show ?thesis .
  qed
  have goal_eq: "4 * (1 - r / N) ^ 3 * (N * T) = 4 * u^3 * (N * T)" using udef by simp
  show ?thesis
  proof (cases "x \<le> pi / 2")
    case True
    have J: "2 / pi * x \<le> sin x" using shor_jordan[OF less_imp_le[OF x0] True] by simp
    have step1: "T * (2 / pi * x) \<le> T * sin x" using J T0 by (intro mult_left_mono) (auto simp: less_imp_le[OF T0])
    have step2: "(2 * T / pi) * x \<le> P * x" proof -
      have "(2 * T / pi) * x = T * (2 / pi * x)" by (simp add: algebra_simps)
      also have "\<dots> \<le> T * sin x" using step1 by simp
      also have "\<dots> \<le> P * x" using H1 by simp
      finally show ?thesis .
    qed
    have step3: "2 * T / pi \<le> P" using step2 x0 by (simp only: mult_le_cancel_right_pos)
    have PT: "2 * T \<le> P * pi" proof -
      have "2 * T = (2 * T / pi) * pi" using pine by simp
      also have "\<dots> \<le> P * pi" using step3 pi0 by (intro mult_right_mono) auto
      finally show ?thesis .
    qed
    have sq': "(2 * T)^2 \<le> (P * pi)^2" using PT T0 by (intro power_mono) (auto simp: less_imp_le[OF T0])
    have sq: "4 * T^2 \<le> P^2 * pi^2" using sq' by (simp add: power_mult_distrib)
    have s2: "4 * T^2 * r \<le> P^2 * pi^2 * r" using sq r0 by (intro mult_right_mono) (auto simp: less_imp_le[OF r0])
    have k2: "u^3 * N * T \<le> T * r * T" using k1 T0 by (intro mult_right_mono) (auto simp: less_imp_le[OF T0])
    have "4 * u^3 * (N * T) \<le> 4 * T^2 * r" proof -
      have "4 * u^3 * (N * T) = 4 * (u^3 * N * T)" by (simp add: algebra_simps)
      also have "\<dots> \<le> 4 * (T * r * T)" using k2 by simp
      also have "\<dots> = 4 * T^2 * r" by (simp add: power2_eq_square algebra_simps)
      finally show ?thesis .
    qed
    also have "\<dots> \<le> P^2 * pi^2 * r" using s2 by simp
    finally have ch: "4 * u^3 * (N * T) \<le> P^2 * pi^2 * r" .
    have fin: "P^2 * (pi^2 * r) = P^2 * pi^2 * r" by (simp add: mult.assoc)
    show ?thesis using ch fin goal_eq by linarith
  next
    case False
    have xgt: "pi / 2 < x" using False by simp
    have hTr: "0 < T * r" using T0 r0 by simp
    have Nne: "N \<noteq> 0" using N0 by simp
    have ex: "\<exists>s. T * r = s * N" using Nne by (intro exI[of _ "T * r / N"]) (simp add: field_simps)
    obtain s where hs: "T * r = s * N" using ex by blast
    have hs0: "0 * N < s * N" using hTr hs by (metis mult_zero_left)
    have s0: "0 < s" using hs0 N0 by (simp only: mult_less_cancel_right_pos)
    have uN': "u * N = N - r" using uN by (simp add: mult.commute)
    have e1: "(2 - u) * N = N + r" proof -
      have "(2 - u) * N = 2 * N - u * N" by (simp add: algebra_simps)
      then show ?thesis using uN' by linarith
    qed
    have s_hi: "s < 2 - u" proof -
      have "s * N < (2 - u) * N" using hs Thi e1 by linarith
      then show ?thesis using N0 by (simp only: mult_less_cancel_right_pos)
    qed
    have s_ge: "u \<le> s" proof -
      have "u * N \<le> s * N" using Tr_ge hs mult.commute[of u N] by linarith
      then show ?thesis using N0 by (simp only: mult_le_cancel_right_pos)
    qed
    have us1: "u * s \<le> 1" proof -
      have "u * s \<le> u * (2 - u)" using s_hi u0 by (intro mult_left_mono) auto
      moreover have "u * (2 - u) = 1 - (1 - u)^2" by (simp add: algebra_simps power2_eq_square)
      moreover have "0 \<le> (1 - u)^2" by simp
      ultimately show ?thesis by linarith
    qed
    have e2: "pi * T * r = N * (pi * s)" proof -
      have "pi * T * r = pi * (T * r)" by (simp add: algebra_simps)
      also have "\<dots> = pi * (s * N)" using hs by simp
      also have "\<dots> = N * (pi * s)" by (simp add: algebra_simps)
      finally show ?thesis .
    qed
    have hxs: "2 * x \<le> pi * s" proof -
      have "N * (2 * x) \<le> N * (pi * s)" proof -
        have "N * (2 * x) = 2 * N * x" by (simp add: algebra_simps)
        also have "\<dots> \<le> pi * T * r" using x_le .
        also have "\<dots> = N * (pi * s)" using e2 .
        finally show ?thesis .
      qed
      then show ?thesis using N0 by (simp only: mult_le_cancel_left_pos)
    qed
    have y0: "0 \<le> pi - x" using xpi by linarith
    have y1: "pi - x \<le> pi / 2" using xgt by linarith
    have Jy: "2 / pi * (pi - x) \<le> sin (pi - x)" using shor_jordan[OF y0 y1] .
    have sinx_ge: "2 - s \<le> sin x" proof -
      have sp: "sin (pi - x) = sin x" by simp
      have eq2: "2 / pi * (pi - x) = 2 - 2 * x / pi" using pine by (simp add: field_simps)
      have "2 * x / pi \<le> s" proof -
        have "2 * x \<le> s * pi" using hxs mult.commute[of pi s] by linarith
        then show ?thesis using pi0 by (simp add: pos_divide_le_eq)
      qed
      then show ?thesis using Jy sp eq2 by linarith
    qed
    have E1: "2 * T * (2 - s) \<le> P * (pi * s)" proof -
      have "T * (2 - s) \<le> T * sin x" using sinx_ge T0 by (intro mult_left_mono) (auto simp: less_imp_le[OF T0])
      also have "\<dots> \<le> P * x" using H1 .
      finally have h1: "T * (2 - s) \<le> P * x" .
      have "P * (2 * x) \<le> P * (pi * s)" using hxs P0 by (intro mult_left_mono) auto
      then show ?thesis using h1 by (simp add: algebra_simps)
    qed
    have h2s: "0 \<le> 2 - s" using s_hi u0 by linarith
    have hA: "0 \<le> 2 * T * (2 - s)" using h2s T0 by (intro mult_nonneg_nonneg) auto
    have hB: "0 \<le> P * (pi * s)" using P0 pi0 s0 by (intro mult_nonneg_nonneg) auto
    have E2: "(2 * T * (2 - s)) * (2 * T * (2 - s)) \<le> (P * (pi * s)) * (P * (pi * s))" using mult_mono[OF E1 E1 hB hA] .
    have E3: "u^3 * s \<le> (2 - s)^2" proof -
      have ule: "u \<le> 2 - s" using s_hi by linarith
      have "u^2 \<le> (2 - s)^2" using ule u0 by (intro power_mono) auto
      moreover have "u^3 * s \<le> u^2"
      proof -
        have "u^3 * s = u^2 * (u * s)" by (simp add: algebra_simps power2_eq_square power3_eq_cube)
        also have "\<dots> \<le> u^2 * 1" using us1 by (intro mult_left_mono) auto
        finally show ?thesis by simp
      qed
      ultimately show ?thesis by linarith
    qed
    have E4: "4 * T^2 * (u^3 * s) \<le> 4 * T^2 * (2 - s)^2" using E3 by (intro mult_left_mono) auto
    have E5: "4 * T^2 * u^3 \<le> P^2 * pi^2 * s" proof -
      have "s * (4 * T^2 * u^3) \<le> s * (P^2 * pi^2 * s)" proof -
        have "s * (4 * T^2 * u^3) = 4 * T^2 * (u^3 * s)" by (simp add: algebra_simps)
        also have "\<dots> \<le> 4 * T^2 * (2 - s)^2" using E4 .
        also have "\<dots> = (2 * T * (2 - s)) * (2 * T * (2 - s))" by (simp add: algebra_simps power2_eq_square)
        also have "\<dots> \<le> (P * (pi * s)) * (P * (pi * s))" using E2 .
        also have "\<dots> = s * (P^2 * pi^2 * s)" by (simp add: algebra_simps power2_eq_square)
        finally show ?thesis .
      qed
      then show ?thesis using s0 by (simp only: mult_le_cancel_left_pos)
    qed
    have F: "T * (4 * u^3 * (N * T)) \<le> T * (P^2 * (pi^2 * r))" proof -
      have "T * (4 * u^3 * (N * T)) = N * (4 * T^2 * u^3)" by (simp add: algebra_simps power2_eq_square)
      also have "\<dots> \<le> N * (P^2 * pi^2 * s)" using E5 N0 by (intro mult_left_mono) auto
      also have "\<dots> = T * (P^2 * (pi^2 * r))"
      proof -
        have "N * (P^2 * pi^2 * s) = P^2 * pi^2 * (s * N)" by (simp add: algebra_simps)
        also have "\<dots> = P^2 * pi^2 * (T * r)" using hs by simp
        also have "\<dots> = T * (P^2 * (pi^2 * r))" by (simp add: algebra_simps)
        finally show ?thesis .
      qed
      finally show ?thesis .
    qed
    have G: "4 * u^3 * (N * T) \<le> P^2 * (pi^2 * r)" using F T0 by (simp only: mult_le_cancel_left_pos)
    show ?thesis using G goal_eq by linarith
  qed
qed
lemma shor_cmod_cis_minus1: "cmod (cis a - 1) = 2 * \<bar>sin (a / 2)\<bar>"
proof -
  have ex: "\<exists>t. a = 2 * t" by (intro exI[of _ "a / 2"]) simp
  obtain t where a2: "a = 2 * t" using ex by blast
  have ht: "a / 2 = t" using a2 by simp
  have hc: "cos t ^ 2 = 1 - sin t ^ 2" using sin_cos_squared_add2 by (simp add: algebra_simps)
  have ca: "cos a = 1 - 2 * sin t ^ 2" proof -
    have "cos a = (cos t)^2 - (sin t)^2" by (simp add: a2 cos_double)
    then show ?thesis using hc by (simp add: algebra_simps)
  qed
  have sa: "sin a = 2 * sin t * cos t" by (simp add: a2 sin_double)
  have e1: "(sin a)^2 = 4 * (sin t)^2 * (1 - (sin t)^2)" proof -
    have "(sin a)^2 = 4 * (sin t)^2 * (cos t)^2" by (simp add: sa) (simp add: power_mult_distrib; algebra)
    then show ?thesis using hc by simp
  qed
  have e2: "(cos a - 1)^2 = 4 * (sin t)^4" by (simp only: ca) (simp add: power_mult_distrib; algebra)
  have sq: "(cmod (cis a - 1))^2 = (2 * sin t)^2" proof -
    have "(cmod (cis a - 1))^2 = (cos a - 1)^2 + (sin a)^2" by (simp add: cmod_power2 cis_def)
    also have "\<dots> = (2 * sin t)^2" by (simp only: e1 e2) (simp add: power_mult_distrib; algebra)
    finally show ?thesis .
  qed
  have "cmod (cis a - 1) = \<bar>2 * sin t\<bar>"
  proof (rule power2_eq_imp_eq)
    show "(cmod (cis a - 1))^2 = (\<bar>2 * sin t\<bar>)^2" using sq by simp
    show "0 \<le> cmod (cis a - 1)" by simp
    show "0 \<le> \<bar>2 * sin t\<bar>" by simp
  qed
  then show ?thesis using ht by (simp add: abs_mult)
qed
lemma shor_geom_mul: "(\<Sum>t<T. w^t) * (w - 1) = w^T - 1"
  for w :: complex
proof (induction T)
  case 0 then show ?case by simp
next
  case (Suc T)
  have "(\<Sum>t<Suc T. w^t) = (\<Sum>t<T. w^t) + w^T" by (simp add: lessThan_Suc)
  then have "(\<Sum>t<Suc T. w^t) * (w - 1) = (\<Sum>t<T. w^t) * (w - 1) + w^T * (w - 1)" by (simp add: algebra_simps)
  also have "\<dots> = w^Suc T - 1" using Suc by (simp add: algebra_simps)
  finally show ?case .
qed
lemma shor_cis_pow: "(cis a)^t = cis (real t * a)"
proof (induction t)
  case 0 then show ?case by simp
next
  case (Suc t)
  have "(cis a)^(Suc t) = cis (real t * a) * cis a" using Suc by (simp add: algebra_simps)
  also have "\<dots> = cis (real t * a + a)" by (simp add: cis_mult)
  also have "\<dots> = cis (real (Suc t) * a)" by (simp add: algebra_simps)
  finally show ?case .
qed
lemma shor_dirichlet: "cmod (\<Sum>t<T. cis (real t * a)) * \<bar>sin (a / 2)\<bar> = \<bar>sin (real T * a / 2)\<bar>"
proof -
  have geo: "(\<Sum>t<T. cis (real t * a)) * (cis a - 1) = cis (real T * a) - 1" proof -
    have "(\<Sum>t<T. cis (real t * a)) = (\<Sum>t<T. (cis a)^t)" by (simp add: shor_cis_pow)
    then have "(\<Sum>t<T. cis (real t * a)) * (cis a - 1) = (\<Sum>t<T. (cis a)^t) * (cis a - 1)" by simp
    also have "\<dots> = (cis a)^T - 1" using shor_geom_mul[of "cis a" T] by simp
    also have "\<dots> = cis (real T * a) - 1" by (simp add: shor_cis_pow)
    finally show ?thesis .
  qed
  have "cmod ((\<Sum>t<T. cis (real t * a)) * (cis a - 1)) = cmod (cis (real T * a) - 1)" using geo by simp
  then have "cmod (\<Sum>t<T. cis (real t * a)) * cmod (cis a - 1) = cmod (cis (real T * a) - 1)" by (simp add: norm_mult)
  then have "cmod (\<Sum>t<T. cis (real t * a)) * (2 * \<bar>sin (a / 2)\<bar>) = 2 * \<bar>sin (real T * a / 2)\<bar>" using shor_cmod_cis_minus1[of a] shor_cmod_cis_minus1[of "real T * a"] by simp
  then show ?thesis by (simp add: algebra_simps)
qed
lemma shor_support:
  fixes N r x0 :: nat
  assumes r: "0 < r" and x0: "x0 < r" and rN: "r < N"
  shows "\<exists>T. 0 < T \<and> N \<le> x0 + r * T \<and> x0 + r * T < N + r \<and>
    {i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<T}"
proof -
  have ex0: "\<exists>t. N \<le> x0 + r * t" proof -
    have "1 * N \<le> r * N" using r by (intro mult_right_mono) auto
    then have "N \<le> r * N" by simp
    then show ?thesis by (intro exI[of _ N]) (use \<open>N \<le> r * N\<close> in linarith)
  qed
  have ex: "\<exists>T. \<forall>t. (x0 + r * t < N) = (t < T)" proof -
    let ?P = "\<lambda>t. N \<le> x0 + r * t"
    let ?T = "Least ?P"
    have PT: "?P ?T" using LeastI_ex[OF ex0] by simp
    have "\<forall>t. (x0 + r * t < N) = (t < ?T)"
    proof (intro allI)
      fix t
      show "(x0 + r * t < N) = (t < ?T)"
      proof
        assume lt: "x0 + r * t < N"
        show "t < ?T"
        proof (rule ccontr)
          assume "\<not> t < ?T"
          then have "?T \<le> t" by simp
          then have "r * ?T \<le> r * t" by (intro mult_left_mono) auto
          then have "N \<le> x0 + r * t" using PT by linarith
          then show False using lt by simp
        qed
      next
        assume "t < ?T"
        then have "\<not> ?P t" by (rule not_less_Least)
        then show "x0 + r * t < N" by simp
      qed
    qed
    then show ?thesis by blast
  qed
  then obtain T where hT: "\<forall>t. (x0 + r * t < N) = (t < T)" by blast
  have T0: "0 < T" proof -
    have "x0 + r * 0 < N" using x0 rN by simp
    then show ?thesis using hT[rule_format, of 0] by simp
  qed
  have TN: "N \<le> x0 + r * T" proof -
    have "\<not> (x0 + r * T < N)" using hT[rule_format, of T] by simp
    then show ?thesis by simp
  qed
  have Tr: "x0 + r * T < N + r" proof -
    obtain T' where hT': "T = Suc T'" using T0 by (cases T) auto
    have "x0 + r * T' < N" using hT[rule_format, of T'] hT' by simp
    moreover have "x0 + r * T = (x0 + r * T') + r" using hT' by (simp add: algebra_simps)
    ultimately show ?thesis by linarith
  qed
  have S: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<T}"
  proof (intro set_eqI iffI)
    fix i
    assume hi: "i \<in> {i. i < N \<and> i mod r = x0}"
    then have iN: "i < N" and imod: "i mod r = x0" by auto
    have eq: "x0 + r * (i div r) = i" proof -
      have "i div r * r + i mod r = i" by (rule div_mult_mod_eq)
      then show ?thesis using imod by (simp add: algebra_simps mult.commute)
    qed
    have "i div r < T" using hT[rule_format, of "i div r"] iN eq by simp
    then show "i \<in> (\<lambda>t. x0 + r * t) ` {..<T}" using eq by (intro image_eqI[of _ _ "i div r"]) auto
  next
    fix i
    assume "i \<in> (\<lambda>t. x0 + r * t) ` {..<T}"
    then obtain t where ht: "t < T" and ieq: "i = x0 + r * t" by auto
    have iN: "i < N" using hT[rule_format, of t] ht ieq by simp
    have "i mod r = x0" proof -
      have "(x0 + r * t) mod r = x0 mod r" by (simp add: mod_mult_self2)
      then show ?thesis using x0 ieq by simp
    qed
    then show "i \<in> {i. i < N \<and> i mod r = x0}" using iN by simp
  qed
  show ?thesis using T0 TN Tr S by blast
qed
lemma shor_sum_support:
  fixes f :: "nat \<Rightarrow> complex" and d :: complex and N r x0 T :: nat
  assumes hS: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<T}" and rpos: "0 < r"
  shows "(\<Sum>k<N. f k * (if k \<in> {i. i < N \<and> i mod r = x0} then d else 0)) = d * (\<Sum>t<T. f (x0 + r * t))"
proof -
  have inj: "inj_on (\<lambda>t. x0 + r * t) {..<T}"
  proof (rule inj_onI)
    fix a b assume "a \<in> {..<T}" "b \<in> {..<T}" "x0 + r * a = x0 + r * b"
    then show "a = b" using rpos by simp
  qed
  have sub: "{..<N} \<inter> {i. i < N \<and> i mod r = x0} = {i. i < N \<and> i mod r = x0}" by auto
  have "(\<Sum>k<N. f k * (if k \<in> {i. i < N \<and> i mod r = x0} then d else 0))
      = (\<Sum>k<N. if k \<in> {i. i < N \<and> i mod r = x0} then f k * d else 0)" by (intro sum.cong) auto
  also have "\<dots> = (\<Sum>k \<in> {..<N} \<inter> {i. i < N \<and> i mod r = x0}. f k * d)" by (subst sum.inter_restrict[of "{..<N}" "\<lambda>k. f k * d" "{i. i < N \<and> i mod r = x0}"]) auto
  also have "\<dots> = (\<Sum>k \<in> (\<lambda>t. x0 + r * t) ` {..<T}. f k * d)" using sub hS by simp
  also have "\<dots> = (\<Sum>t<T. f (x0 + r * t) * d)" using inj by (subst sum.reindex[OF inj]) (simp add: comp_def)
  also have "\<dots> = d * (\<Sum>t<T. f (x0 + r * t))" by (simp add: sum_distrib_left mult.commute)
  finally show ?thesis .
qed
lemma shor_cis_split:
  fixes j x0 r N t :: nat and c :: int
  assumes N0: "0 < N"
  shows "cis (2 * pi * real j * real (x0 + r * t) / real N) = cis (2 * pi * real j * real x0 / real N) * cis (real t * (2 * pi * (real j * real r / real N - real_of_int c)))"
proof -
  have Nne: "real N \<noteq> 0" using N0 by simp
  have n_int: "real_of_int (c * int t) \<in> \<int>" by simp
  have h2: "cis (2 * pi * real_of_int (c * int t)) = 1" using n_int by (simp add: cis_multiple_2pi)
  have arg: "2 * pi * real j * real (x0 + r * t) / real N = ((2 * pi * real j * real x0 / real N) + (real t * (2 * pi * (real j * real r / real N - real_of_int c)))) + (2 * pi * real_of_int (c * int t))" proof -
    have "2 * pi * real j * real (x0 + r * t) / real N = 2 * pi * real j * real x0 / real N + 2 * pi * (real j * real r / real N) * real t" by (simp add: field_simps add_divide_distrib)
    also have "\<dots> = ((2 * pi * real j * real x0 / real N) + (real t * (2 * pi * (real j * real r / real N - real_of_int c)))) + (2 * pi * real_of_int (c * int t))" by (simp add: algebra_simps)
    finally show ?thesis .
  qed
  have c1: "cis (2 * pi * real j * real (x0 + r * t) / real N) = cis ((2 * pi * real j * real x0 / real N) + (real t * (2 * pi * (real j * real r / real N - real_of_int c)))) * cis (2 * pi * real_of_int (c * int t))" by (subst arg) (rule cis_mult[symmetric])
  show ?thesis using c1 h2 by (simp add: cis_mult[symmetric])
qed
lemma shor_abs_sin_sym: "\<bar>sin (pi * y)\<bar> = \<bar>sin (pi * \<bar>y\<bar>)\<bar>"
proof (cases "0 \<le> y")
  case True then show ?thesis by simp
next
  case False
  then have "y < 0" by simp
  have "sin (pi * y) = - sin (pi * (-y))" by (simp add: sin_minus)
  then show ?thesis using \<open>y < 0\<close> by simp
qed
theorem shor_factor:
  assumes n: "1 < n" and ord: "is_order n a r" and even: "even r"
    and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
proof -
  have r_pos: "0 < r" using ord unfolding is_order_def by simp
  have ord_r: "a ^ r mod n = 1" and minimal: "\<And>j. 0 < j \<Longrightarrow> j < r \<Longrightarrow> a ^ j mod n \<noteq> 1" using ord unfolding is_order_def by auto
  obtain k where rk: "r = 2 * k" using even by (rule evenE)
  have hd: "r div 2 = k" using rk by simp
  have k_pos: "0 < k" using r_pos rk by simp
  have k_lt: "k < r" using r_pos rk by simp
  obtain x where hx: "x = a ^ k" by blast
  have sq: "x ^ 2 mod n = 1" using ord_r rk hx by (simp add: power_mult [symmetric] mult.commute)
  have x_ne1: "x mod n \<noteq> 1" using minimal[OF k_pos k_lt] hx by simp
  have x_ne_m1: "x mod n \<noteq> n - 1" using not_minus_one hd hx by simp
  have x_pos: "1 \<le> x"
  proof (rule ccontr)
    assume "\<not> 1 \<le> x"
    then have "x = 0" by simp
    with sq n show False by simp
  qed
  obtain m where hm: "x = m + 1" using x_pos by (cases x) auto
  have x1: "x - 1 = m" using hm by simp
  have n_dvd: "n dvd m * (m + 2)" proof -
    have e: "(m + 1) ^ 2 mod n + (m + 1) ^ 2 div n * n = (m + 1) ^ 2" by (rule mod_div_mult_eq)
    have "(m + 1) ^ 2 mod n = 1" using sq hm by simp
    then have f1: "(m + 1) ^ 2 = 1 + (m + 1) ^ 2 div n * n" using e by simp
    have f2: "(m + 1) ^ 2 = m * (m + 2) + 1" by (simp add: algebra_simps power2_eq_square)
    have "m * (m + 2) = n * ((m + 1) ^ 2 div n)" using f1 f2 by (simp add: mult.commute)
    then show ?thesis by auto
  qed
  have gcd_le: "gcd m n \<le> n" using n by simp
  have no_cop: "\<And>q. m + 2 = n * q \<Longrightarrow> False" proof -
    fix q assume q: "m + 2 = n * q"
    have eq: "(x mod n + 1) + n * (x div n) = n * q" proof -
      have hxq: "x + 1 = n * q" using q hm by simp
      have e: "x mod n + n * (x div n) = x" by (simp add: mod_div_mult_eq mult.commute)
      show ?thesis using hxq e by linarith
    qed
    have h2: "n dvd (x mod n + 1) + n * (x div n)" unfolding eq by simp
    have h3: "n dvd n * (x div n)" by simp
    have h2': "n dvd x mod n + 1" using h2 h3 dvd_add_left_iff by blast
    have le: "n \<le> x mod n + 1" using h2' by (intro Nat.dvd_imp_le) simp_all
    have lt: "x mod n < n" using n by simp
    have "x mod n = n - 1" using le lt by linarith
    with x_ne_m1 show False by simp
  qed
  have a_eq: "a ^ (r div 2) = x" using hd hx by simp
  have g_pos: "gcd (x - 1) n \<noteq> 0" using n x1 by simp
  have g_ne1: "gcd (x - 1) n \<noteq> 1"
  proof
    assume g1: "gcd (x-1) n = 1"
    have g1': "gcd m n = 1" using g1 x1 by simp
    have cop: "coprime n m" using g1' unfolding coprime_iff_gcd_eq_1 by (simp add: gcd.commute)
    have "n dvd m + 2" using coprime_dvd_mult_right_iff[OF cop] n_dvd by blast
    then obtain q where q: "m + 2 = n * q" by blast
    show False by (rule no_cop[OF q])
  qed
  have g_lt: "gcd (x - 1) n < n"
  proof (rule ccontr)
    assume "\<not> gcd (x - 1) n < n"
    then have gm: "gcd m n = n" using gcd_le x1 by simp
    then have "n dvd m" using gcd_dvd1[of m n] by simp
    then obtain t where "m = n * t" by blast
    then have xt: "x = 1 + t * n" using hm by (simp add: mult.commute)
    have h1: "(1 + t * n) mod n = 1 mod n" by (rule mod_mult_self1)
    have h2: "1 mod n = 1" using n by (rule mod_less)
    have "x mod n = 1" by (simp only: xt h1 h2)
    with x_ne1 show False by simp
  qed
  have g_gt: "1 < gcd (x - 1) n" using g_pos g_ne1 by presburger
  show ?thesis using a_eq g_gt g_lt by simp
qed
theorem shor_peak:
  assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r" and j: "j < N"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "is_state N (periodic_state N r x0) \<and>
    4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
proof -
  have N0: "0 < N" using rN r by simp
  obtain T where T0: "0 < T" and TN: "N \<le> x0 + r * T" and Tr: "x0 + r * T < N + r" and hS: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<T}" using shor_support[OF r x0 rN] by blast
  have inj: "inj_on (\<lambda>t. x0 + r * t) {..<T}"
  proof (rule inj_onI)
    fix a b assume "a \<in> {..<T}" "b \<in> {..<T}" "x0 + r * a = x0 + r * b"
    then show "a = b" using r by simp
  qed
  have hcard: "card {i. i < N \<and> i mod r = x0} = T" by (simp add: hS card_image inj)
  have hpsi: "\<And>k. periodic_state N r x0 k =
    (if k \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / sqrt (real T)) else 0)" by (simp add: periodic_state_def hcard)
  have sqT2: "(1 / sqrt (real T)) * (1 / sqrt (real T)) = 1 / real T" proof -
    have "sqrt (real T) * sqrt (real T) = real T" using T0 by simp
    then show ?thesis by (simp add: field_simps)
  qed
  have sqC: "cnj (complex_of_real (1 / sqrt (real T))) * complex_of_real (1 / sqrt (real T)) = complex_of_real (1 / real T)" by (simp only: complex_cnj_complex_of_real of_real_mult[symmetric] sqT2)
  have psi_term: "\<And>i. cnj (periodic_state N r x0 i) * periodic_state N r x0 i =
    (if i \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / real T) else 0)"
  proof -
    fix i
    show "cnj (periodic_state N r x0 i) * periodic_state N r x0 i =
      (if i \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / real T) else 0)"
    proof (cases "i \<in> {i. i < N \<and> i mod r = x0}")
      case True
      have p1: "periodic_state N r x0 i = complex_of_real (1 / sqrt (real T))" using True by (simp add: hpsi)
      show ?thesis using p1 sqC True by (simp only: p1 sqC if_True)
    next
      case False
      then have no: "i \<notin> {i. i < N \<and> i mod r = x0}" using False by blast
      then have p0: "periodic_state N r x0 i = 0" by (simp only: hpsi if_not_P[OF no] if_False)
      show ?thesis by (simp only: p0 if_not_P[OF no] complex_cnj_zero mult_zero_left)
    qed
  qed
  have sub: "{..<N} \<inter> {i. i < N \<and> i mod r = x0} = {i. i < N \<and> i mod r = x0}" by auto
  have st: "is_state N (periodic_state N r x0)" proof -
    have "inner N (periodic_state N r x0) (periodic_state N r x0) =
      (\<Sum>i<N. if i \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / real T) else 0)" unfolding inner_def by (intro sum.cong refl ballI) (rule psi_term)
    also have "\<dots> = (\<Sum>i \<in> {..<N} \<inter> {i. i < N \<and> i mod r = x0}. complex_of_real (1 / real T))" by (subst sum.inter_restrict[of "{..<N}" "\<lambda>_. complex_of_real (1 / real T)" "{i. i < N \<and> i mod r = x0}"]) auto
    also have "\<dots> = (\<Sum>i \<in> {i. i < N \<and> i mod r = x0}. complex_of_real (1 / real T))" by (simp only: sub)
    also have "\<dots> = of_nat (card {i. i < N \<and> i mod r = x0}) * complex_of_real (1 / real T)" by (rule sum_constant)
    also have "\<dots> = 1" using T0 hcard by (simp add: field_simps)
    finally show ?thesis unfolding is_state_def by simp
  qed
  obtain \<delta> where \<delta>def: "\<delta> = real j * real r / real N - real_of_int c" by blast
  obtain \<psi>' where \<psi>def: "\<psi>' = 2 * pi * \<delta>" by blast
  obtain \<alpha> where \<alpha>def: "\<alpha> = 2 * pi * real j * real x0 / real N" by blast
  obtain Z where Zdef: "Z = (\<Sum>t<T. cis (real t * \<psi>'))" by blast
  have Fsum: "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k) =
    complex_of_real (1 / sqrt (real T)) * (cis \<alpha> * Z)"
  proof -
    have s1: "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k) =
      (\<Sum>k<N. cis (2 * pi * real j * real k / real N) * (if k \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / sqrt (real T)) else 0))" by (intro sum.cong refl) (simp add: hpsi)
    have sup: "(\<Sum>k<N. (\<lambda>k. cis (2 * pi * real j * real k / real N)) k * (if k \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / sqrt (real T)) else 0))
      = complex_of_real (1 / sqrt (real T)) * (\<Sum>t<T. (\<lambda>k. cis (2 * pi * real j * real k / real N)) (x0 + r * t))" by (rule shor_sum_support[OF hS r])
    have split: "\<And>t. cis (2 * pi * real j * real (x0 + r * t) / real N) = cis \<alpha> * cis (real t * \<psi>')" using shor_cis_split[OF N0] by (simp add: \<alpha>def \<psi>def \<delta>def)
    have "(\<Sum>t<T. cis (2 * pi * real j * real (x0 + r * t) / real N)) = (\<Sum>t<T. cis \<alpha> * cis (real t * \<psi>'))" using split by simp
    also have "\<dots> = cis \<alpha> * Z" by (simp add: Zdef sum_distrib_left)
    finally have s2: "(\<Sum>t<T. cis (2 * pi * real j * real (x0 + r * t) / real N)) = cis \<alpha> * Z" .
    show ?thesis using s1 sup s2 by (simp add: s2 mult.assoc)
  qed
  obtain FF where FFdef: "FF = (\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)" by blast
  have pos: "0 < 1 / sqrt (real T)" using T0 by simp
  have sposN: "0 < sqrt (real N)" using N0 by simp
  have eF: "FF = complex_of_real (1 / sqrt (real T)) * (cis \<alpha> * Z)" by (rule trans[OF FFdef Fsum])
  have nF: "cmod FF = (1 / sqrt (real T)) * cmod Z" by (simp only: eF norm_mult norm_of_real abs_of_pos[OF pos] norm_cis mult_1)
  have qdef: "qft N (periodic_state N r x0) j = FF / complex_of_real (sqrt (real N))" by (simp add: qft_def FFdef)
  have prob_eq: "prob (qft N (periodic_state N r x0)) j = (cmod Z)^2 / (real T * real N)" proof -
    have amp: "cmod (qft N (periodic_state N r x0) j) = (1 / sqrt (real T)) * cmod Z / sqrt (real N)" by (simp only: qdef norm_divide norm_of_real abs_of_pos[OF sposN] nF)
    show ?thesis unfolding prob_def amp using T0 N0 by (simp add: power_divide power_mult_distrib field_simps)
  qed
  have TNr: "real N \<le> real x0 + real r * real T" using TN by (metis of_nat_add of_nat_le_iff of_nat_mult)
  have TrR: "real x0 + real r * real T < real N + real r" using Tr by (metis of_nat_add of_nat_less_iff of_nat_mult)
  have x0R: "real x0 < real r" using x0 by simp
  have x0nn: "0 \<le> real x0" by simp
  have rR: "0 < real r" using r by simp
  have NR: "0 < real N" using N0 by simp
  have rNR: "real r < real N" using rN by simp
  have TR: "0 < real T" using T0 by simp
  have TloR: "real N - real r \<le> real T * real r" using TNr x0R mult.commute[of "real T" "real r"] by linarith
  have ThiR: "real T * real r < real N + real r" using TrR x0nn mult.commute[of "real T" "real r"] by linarith
  have NneR: "real N \<noteq> 0" using NR by simp
  have nearR: "2 * \<bar>real j * real r - real_of_int c * real N\<bar> \<le> real r" proof -
    have h2e: "\<bar>2 * (int j * int r - c * int N)\<bar> = 2 * \<bar>int j * int r - c * int N\<bar>" by (simp only: abs_mult abs_numeral)
    have h2: "\<bar>2 * (int j * int r - c * int N)\<bar> \<le> int r" using near h2e by linarith
    have nearI: "2 * (int j * int r - c * int N) \<le> int r \<and> -(2 * (int j * int r - c * int N)) \<le> int r" using h2 by (simp only: abs_le_iff)
    have n1: "2 * (int j * int r - c * int N) \<le> int r" using nearI by blast
    have n2: "-(2 * (int j * int r - c * int N)) \<le> int r" using nearI by blast
    obtain Y where Ydef: "Y = real j * real r - real_of_int c * real N" by blast
    have A1: "(real_of_int (2 * (int j * int r - c * int N)) :: real) \<le> real_of_int (int r)" by (rule of_int_le_iff[THEN iffD2, OF n1])
    have A2: "(real_of_int (-(2 * (int j * int r - c * int N))) :: real) \<le> real_of_int (int r)" by (rule of_int_le_iff[THEN iffD2, OF n2])
    have e1: "(real_of_int (2 * (int j * int r - c * int N)) :: real) = 2 * Y" by (simp add: Ydef algebra_simps)
    have e2: "(real_of_int (-(2 * (int j * int r - c * int N))) :: real) = -(2 * Y)" by (simp add: Ydef algebra_simps)
    have e3: "(real_of_int (int r) :: real) = real r" by simp
    have R1: "2 * Y \<le> real r" using A1 e1 e3 by linarith
    have R2: "-(2 * Y) \<le> real r" using A2 e2 e3 by linarith
    have h1: "Y \<le> real r / 2" using R1 by linarith
    have h2: "-Y \<le> real r / 2" using R2 by linarith
    have hY: "\<bar>Y\<bar> \<le> real r / 2" using abs_le_iff[THEN iffD2, OF conjI[OF h1 h2]] by simp
    show ?thesis using hY Ydef by simp
  qed
  have zero_or_not: "\<delta> = 0 \<or> \<delta> \<noteq> 0" by blast
  have bound: "4 * (1 - real r / real N) ^ 3 * (real N * real T) \<le> (cmod Z)^2 * (pi^2 * real r)"
  proof (cases "\<delta> = 0")
    case True
    have psi0: "\<psi>' = 0" using \<psi>def True by simp
    have Zval: "cmod Z = real T" using Zdef psi0 by simp
    have pi2: "4 \<le> pi^2" proof -
      have h4: "(2::real)^2 \<le> pi^2" using pi_ge_two by (intro power_mono) auto
      show ?thesis using h4 by simp
    qed
    have u0: "0 < 1 - real r / real N" using rNR NR by (simp add: field_simps)
    have u1: "1 - real r / real N \<le> 1" using NR rR by (simp add: field_simps)
    have uN: "real N * (1 - real r / real N) = real N - real r" using NneR by (simp add: field_simps)
    have k1: "(1 - real r / real N)^3 * real N \<le> real T * real r" proof -
      have u2: "(1 - real r / real N)^2 \<le> 1" proof -
        have "(1 - real r / real N)^2 = (1 - real r / real N) * (1 - real r / real N)" by (simp add: power2_eq_square)
        also have "\<dots> \<le> 1 * 1" using u0 u1 by (intro mult_mono) auto
        finally show ?thesis by simp
      qed
      have "(1 - real r / real N)^3 \<le> (1 - real r / real N)" proof -
        have "(1 - real r / real N)^3 = (1 - real r / real N) * (1 - real r / real N)^2" by (simp add: power2_eq_square power3_eq_cube algebra_simps)
        also have "\<dots> \<le> (1 - real r / real N) * 1" using mult_left_mono[OF u2 less_imp_le[OF u0]] .
        finally show ?thesis by simp
      qed
      then have "(1 - real r / real N)^3 * real N \<le> (1 - real r / real N) * real N" using NR by (intro mult_right_mono) auto
      also have "\<dots> = real N * (1 - real r / real N)" by (simp add: mult.commute)
      also have "\<dots> = real N - real r" using uN by simp
      also have "\<dots> \<le> real T * real r" using TloR by simp
      finally show ?thesis .
    qed
    have k2: "4 * (1 - real r / real N)^3 * (real N * real T) \<le> 4 * real T^2 * real r" proof -
      have "(1 - real r / real N)^3 * real N * real T \<le> real T * real r * real T" using k1 TR by (intro mult_right_mono) (auto simp: less_imp_le)
      then show ?thesis by (simp add: algebra_simps power2_eq_square)
    qed
    have k3: "4 * real T^2 * real r \<le> pi^2 * real T^2 * real r" proof -
      have "4 * real T^2 * real r = 4 * (real T^2 * real r)" by (simp add: algebra_simps)
      also have "\<dots> \<le> pi^2 * (real T^2 * real r)" using pi2 by (intro mult_right_mono) auto
      finally show ?thesis by (simp add: algebra_simps)
    qed
    show ?thesis using k2 k3 Zval by (simp add: algebra_simps power2_eq_square)
  next
    case False
    have d0: "0 < \<bar>\<delta>\<bar>" using False by simp
    have hdN: "\<delta> * real N = real j * real r - real_of_int c * real N" using NneR by (simp add: \<delta>def field_simps)
    have dN: "2 * real N * \<bar>\<delta>\<bar> \<le> real r" proof -
      have dNabs: "\<bar>\<delta>\<bar> * real N = \<bar>\<delta> * real N\<bar>" by (simp add: abs_mult abs_of_pos[OF NR])
      have e4: "\<bar>\<delta>\<bar> * real N = \<bar>real j * real r - real_of_int c * real N\<bar>" using dNabs hdN by simp
      have e5: "2 * real N * \<bar>\<delta>\<bar> = 2 * (\<bar>\<delta>\<bar> * real N)" by (simp add: algebra_simps)
      show ?thesis by (simp only: e5 e4 nearR)
    qed
    have dir: "cmod Z * \<bar>sin (pi * \<delta>)\<bar> = \<bar>sin (pi * (real T * \<delta>))\<bar>" proof -
      have h1: "cmod Z * \<bar>sin (\<psi>' / 2)\<bar> = \<bar>sin (real T * \<psi>' / 2)\<bar>" using shor_dirichlet[of \<psi>' T] Zdef by simp
      have h2: "\<psi>' / 2 = pi * \<delta>" using \<psi>def by simp
      have h3: "real T * \<psi>' / 2 = pi * (real T * \<delta>)" using \<psi>def by (simp add: algebra_simps)
      show ?thesis using h1 h2 h3 by simp
    qed
    have rel: "cmod Z * \<bar>sin (pi * \<bar>\<delta>\<bar>)\<bar> = \<bar>sin (pi * real T * \<bar>\<delta>\<bar>)\<bar>" proof -
      have a1: "\<bar>sin (pi * \<delta>)\<bar> = \<bar>sin (pi * \<bar>\<delta>\<bar>)\<bar>" using shor_abs_sin_sym[of \<delta>] by simp
      have a2: "\<bar>sin (pi * (real T * \<delta>))\<bar> = \<bar>sin (pi * \<bar>real T * \<delta>\<bar>)\<bar>" using shor_abs_sin_sym[of "real T * \<delta>"] by simp
      have a3: "\<bar>real T * \<delta>\<bar> = real T * \<bar>\<delta>\<bar>" using TR by (simp add: abs_mult)
      show ?thesis using dir a1 a2 a3 by (simp add: mult.assoc)
    qed
    have P0: "0 \<le> cmod Z" by simp
    show ?thesis using shor_key_real[OF P0 d0 NR rR rNR TR TloR ThiR dN rel] .
  qed
  have final_ineq: "4 / (pi^2 * real r) * (1 - real r / real N)^3 \<le> (cmod Z)^2 / (real T * real N)" proof -
    have hb: "0 < pi^2 * real r" using rR by simp
    have hc: "0 < real T * real N" using TR NR by simp
    have eq1: "4 / (pi^2 * real r) * (1 - real r / real N)^3 = (4 * (1 - real r / real N)^3) / (pi^2 * real r)" by (simp add: field_simps)
    have "(4 * (1 - real r / real N)^3) * (real T * real N) \<le> (cmod Z)^2 * (pi^2 * real r)" using bound by (simp add: algebra_simps)
    then show ?thesis unfolding eq1 using hb hc by (simp add: field_simps)
  qed
  have pine: "4 / (pi^2 * real r) * (1 - real r / real N)^3 \<le> prob (qft N (periodic_state N r x0)) j" using final_ineq prob_eq by simp
  show ?thesis using st pine by blast
qed
lemma shor_s_near:
  fixes c r N :: nat
  assumes rpos: "0 < r"
  shows "2 * \<bar>int ((2*c*N + r) div (2*r)) * int r - int c * int N\<bar> \<le> int r"
proof -
  obtain q where qdef: "q = (2*c*N + r) div (2*r)" by blast
  obtain s where sdef: "s = (2*c*N + r) mod (2*r)" by blast
  have eq: "q * (2*r) + s = 2*c*N + r" using div_mult_mod_eq[of "2*c*N + r" "2*r"] qdef sdef by simp
  have slt: "s < 2*r" using sdef rpos by (simp add: mod_less_divisor)
  have e1: "int q * int r * 2 + int s = 2 * int c * int N + int r" using eq by (simp add: algebra_simps) (metis of_nat_add of_nat_mult of_nat_numeral)
  have s1: "int s < 2 * int r" using slt by (metis of_nat_less_iff of_nat_mult of_nat_numeral)
  have s0: "0 \<le> int s" by simp
  obtain X where Xdef: "X = int q * int r - int c * int N" by blast
  have hX1: "2 * X \<le> int r" using e1 s0 Xdef by (simp add: algebra_simps)
  have hX2: "- int r \<le> 2 * X" using e1 s1 Xdef by (simp add: algebra_simps)
  have key: "2 * \<bar>X\<bar> \<le> int r"
  proof (cases "X \<ge> 0")
    case True
    then have "\<bar>X\<bar> = X" by simp
    with hX1 show "2 * \<bar>X\<bar> \<le> int r" by linarith
  next
    case False
    then have "\<bar>X\<bar> = - X" by simp
    with hX2 show "2 * \<bar>X\<bar> \<le> int r" by linarith
  qed
  have XE: "X = int ((2*c*N + r) div (2*r)) * int r - int c * int N" using Xdef qdef by simp
  show ?thesis using key XE by metis
qed
lemma shor_s_inj:
  fixes N r c c' j :: nat
  assumes rpos: "0 < r" and rN: "r < N"
    and n1: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r" and n2: "2 * \<bar>int j * int r - int c' * int N\<bar> \<le> int r"
  shows "c = c'"
proof -
  obtain P1 where P1: "P1 = int j * int r - int c * int N" by blast
  obtain P2 where P2: "P2 = int j * int r - int c' * int N" by blast
  obtain D where D: "D = int c' - int c" by blast
  have ident: "int N * D = P1 - P2" unfolding P1 P2 D by (simp add: algebra_simps)
  have n1': "2 * \<bar>P1\<bar> \<le> int r" unfolding P1 by (rule n1)
  have n2': "2 * \<bar>P2\<bar> \<le> int r" unfolding P2 by (rule n2)
  have a1: "P1 \<le> \<bar>P1\<bar>" by simp
  have a2: "- P1 \<le> \<bar>P1\<bar>" by simp
  have a3: "P2 \<le> \<bar>P2\<bar>" by simp
  have a4: "- P2 \<le> \<bar>P2\<bar>" by simp
  have bD1: "int N * D \<le> int r" using ident a1 a2 a3 a4 n1' n2' by linarith
  have bD2: "- int r \<le> int N * D" using ident a1 a2 a3 a4 n1' n2' by linarith
  have rN_i: "int r < int N" using rN by simp
  have N0: "(0::int) \<le> int N" by simp
  have D0: "D = 0"
  proof (rule ccontr)
    assume "D \<noteq> 0"
    then consider (pos) "D \<ge> 1" | (neg) "D \<le> -1" by linarith
    then show False
    proof cases
      case pos
      then have "int N * 1 \<le> int N * D" using N0 by (intro mult_left_mono) auto
      with bD1 rN_i show False by linarith
    next
      case neg
      then have "int N * D \<le> int N * (-1)" using N0 by (intro mult_left_mono) auto
      with bD2 rN_i show False by linarith
    qed
  qed
  then show ?thesis using D by linarith
qed
lemma shor_s_recover:
  fixes N r c j :: nat
  assumes rpos: "0 < r" and rr: "r * r < N" and cr: "c < r" and cop: "coprime c r"
    and jdef: "j = (2*c*N + r) div (2*r)"
  shows "recover N j = r"
proof -
  have near_j: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r" using shor_s_near[OF rpos, of c N] jdef by simp
  have rN: "r < N" proof -
    have "r \<le> r * r" by (rule le_square)
    with rr show ?thesis by linarith
  qed
  have rr_i: "int r * int r < int N" using rr by (metis of_nat_less_iff of_nat_mult)
  have cop': "coprime r c" using cop by (simp add: coprime_commute)
  show ?thesis unfolding recover_def
  proof (rule Least_equality)
    show "0 < r \<and> (\<exists>a::int. 2 * \<bar>int j * int r - a * int N\<bar> \<le> int r)" using rpos near_j by blast
  next
    fix y assume hy: "0 < y \<and> (\<exists>a::int. 2 * \<bar>int j * int y - a * int N\<bar> \<le> int y)"
    then obtain a where ypos: "0 < y" and ha: "2 * \<bar>int j * int y - a * int N\<bar> \<le> int y" by blast
    show "r \<le> y"
    proof (rule ccontr)
      assume "\<not> r \<le> y"
      then have yr: "y < r" by simp
      have yr_i: "int y < int r" using yr by simp
      have y0: "(0::int) < int y" using ypos by simp
      have y0': "(0::int) \<le> int y" using y0 by simp
      have r0: "(0::int) < int r" using rpos by simp
      have r0': "(0::int) \<le> int r" using r0 by simp
      obtain P where P: "P = int j * int r - int c * int N" by blast
      obtain Q where Q: "Q = int j * int y - a * int N" by blast
      obtain X where Xdef: "X = int c * int y - a * int r" by blast
      have ident: "int N * X = - (int y * P) + int r * Q" unfolding P Q Xdef by (simp add: algebra_simps)
      have nP: "2 * \<bar>P\<bar> \<le> int r" unfolding P by (rule near_j)
      have nQ: "2 * \<bar>Q\<bar> \<le> int y" unfolding Q by (rule ha)
      have hP1: "- int r \<le> 2 * P" using nP abs_ge_minus_self[of P] by linarith
      have hP2: "2 * P \<le> int r" using nP abs_ge_self[of P] by linarith
      have hQ1: "- int y \<le> 2 * Q" using nQ abs_ge_minus_self[of Q] by linarith
      have hQ2: "2 * Q \<le> int y" using nQ abs_ge_self[of Q] by linarith
      have f1: "2 * (int y * P) \<le> int r * int y" proof -
        have "2 * (int y * P) = int y * (2 * P)" by (simp add: algebra_simps)
        also have "\<dots> \<le> int y * int r" using hP2 y0' by (intro mult_left_mono) auto
        also have "\<dots> = int r * int y" by (simp add: algebra_simps)
        finally show ?thesis .
      qed
      have f2: "- (int r * int y) \<le> 2 * (int y * P)" proof -
        have "- (int r * int y) = int y * (- int r)" by (simp add: algebra_simps)
        also have "\<dots> \<le> int y * (2 * P)" using hP1 y0' by (intro mult_left_mono) auto
        also have "\<dots> = 2 * (int y * P)" by (simp add: algebra_simps)
        finally show ?thesis .
      qed
      have f3: "2 * (int r * Q) \<le> int r * int y" proof -
        have "2 * (int r * Q) = int r * (2 * Q)" by (simp add: algebra_simps)
        also have "\<dots> \<le> int r * int y" using hQ2 r0' by (intro mult_left_mono) auto
        finally show ?thesis .
      qed
      have f4: "- (int r * int y) \<le> 2 * (int r * Q)" proof -
        have "- (int r * int y) = int r * (- int y)" by (simp add: algebra_simps)
        also have "\<dots> \<le> int r * (2 * Q)" using hQ1 r0' by (intro mult_left_mono) auto
        also have "\<dots> = 2 * (int r * Q)" by (simp add: algebra_simps)
        finally show ?thesis .
      qed
      have ry1: "int r * int y \<le> int r * int r" using yr_i r0' by (intro mult_left_mono) auto
      have ry: "int r * int y < int N" using ry1 rr_i by linarith
      have bnd1: "int N * X \<le> int r * int y" using ident f2 f3 by linarith
      have bnd2: "- (int r * int y) \<le> int N * X" using ident f1 f4 by linarith
      have N0: "(0::int) < int N" using rN by simp
      have X0: "X = 0"
      proof (rule ccontr)
        assume "X \<noteq> 0"
        then consider (pos) "X \<ge> 1" | (neg) "X \<le> -1" by linarith
        then show False
        proof cases
          case pos
          then have "int N * 1 \<le> int N * X" using N0 by (intro mult_left_mono) auto
          with bnd1 ry show False by linarith
        next
          case neg
          then have "int N * X \<le> int N * (-1)" using N0 by (intro mult_left_mono) auto
          with bnd2 ry show False by linarith
        qed
      qed
      have eq_int: "int c * int y = a * int r" using X0 Xdef by linarith
      have dvd_i: "int r dvd int (c * y)" by (rule dvdI[of _ _ a]) (use eq_int in \<open>simp add: mult.commute\<close>)
      have dvd_n: "r dvd c * y" using dvd_i by (simp only: int_dvd_int_iff)
      have "r dvd y" using dvd_n coprime_dvd_mult_right_iff[OF cop'] by blast
      then have "r \<le> y" using ypos by (intro Nat.dvd_imp_le) auto
      with yr show False by simp
    qed
  qed
qed
theorem shor_general_success:
  assumes r: "0 < r" and rr: "r * r < N" and x0: "x0 < r"
  shows "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
    \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
proof -
  have rN: "r < N" proof -
    have "r \<le> r * r" by (rule le_square)
    with rr show ?thesis by linarith
  qed
  let ?C = "{c. c < r \<and> coprime c r}"
  let ?T = "{j. j < N \<and> recover N j = r}"
  let ?jf = "\<lambda>c. (2 * c * N + r) div (2 * r)"
  let ?p = "\<lambda>j. prob (qft N (periodic_state N r x0)) j"
  let ?b = "4 / (pi^2 * real r) * (1 - real r / real N) ^ 3"
  have C_fin: "finite ?C" by (rule finite_subset[of _ "{..<r}"]) auto
  have T_sub: "?T \<subseteq> {..<N}" by auto
  have T_fin: "finite ?T" by (rule finite_subset[OF T_sub]) simp
  have jlt: "\<And>c. c < r \<Longrightarrow> ?jf c < N" proof -
    fix c assume cr: "c < r"
    have c1: "c + 1 \<le> r" using cr by simp
    have m1: "(c + 1) * (2 * N) \<le> r * (2 * N)" using c1 by (intro mult_right_mono) auto
    have e1: "(c + 1) * (2 * N) = 2 * c * N + 2 * N" by (simp add: algebra_simps)
    have e2: "r * (2 * N) = N * (2 * r)" by (simp add: algebra_simps)
    have lt: "2 * c * N + r < N * (2 * r)" using m1 e1 e2 rN by linarith
    show "?jf c < N" by (rule less_mult_imp_div_less) (use lt in \<open>simp add: algebra_simps\<close>)
  qed
  have jf_mem: "\<And>c. c \<in> ?C \<Longrightarrow> ?jf c \<in> ?T" proof -
    fix c assume hc: "c \<in> ?C"
    then have cr: "c < r" and cop: "coprime c r" by auto
    have "?jf c < N" using jlt cr by simp
    moreover have "recover N (?jf c) = r" using shor_s_recover[OF r rr cr cop] by simp
    ultimately show "?jf c \<in> ?T" by simp
  qed
  have jf_inj: "inj_on ?jf ?C"
  proof (rule inj_onI)
    fix c c' assume hc: "c \<in> ?C" and hc': "c' \<in> ?C" and heq: "?jf c = ?jf c'"
    have n1: "2 * \<bar>int (?jf c) * int r - int c * int N\<bar> \<le> int r" using shor_s_near[OF r, of c N] by simp
    have n2: "2 * \<bar>int (?jf c') * int r - int c' * int N\<bar> \<le> int r" using shor_s_near[OF r, of c' N] by simp
    have n1': "2 * \<bar>int (?jf c') * int r - int c * int N\<bar> \<le> int r" using n1 heq by simp
    show "c = c'" using shor_s_inj[OF r rN n1' n2] by simp
  qed
  have each: "\<And>c. c \<in> ?C \<Longrightarrow> ?b \<le> ?p (?jf c)" proof -
    fix c assume hc: "c \<in> ?C"
    then have cr: "c < r" and cop: "coprime c r" by auto
    have near: "2 * \<bar>int (?jf c) * int r - int c * int N\<bar> \<le> int r" using shor_s_near[OF r, of c N] by simp
    show "?b \<le> ?p (?jf c)" using shor_peak[OF r rN x0 _ near] jlt[OF cr] by blast
  qed
  have pnn: "\<And>j. 0 \<le> ?p j" by (simp add: prob_def)
  have s1: "(\<Sum>c \<in> ?C. ?b) \<le> (\<Sum>c \<in> ?C. ?p (?jf c))" by (rule sum_mono) (rule each)
  have s2: "(\<Sum>j \<in> ?jf ` ?C. ?p j) = (\<Sum>c \<in> ?C. ?p (?jf c))" by (subst sum.reindex[OF jf_inj]) (simp add: comp_def)
  have s3: "(\<Sum>j \<in> ?jf ` ?C. ?p j) \<le> (\<Sum>j \<in> ?T. ?p j)"
  proof (rule sum_mono2[OF T_fin])
    show "?jf ` ?C \<subseteq> ?T" using jf_mem by auto
    show "\<And>j. j \<in> ?T - ?jf ` ?C \<Longrightarrow> 0 \<le> ?p j" using pnn by simp
  qed
  have s4: "(\<Sum>c \<in> ?C. ?b) = real (card ?C) * ?b" by simp
  have pi0: "pi \<noteq> 0" by simp
  have r0: "real r \<noteq> 0" using r by simp
  have eq: "4 / pi\<^sup>2 * (real (card ?C) / real r) * (1 - real r / real N) ^ 3
      = real (card ?C) * ?b" using pi0 r0 by (simp add: field_simps)
  show ?thesis using eq s1 s2 s3 s4 by linarith
qed
end

