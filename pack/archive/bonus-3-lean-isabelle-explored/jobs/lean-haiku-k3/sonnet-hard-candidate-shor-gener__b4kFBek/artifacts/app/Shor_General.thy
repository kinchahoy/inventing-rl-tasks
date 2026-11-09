theory Shor_General
  imports Quantum_Basics
begin
lemma shor_gcd_ne_one:
  fixes m n :: nat
  assumes n: "1 < n" and mm: "(m * m) mod n = 1" and m1: "m mod n \<noteq> n - 1"
  shows "gcd (m - 1) n \<noteq> 1"
proof
  have m0: "m \<noteq> 0" proof
    assume "m = 0"
    then have "(m * m) mod n = 0" by simp
    with mm show False by simp
  qed
  have e1: "(m - 1) * (m + 1) + 1 = m * m" using m0 by (cases m) (auto simp: algebra_simps)
  have dm0: "m * m div n * n + 1 = m * m" using div_mult_mod_eq[of "m * m" n] mm by simp
  have prod: "(m - 1) * (m + 1) = m * m div n * n" using e1 dm0 by linarith
  have dv: "n dvd (m - 1) * (m + 1)"
    unfolding prod by simp
  assume g1: "gcd (m - 1) n = 1"
  have cop: "coprime n (m - 1)" using g1 by (simp add: coprime_iff_gcd_eq_1 gcd.commute)
  have dvn: "n dvd (m + 1)" using coprime_dvd_mult_right_iff[OF cop] dv by blast
  then obtain t where ht: "m + 1 = n * t" by (auto elim!: dvdE)
  have h2a: "(m + 1) mod n = 0" by (subst ht) simp
  have h2: "(m mod n + 1) mod n = 0" proof -
    have "(m mod n + 1) mod n = (m + 1) mod n" by (rule mod_add_left_eq)
    also have "\<dots> = 0" by (rule h2a)
    finally show ?thesis .
  qed
  have r0: "m mod n < n" using n by simp
  have h3: "m mod n + 1 = n" proof (rule ccontr)
    assume ne: "m mod n + 1 \<noteq> n"
    then have lt: "m mod n + 1 < n" using r0 by linarith
    have "(m mod n + 1) mod n = m mod n + 1" by (rule mod_less[OF lt])
    with h2 show False by simp
  qed
  have "m mod n = n - 1" using h3 by arith
  with m1 show False by simp
qed
lemma shor_one_mod:
  fixes m n :: nat
  assumes n: "1 < n" and m0: "m \<noteq> 0" and dv: "n dvd (m - 1)"
  shows "m mod n = 1"
proof -
  obtain s where hs: "m - 1 = n * s" using dv by (auto elim!: dvdE)
  have ms: "m = n * s + 1" using hs m0 by (cases m) auto
  have ms2: "m = 1 + s * n" using ms by (simp add: add.commute mult.commute)
  have "m mod n = (1 + s * n) mod n" using ms2 by (rule arg_cong)
  also have "\<dots> = 1 mod n" by (rule mod_mult_self1)
  also have "\<dots> = 1" using mod_less[OF n] by simp
  finally show ?thesis .
qed
theorem shor_factor:
  assumes n: "1 < n" and ord: "is_order n a r" and even: "even r"
    and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
proof -
  obtain k where hk: "r = 2 * k" using even by (auto elim: evenE)
  have hkk: "r = k + k" using hk by arith
  have hkd: "r div 2 = k" using hk by arith
  have rpos: "0 < r" using ord unfolding is_order_def by blast
  have k0: "0 < k" using rpos hkk by arith
  have kr: "k < r" using k0 hkk by arith
  have ord1: "a ^ r mod n = 1" using ord unfolding is_order_def by blast
  have ord2: "a ^ k mod n \<noteq> 1" using ord kr k0 unfolding is_order_def by blast
  have pw: "a ^ r = a ^ k * a ^ k" by (simp add: hkk power_add)
  have mm: "(a ^ k * a ^ k) mod n = 1" using ord1 pw by simp
  have nm1: "a ^ k mod n \<noteq> n - 1" using not_minus_one hkd by simp
  have g_ne1: "gcd (a ^ k - 1) n \<noteq> 1" using shor_gcd_ne_one[OF n mm nm1] by simp
  have m0: "a ^ k \<noteq> 0" proof
    assume "a ^ k = 0"
    then have "a ^ k * a ^ k = 0" by simp
    with mm show False by simp
  qed
  have dvd_nm: "\<not> n dvd (a ^ k - 1)" proof
    assume dv: "n dvd (a ^ k - 1)"
    have "a ^ k mod n = 1" using shor_one_mod[OF n m0 dv] .
    with ord2 show False by simp
  qed
  have gpos: "gcd (a ^ k - 1) n \<noteq> 0" using n by simp
  have gle: "gcd (a ^ k - 1) n \<le> n" using dvd_imp_le[OF gcd_dvd2[of "a ^ k - 1" n]] n by simp
  have gneq: "gcd (a ^ k - 1) n \<noteq> n" proof
    assume "gcd (a ^ k - 1) n = n"
    then have "n dvd (a ^ k - 1)" using gcd_dvd1[of "a ^ k - 1" n] by simp
    with dvd_nm show False by simp
  qed
  have goal': "1 < gcd (a ^ k - 1) n \<and> gcd (a ^ k - 1) n < n" using g_ne1 gpos gle gneq by linarith
  show ?thesis using goal' hkd by simp
qed
lemma cos_ge_1_sub:
  fixes u :: real
  assumes u: "0 \<le> u"
  shows "1 - u^2/2 \<le> cos u"
proof -
  let ?f = "\<lambda>x. cos x - 1 + x^2/2"
  have mono: "?f 0 \<le> ?f u" proof (rule DERIV_nonneg_imp_nondecreasing[OF u])
    fix x :: real assume x: "0 \<le> x" "x \<le> u"
    have d: "(?f has_real_derivative (- sin x + x)) (at x)" by (auto intro!: derivative_eq_intros simp: field_simps)
    have "0 \<le> - sin x + x" using sin_x_le_x[of x] x by linarith
    with d show "\<exists>y. (?f has_real_derivative y) (at x) \<and> 0 \<le> y" by blast
  qed
  show ?thesis using mono by simp
qed
lemma sin_ge_cubic:
  fixes s :: real
  assumes s: "0 \<le> s"
  shows "s - s^3/6 \<le> sin s"
proof -
  let ?g = "\<lambda>x. sin x - x + x^3/6"
  have mono: "?g 0 \<le> ?g s" proof (rule DERIV_nonneg_imp_nondecreasing[OF s])
    fix x :: real assume x: "0 \<le> x" "x \<le> s"
    have d: "(?g has_real_derivative (cos x - 1 + x^2/2)) (at x)" by (auto intro!: derivative_eq_intros simp: field_simps)
    have "0 \<le> cos x - 1 + x^2/2" using cos_ge_1_sub[of x] x by linarith
    with d show "\<exists>y. (?g has_real_derivative y) (at x) \<and> 0 \<le> y" by blast
  qed
  show ?thesis using mono by simp
qed
lemma pi_ge_three: "3 \<le> pi"
proof -
  have h: "sin (pi/6) = 1/2" by (rule sin_30)
  have "sin (pi/6) \<le> pi/6" using sin_x_le_x[of "pi/6"] pi_gt_zero by simp
  with h show ?thesis by linarith
qed
lemma jordan_sin:
  fixes t :: real
  assumes t0: "0 \<le> t" and t1: "t \<le> pi/2"
  shows "2 * t / pi \<le> sin t"
proof (cases "t \<le> 7/5")
  case True
  have pos: "0 < pi" by (rule pi_gt_zero)
  have s3: "t - t^3/6 \<le> sin t" using sin_ge_cubic[OF t0] by simp
  have a: "2 / pi \<le> 2/3" using pi_ge_three pos by (simp add: divide_le_eq field_simps)
  have e2: "2 * t / pi = t * (2 / pi)" by (simp add: field_simps)
  have b: "t * (2 / pi) \<le> t * (2/3)" using a t0 by (intro mult_left_mono) auto
  have tt: "t * t \<le> (7/5) * (7/5)" using True t0 by (intro mult_mono) auto
  have sqeq: "t^2 = t * t" by (simp add: power2_eq_square)
  have t2: "t^2 \<le> 2" using tt sqeq by linarith
  have t3: "t^3 \<le> 2 * t" proof -
    have "t^3 = t * t^2" by (simp add: power3_eq_cube power2_eq_square algebra_simps)
    also have "\<dots> \<le> t * 2" using t2 t0 by (intro mult_left_mono) auto
    finally show ?thesis by simp
  qed
  have c: "2/3 * t \<le> t - t^3/6" using t3 by linarith
  show ?thesis using s3 c b e2 by linarith
next
  case False
  define u where "u = pi/2 - t"
  have u0: "0 \<le> u" using t1 unfolding u_def by simp
  have pi4: "pi < 4" by (rule pi_less_4)
  have u06: "u \<le> 3/5" using False pi4 unfolding u_def by linarith
  have tu: "t = pi/2 - u" unfolding u_def by simp
  have sin_eq: "sin t = cos u" unfolding tu by (simp add: sin_diff)
  have c: "1 - u^2/2 \<le> cos u" using cos_ge_1_sub[OF u0] .
  have pos: "0 < pi" by (rule pi_gt_zero)
  have key: "2 * t / pi = 1 - 2 * u / pi" unfolding tu by (simp add: field_simps)
  have up0: "u * pi \<le> u * 4" using pi4 u0 by (intro mult_left_mono) auto
  have up: "u * pi \<le> 4" using up0 u06 u0 by linarith
  have "u^2/2 \<le> 2 * u / pi" proof -
    have "u^2/2 = u * (u / 2)" by (simp add: power2_eq_square)
    also have "\<dots> \<le> u * (2 / pi)"
    proof (intro mult_left_mono)
      show "u / 2 \<le> 2 / pi" using up pos by (simp add: divide_le_eq field_simps)
      show "0 \<le> u" using u0 .
    qed
    also have "\<dots> = 2 * u / pi" by (simp add: field_simps)
    finally show ?thesis .
  qed
  with c sin_eq key show ?thesis by linarith
qed
lemma jordan_sin_min:
  fixes t :: real
  assumes t0: "0 \<le> t" and t1: "t \<le> pi"
  shows "2 * min t (pi - t) / pi \<le> sin t"
proof (cases "t \<le> pi/2")
  case True
  then have "min t (pi - t) = t" by linarith
  then show ?thesis using jordan_sin[OF t0 True] by simp
next
  case False
  then have "min t (pi - t) = pi - t" by linarith
  moreover have "sin t = sin (pi - t)" by simp
  moreover have "2 * (pi - t) / pi \<le> sin (pi - t)" using jordan_sin[of "pi - t"] t1 False by linarith
  ultimately show ?thesis by simp
qed
lemma sine_key:
  fixes mu e t :: real
  assumes e0: "0 < e" and e1: "e < 1" and mu1: "1 - e \<le> mu" and mu2: "mu < 1 + e"
    and t0: "0 \<le> t" and t1: "t \<le> pi * mu / 2"
  shows "4 / pi^2 * (1 - e)^3 * t^2 \<le> mu * (sin t)^2"
proof -
  have pos: "0 < pi" by (rule pi_gt_zero)
  have mu0: "0 < mu" using mu1 e1 by linarith
  have mu2': "mu < 2" using mu2 e1 by linarith
  have mu0': "0 \<le> mu" using mu0 by simp
  have cube: "(1 - e)^3 \<le> mu" proof -
    have "(1 - e)^3 \<le> (1 - e)^1" using e0 e1 by (intro power_decreasing) auto
    then show ?thesis using mu1 by simp
  qed
  have ce: "0 \<le> (1 - e)^3" using e1 by simp
  have eq4: "4 / pi^2 * (1 - e)^3 * t^2 = (1 - e)^3 * (4 / pi^2 * t^2)" by (simp add: algebra_simps)
  have nn4: "0 \<le> 4 / pi^2 * t^2" by simp
  show ?thesis proof (cases "t \<le> pi/2")
    case True
    have hj: "2 * t / pi \<le> sin t" using jordan_sin[OF t0 True] .
    have nn: "0 \<le> 2 * t / pi" using t0 pos by (intro divide_nonneg_nonneg) auto
    have sq1: "(2 * t / pi)^2 \<le> (sin t)^2" using power_mono[OF hj nn] .
    have eq1: "(2 * t / pi)^2 = 4 / pi^2 * t^2" by (simp add: power_divide algebra_simps)
    have sq2: "4 / pi^2 * t^2 \<le> (sin t)^2" using sq1 eq1 by linarith
    have "(1 - e)^3 * (4 / pi^2 * t^2) \<le> mu * (sin t)^2" using mult_mono[OF cube sq2 mu0' nn4] .
    then show ?thesis using eq4 by linarith
  next
    case False
    define m where "m = pi - t"
    have tpi0: "pi * mu \<le> pi * 2" using mu2' pos by (intro mult_left_mono) auto
    have tpi: "t \<le> pi" using t1 tpi0 by linarith
    have m0: "0 \<le> m" using tpi unfolding m_def by linarith
    have sinm: "2 * m / pi \<le> sin t" proof -
      have "min t (pi - t) = m" unfolding m_def using False by linarith
      then show ?thesis using jordan_sin_min[OF t0 tpi] unfolding m_def by simp
    qed
    have nn: "0 \<le> 2 * m / pi" using m0 pos by (intro divide_nonneg_nonneg) auto
    have sq1: "(2 * m / pi)^2 \<le> (sin t)^2" using power_mono[OF sinm nn] .
    have eq1: "(2 * m / pi)^2 = 4 / pi^2 * m^2" by (simp add: power_divide algebra_simps)
    have sq2: "4 / pi^2 * m^2 \<le> (sin t)^2" using sq1 eq1 by linarith
    have pim: "2 * t \<le> pi * mu" using t1 by linarith
    have mm: "t * (2 - mu) \<le> mu * m" proof -
      have "mu * m = mu * pi - mu * t" unfolding m_def by (simp add: algebra_simps)
      moreover have "2 * t \<le> mu * pi" using pim by (simp add: algebra_simps)
      ultimately show ?thesis by (simp add: algebra_simps)
    qed
    have a0: "0 \<le> t * (2 - mu)" using t0 mu2' by (intro mult_nonneg_nonneg) auto
    have sq3: "(t * (2 - mu))^2 \<le> (mu * m)^2" using power_mono[OF mm a0] .
    have bnd0: "1 - e \<le> 2 - mu" using mu2 by linarith
    have bnd1: "(1 - e)^2 \<le> (2 - mu)^2" using bnd0 e1 by (intro power_mono) auto
    have bnd2: "mu * (1 - e) \<le> (1 + e) * (1 - e)" using mu2 e1 by (intro mult_right_mono) auto
    have bnd2': "(1 + e) * (1 - e) = 1 - e^2" by (simp add: algebra_simps power2_eq_square)
    have esq: "0 \<le> e^2" by simp
    have bnd2'': "mu * (1 - e) \<le> 1" using bnd2 bnd2' esq by linarith
    have bnd3: "mu * (1 - e)^3 \<le> (1 - e)^2" proof -
      have "mu * (1 - e)^3 = (mu * (1 - e)) * (1 - e)^2" by (simp add: power3_eq_cube power2_eq_square algebra_simps)
      also have "\<dots> \<le> 1 * (1 - e)^2" using bnd2'' by (intro mult_right_mono) auto
      finally show ?thesis by simp
    qed
    have bnd: "mu * (1 - e)^3 \<le> (2 - mu)^2" using bnd3 bnd1 by linarith
    have t2: "0 \<le> t^2" by simp
    have h1: "mu * (1 - e)^3 * t^2 \<le> (2 - mu)^2 * t^2" using mult_right_mono[OF bnd t2] .
    have e3: "mu * ((1 - e)^3 * t^2) = mu * (1 - e)^3 * t^2" by (simp add: power2_eq_square algebra_simps)
    have e5: "(t * (2 - mu))^2 = (2 - mu)^2 * t^2" by (simp add: power2_eq_square algebra_simps)
    have e6: "(mu * m)^2 = mu * (mu * m^2)" by (simp add: power2_eq_square algebra_simps)
    have h2: "mu * ((1 - e)^3 * t^2) \<le> mu * (mu * m^2)" using h1 sq3 e3 e5 e6 by linarith
    have main: "(1 - e)^3 * t^2 \<le> mu * m^2" using h2 mu0 mult_le_cancel_left_pos by blast
    have "4 / pi^2 * ((1 - e)^3 * t^2) \<le> 4 / pi^2 * (mu * m^2)" using main by (intro mult_left_mono) auto
    moreover have "4 / pi^2 * (mu * m^2) = mu * (4 / pi^2 * m^2)" by (simp add: algebra_simps)
    moreover have "mu * (4 / pi^2 * m^2) \<le> mu * (sin t)^2" using sq2 mu0 by (intro mult_left_mono) auto
    ultimately show ?thesis using eq4 by linarith
  qed
qed
definition kc :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "kc N r x0 = (N - x0 - 1) div r + 1"
lemma kc_set:
  assumes r: "0 < r" and x0: "x0 < r" and xN: "x0 < N"
  shows "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<kc N r x0}"
proof -
  obtain A where hA: "A = N - x0 - 1" by blast
  have hNA: "N = A + x0 + 1" using xN hA by arith
  have hK: "kc N r x0 = A div r + 1" by (simp add: kc_def hA)
  show ?thesis proof (intro set_eqI iffI)
    fix i
    assume "i \<in> {i. i < N \<and> i mod r = x0}"
    then have iN: "i < N" and im: "i mod r = x0" by auto
    have dm: "i div r * r + i mod r = i" by (rule div_mult_mod_eq)
    have bound: "i div r * r \<le> A" using iN hNA dm im by linarith
    have "i div r \<le> A div r" using bound by (simp add: less_eq_div_iff_mult_less_eq r)
    then have "i div r < kc N r x0" using hK by simp
    moreover have "x0 + r * (i div r) = i" using dm im by (simp add: mult.commute)
    ultimately show "i \<in> (\<lambda>m. x0 + r * m) ` {..<kc N r x0}" by (intro image_eqI[of _ _ "i div r"]) auto
  next
    fix i
    assume "i \<in> (\<lambda>m. x0 + r * m) ` {..<kc N r x0}"
    then obtain m where mK: "m < kc N r x0" and ieq: "i = x0 + r * m" by auto
    have "m \<le> A div r" using mK hK by simp
    then have "m * r \<le> A" by (simp add: less_eq_div_iff_mult_less_eq r)
    then have "i < N" using ieq hNA mult.commute[of r m] by linarith
    moreover have "i mod r = x0" using ieq x0 by (simp add: add.commute mod_mult_self1)
    ultimately show "i \<in> {i. i < N \<and> i mod r = x0}" by simp
  qed
qed
lemma kc_inj:
  fixes x0 r :: nat and A :: "nat set"
  assumes "0 < r"
  shows "inj_on (\<lambda>m. x0 + r * m) A"
proof (rule inj_onI)
  fix x y assume "x0 + r * x = x0 + r * y"
  then have h: "r * x = r * y" by simp
  have hr: "r \<noteq> 0" using assms by simp
  show "x = y" using h hr by (simp add: mult_cancel_left)
qed
lemma kc_card:
  assumes r: "0 < r" and x0: "x0 < r" and xN: "x0 < N"
  shows "card {i. i < N \<and> i mod r = x0} = kc N r x0"
  using kc_inj[OF r, of x0] by (simp add: kc_set[OF r x0 xN] card_image)
lemma kc_bounds:
  assumes r: "0 < r" and x0: "x0 < r" and xN: "x0 < N"
  shows "N - x0 \<le> kc N r x0 * r" and "kc N r x0 * r < N - x0 + r"
proof -
  obtain A where hA: "A = N - x0 - 1" by blast
  have hNA: "N = A + x0 + 1" using xN hA by arith
  have hK: "kc N r x0 * r = A div r * r + r" by (simp add: kc_def hA algebra_simps)
  have d: "A div r * r + A mod r = A" by (rule div_mult_mod_eq)
  have m: "A mod r < r" using r by (rule mod_less_divisor)
  show "N - x0 \<le> kc N r x0 * r" using hK d m hNA by linarith
  show "kc N r x0 * r < N - x0 + r" using hK d hNA by linarith
qed
lemma sum_kc:
  fixes f :: "nat \<Rightarrow> complex"
  assumes r: "0 < r" and x0: "x0 < r" and xN: "x0 < N"
  shows "(\<Sum>k<N. if k < N \<and> k mod r = x0 then f k else 0) = (\<Sum>m<kc N r x0. f (x0 + r * m))"
proof -
  have hS: "{..<N} \<inter> {k. k mod r = x0} = (\<lambda>m. x0 + r * m) ` {..<kc N r x0}" using kc_set[OF r x0 xN] by auto
  have "(\<Sum>k<N. if k < N \<and> k mod r = x0 then f k else 0) = (\<Sum>k<N. if k mod r = x0 then f k else 0)" by (intro sum.cong) auto
  also have "\<dots> = (\<Sum>k \<in> {..<N} \<inter> {k. k mod r = x0}. f k)"
    by (simp add: sum.inter_restrict)
  also have "\<dots> = (\<Sum>k \<in> (\<lambda>m. x0 + r * m) ` {..<kc N r x0}. f k)"
    by (simp add: hS)
  also have "\<dots> = (\<Sum>m<kc N r x0. f (x0 + r * m))"
    by (simp add: sum.reindex[OF kc_inj[OF r]] o_def)
  finally show ?thesis .
qed
lemma periodic_state_kc:
  assumes "0 < r" "x0 < r" "x0 < N"
  shows "periodic_state N r x0 k = (if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real (kc N r x0))) else 0)"
  using kc_card[OF assms] by (simp add: periodic_state_def)
lemma gp_id:
  fixes z :: complex
  shows "(z - 1) * (\<Sum>m<K. z^m) = z^K - 1"
  by (induct K) (simp_all add: lessThan_Suc algebra_simps)
lemma cis_pow_nat:
  "cis b ^ m = cis (real m * b)"
proof (induct m)
  case 0 then show ?case by simp
next
  case (Suc m)
  then show ?case by (simp add: cis_mult[symmetric] algebra_simps)
qed
lemma cmod_cis_minus_one_sq:
  "(cmod (cis \<theta> - 1))\<^sup>2 = 4 * (sin (\<theta> / 2))\<^sup>2"
proof -
  let ?s = "sin (\<theta>/2)" and ?c = "cos (\<theta>/2)"
  have c: "cos \<theta> = 1 - 2 * ?s^2" using cos_double_sin[of "\<theta>/2"] by simp
  have s: "sin \<theta> = 2 * ?s * ?c" using sin_double[of "\<theta>/2"] by simp
  have pyth: "?s^2 + ?c^2 = 1" using sin_cos_squared_add[of "\<theta>/2"] by simp
  have "(cmod (cis \<theta> - 1))\<^sup>2 = (Re (cis \<theta> - 1))^2 + (Im (cis \<theta> - 1))^2" by (rule cmod_power2)
  also have "\<dots> = (cos \<theta> - 1)^2 + (sin \<theta>)^2"
    by (simp add: cis_def)
  also have "\<dots> = (-2 * ?s^2)^2 + (2 * ?s * ?c)^2" using c s by simp
  also have "\<dots> = 4 * ?s^2 * (?s^2 + ?c^2)"
    by (simp only: power2_eq_square algebra_simps)
  also have "\<dots> = 4 * ?s^2 * 1" by (simp only: pyth)
  finally show ?thesis by simp
qed
lemma cis_add_int_2pi:
  fixes x :: real and n :: int
  shows "cis (x + 2 * pi * real_of_int n) = cis x"
proof -
  have "cis (2 * pi * real_of_int n) = 1" using cis_multiple_2pi[of "real_of_int n"] by simp
  then show ?thesis using cis_mult[of x "2 * pi * real_of_int n"] by simp
qed
lemma cis_term:
  fixes N j x0 r m :: nat and c :: int
  assumes "0 < N"
  shows "cis (2 * pi * real j * real (x0 + r * m) / real N) = cis (2 * pi * real j * real x0 / real N) * (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m"
proof -
  have N0: "real N \<noteq> 0" using assms by simp
  have eq: "2 * pi * real j * real (x0 + r * m) / real N = (2 * pi * real j * real x0 / real N + real m * (2 * pi * (real j * real r - real_of_int c * real N) / real N)) + 2 * pi * real_of_int (of_nat m * c)" using N0 by (simp add: field_simps)
  have "cis (2 * pi * real j * real (x0 + r * m) / real N) = cis (2 * pi * real j * real x0 / real N + real m * (2 * pi * (real j * real r - real_of_int c * real N) / real N))" using eq cis_add_int_2pi[of _ "of_nat m * c"] by simp
  also have "\<dots> = cis (2 * pi * real j * real x0 / real N) * cis (real m * (2 * pi * (real j * real r - real_of_int c * real N) / real N))"
    by (simp add: cis_mult[symmetric])
  also have "\<dots> = cis (2 * pi * real j * real x0 / real N) * (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m"
    by (simp add: cis_pow_nat)
  finally show ?thesis .
qed
lemma T_eq:
  fixes N j x0 r :: nat and K :: nat and c :: int
  assumes "0 < N"
  shows "(\<Sum>m<K. cis (2 * pi * real j * real (x0 + r * m) / real N)) = cis (2 * pi * real j * real x0 / real N) * (\<Sum>m<K. (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m)"
proof -
  have "(\<Sum>m<K. cis (2 * pi * real j * real (x0 + r * m) / real N)) = (\<Sum>m<K. cis (2 * pi * real j * real x0 / real N) * (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m)" by (intro sum.cong refl) (rule cis_term[OF assms])
  then show ?thesis by (simp only: sum_distrib_left)
qed
lemma S_identity:
  fixes b :: real
  shows "(cmod (\<Sum>m<K. (cis b) ^ m))\<^sup>2 * (sin (b / 2))\<^sup>2 = (sin (real K * b / 2))\<^sup>2"
proof -
  have g: "(cis b - 1) * (\<Sum>m<K. (cis b) ^ m) = cis (real K * b) - 1" using gp_id[of "cis b" K] cis_pow_nat[of b K] by simp
  have "(cmod ((cis b - 1) * (\<Sum>m<K. (cis b) ^ m)))\<^sup>2 = (cmod (cis (real K * b) - 1))\<^sup>2" using g by simp
  then have "(cmod (cis b - 1))\<^sup>2 * (cmod (\<Sum>m<K. (cis b) ^ m))\<^sup>2 = (cmod (cis (real K * b) - 1))\<^sup>2" by (simp add: norm_mult power_mult_distrib)
  then have h4: "4 * ((cmod (\<Sum>m<K. (cis b) ^ m))\<^sup>2 * (sin (b / 2))\<^sup>2) = 4 * (sin (real K * b / 2))\<^sup>2" using cmod_cis_minus_one_sq[of b] cmod_cis_minus_one_sq[of "real K * b"] by (simp add: algebra_simps)
  show ?thesis using h4 by simp
qed
lemma sin_sq_le_sq: fixes t :: real shows "(sin t)\<^sup>2 \<le> t\<^sup>2"
proof -
  have "\<bar>sin t\<bar> \<le> \<bar>t\<bar>" proof (cases "0 \<le> t")
    case True
    then show ?thesis using sin_x_le_x[of t] sin_x_ge_neg_x[of t] by simp
  next
    case False
    then have t: "0 \<le> -t" by simp
    then show ?thesis using sin_x_le_x[of "-t"] sin_x_ge_neg_x[of "-t"] by simp
  qed
  then have "\<bar>sin t\<bar>^2 \<le> \<bar>t\<bar>^2" by (rule power_mono) simp
  then show ?thesis by simp
qed
lemma qft_periodic:
  assumes "0 < r" "x0 < r" "x0 < N"
  shows "qft N (periodic_state N r x0) j = (\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N)) * complex_of_real (1 / sqrt (real (kc N r x0))) / complex_of_real (sqrt (real N))"
proof -
  have h1: "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k) = (\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N) * complex_of_real (1 / sqrt (real (kc N r x0))))" proof -
    have "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k) = (\<Sum>k<N. if k < N \<and> k mod r = x0 then cis (2 * pi * real j * real k / real N) * complex_of_real (1 / sqrt (real (kc N r x0))) else 0)" by (intro sum.cong) (auto simp: periodic_state_kc[OF assms])
    also have "\<dots> = (\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N) * complex_of_real (1 / sqrt (real (kc N r x0))))"
      by (rule sum_kc[OF assms])
    finally show ?thesis .
  qed
  have "qft N (periodic_state N r x0) j = (\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k) / complex_of_real (sqrt (real N))" by (simp add: qft_def)
  also have "\<dots> = (\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N) * complex_of_real (1 / sqrt (real (kc N r x0)))) / complex_of_real (sqrt (real N))"
    by (simp only: h1)
  also have "\<dots> = (\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N)) * complex_of_real (1 / sqrt (real (kc N r x0))) / complex_of_real (sqrt (real N))"
    by (simp only: sum_distrib_right)
  finally show ?thesis .
qed
lemma prob_periodic:
  assumes "0 < r" "x0 < r" "x0 < N"
  shows "prob (qft N (periodic_state N r x0)) j = (cmod (\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N)))\<^sup>2 / (real (kc N r x0) * real N)"
proof -
  have K1: "1 \<le> kc N r x0" by (simp add: kc_def)
  have Kpos: "(0::real) < real (kc N r x0)" using K1 by simp
  have Npos: "(0::real) < real N" using assms by simp
  define T where "T = (\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N))"
  have sK: "0 < sqrt (real (kc N r x0))" using Kpos by simp
  have pK: "0 < 1 / sqrt (real (kc N r x0))" using sK by simp
  have cK: "cmod (complex_of_real (1 / sqrt (real (kc N r x0)))) = 1 / sqrt (real (kc N r x0))" by (simp only: norm_of_real abs_of_pos[OF pK])
  have cN: "cmod (complex_of_real (sqrt (real N))) = sqrt (real N)" using Npos by simp
  have "prob (qft N (periodic_state N r x0)) j = (cmod (qft N (periodic_state N r x0) j))\<^sup>2" by (simp add: prob_def)
  also have "\<dots> = (cmod (T * complex_of_real (1 / sqrt (real (kc N r x0))) / complex_of_real (sqrt (real N))))\<^sup>2"
    by (simp add: qft_periodic[OF assms] T_def)
  also have "\<dots> = (cmod T * (1 / sqrt (real (kc N r x0))) / sqrt (real N))\<^sup>2"
    by (simp add: norm_divide norm_mult cK cN)
  also have "\<dots> = (cmod T)\<^sup>2 / (real (kc N r x0) * real N)" using Kpos Npos by (simp add: power_divide power_mult_distrib real_sqrt_pow2 field_simps)
  finally show ?thesis unfolding T_def .
qed
lemma T_lower:
  fixes N r j K :: nat and c :: int and x0 :: nat
  assumes r: "0 < r" and rN: "r < N" and K1: "1 \<le> K"
    and hK1: "real N - real r \<le> real K * real r" and hK2: "real K * real r < real N + real r"
    and near: "2 * \<bar>real j * real r - real_of_int c * real N\<bar> \<le> real r"
  shows "4 / (pi^2 * real r) * (1 - real r / real N)^3 * (real K * real N) \<le> (cmod (\<Sum>m<K. (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m))\<^sup>2"
proof -
  define b where "b = 2 * pi * (real j * real r - real_of_int c * real N) / real N"
  define S where "S = (\<Sum>m<K. (cis b) ^ m)"
  define e where "e = real r / real N"
  define mu where "mu = real K * real r / real N"
  define y where "y = real K * b / 2"
  have Rpos: "(0::real) < real r" using r by simp
  have Npos: "(0::real) < real N" using rN r by simp
  have Kpos: "(0::real) < real K" using K1 by simp
  have e0: "0 < e" unfolding e_def using Rpos Npos by simp
  have e1: "e < 1" unfolding e_def using rN Npos by (simp add: divide_less_eq)
  have mu1: "1 - e \<le> mu" proof -
    have "1 - e = (real N - real r) / real N" unfolding e_def using Npos by (simp add: field_simps)
    also have "\<dots> \<le> mu" unfolding mu_def using hK1 Npos by (intro divide_right_mono) auto
    finally show ?thesis .
  qed
  have mu2: "mu < 1 + e" proof -
    have "mu < (real N + real r) / real N" unfolding mu_def using hK2 Npos by (intro divide_strict_right_mono) auto
    also have "\<dots> = 1 + e" unfolding e_def using Npos by (simp add: field_simps)
    finally show ?thesis .
  qed
  have bN: "\<bar>b\<bar> * real N \<le> pi * real r" proof -
    have p2: "0 < 2 * pi" using pi_gt_zero by simp
    have eqb: "b * real N = (2 * pi) * (real j * real r - real_of_int c * real N)"
      unfolding b_def using Npos by (simp add: field_simps)
    have h1: "\<bar>b\<bar> * real N = (2 * pi) * \<bar>real j * real r - real_of_int c * real N\<bar>" proof -
      have "\<bar>b\<bar> * real N = \<bar>b * real N\<bar>" using Npos by (simp add: abs_mult abs_of_pos)
      also have "\<dots> = \<bar>(2 * pi) * (real j * real r - real_of_int c * real N)\<bar>" using eqb by simp
      also have "\<dots> = (2 * pi) * \<bar>real j * real r - real_of_int c * real N\<bar>" using p2 by (simp add: abs_mult abs_of_pos)
      finally show ?thesis .
    qed
    have h2: "pi * (2 * \<bar>real j * real r - real_of_int c * real N\<bar>) \<le> pi * real r" using near pi_gt_zero by (intro mult_left_mono) auto
    show ?thesis using h1 h2 by (simp add: algebra_simps)
  qed
  have ty: "\<bar>y\<bar> \<le> pi * mu / 2" proof -
    have "\<bar>y\<bar> = real K * \<bar>b\<bar> / 2" unfolding y_def using Kpos by (simp add: abs_mult abs_of_pos)
    also have "\<dots> \<le> pi * mu / 2"
    proof -
      have "real K * \<bar>b\<bar> * real N \<le> real K * (pi * real r)" using bN Kpos by (simp add: mult_left_mono mult.assoc mult.commute)
      then have "real K * \<bar>b\<bar> \<le> pi * real K * real r / real N" using Npos by (simp add: field_simps)
      then show ?thesis unfolding mu_def by (simp add: field_simps)
    qed
    finally show ?thesis .
  qed
  have key: "4 / pi^2 * (1 - e)^3 * y^2 \<le> mu * (sin y)^2" proof -
    have "4 / pi^2 * (1 - e)^3 * (\<bar>y\<bar>)^2 \<le> mu * (sin \<bar>y\<bar>)^2" using sine_key[of e mu "\<bar>y\<bar>"] e0 e1 mu1 mu2 ty by simp
    moreover have "(\<bar>y\<bar>)^2 = y^2" by simp
    moreover have "(sin \<bar>y\<bar>)^2 = (sin y)^2"
      by (cases "0 \<le> y") (auto simp: abs_of_neg)
    ultimately show ?thesis by simp
  qed
  have E1: "(cmod S)\<^sup>2 * (sin (b / 2))\<^sup>2 = (sin y)\<^sup>2"
    unfolding S_def y_def using S_identity[of b K] by simp
  have E2: "(sin y)\<^sup>2 \<le> (cmod S)\<^sup>2 * (b / 2)\<^sup>2" proof -
    have "(sin y)\<^sup>2 = (cmod S)\<^sup>2 * (sin (b / 2))\<^sup>2" using E1 by simp
    also have "\<dots> \<le> (cmod S)\<^sup>2 * (b / 2)\<^sup>2" using sin_sq_le_sq[of "b/2"] by (intro mult_left_mono) auto
    finally show ?thesis .
  qed
  have Sdef: "(\<Sum>m<K. (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m) = S" by (simp add: S_def b_def)
  have G: "4 / (pi^2 * real r) * (1 - e)^3 * (real K * real N) \<le> (cmod S)\<^sup>2" proof (cases "b = 0")
    case True
    then have S_eq: "S = of_nat K" unfolding S_def by simp
    have cS: "(cmod S)\<^sup>2 = (real K)^2" unfolding S_eq by simp
    have eN: "e * real N = real r" unfolding e_def using Npos by simp
    have p1: "(1 - e) * real N \<le> real K * real r" using hK1 eN by (simp add: algebra_simps)
    have e1le: "0 \<le> 1 - e" using e1 by simp
    have a1: "(1 - e) * (1 - e) \<le> 1" using e1le e1 e0 by (intro mult_le_one) auto
    have p2: "(1 - e)^3 \<le> 1 - e" proof -
      have "(1 - e) * ((1 - e) * (1 - e)) \<le> (1 - e) * 1" by (rule mult_left_mono[OF a1 e1le])
      then show ?thesis by (simp add: power3_eq_cube algebra_simps mult.assoc)
    qed
    have pi3: "3 \<le> pi" by (rule pi_ge_three)
    have pi2: "4 \<le> pi^2" proof -
      have "3 * 3 \<le> pi * pi" by (rule mult_mono) (use pi3 in auto)
      then show ?thesis by (simp add: power2_eq_square)
    qed
    have KN: "0 \<le> real K * real N" using Kpos Npos by simp
    have c1: "4 * (1 - e)^3 * (real K * real N) \<le> 4 * (1 - e) * (real K * real N)" using p2 KN by (intro mult_right_mono) (auto simp: mult.assoc)
    have c2: "real K * ((1 - e) * real N) \<le> real K * (real K * real r)" by (rule mult_left_mono[OF p1 less_imp_le[OF Kpos]])
    have c3: "4 * (real K * (real K * real r)) \<le> pi^2 * (real K * (real K * real r))" using pi2 Kpos Rpos by (intro mult_right_mono) auto
    have hpos: "0 < pi^2 * real r" using pi3 Rpos by simp
    have "4 * (1 - e)^3 * (real K * real N) \<le> (real K)^2 * (pi^2 * real r)" proof -
      have "4 * (1 - e)^3 * (real K * real N) \<le> 4 * (1 - e) * (real K * real N)" using c1 by simp
      also have "4 * (1 - e) * (real K * real N) = 4 * (real K * ((1 - e) * real N))" by (simp add: algebra_simps)
      also have "\<dots> \<le> 4 * (real K * (real K * real r))" by (rule mult_left_mono[OF c2]) simp
      also have "\<dots> \<le> pi^2 * (real K * (real K * real r))" using c3 by simp
      also have "\<dots> = (real K)^2 * (pi^2 * real r)" by (simp add: power2_eq_square algebra_simps)
      finally show ?thesis .
    qed
    then have "4 * (1 - e)^3 * (real K * real N) / (pi^2 * real r) \<le> (real K)^2" using hpos by (simp add: pos_divide_le_eq)
    then have "4 / (pi^2 * real r) * (1 - e)^3 * (real K * real N) \<le> (real K)^2" by (simp add: field_simps)
    then show ?thesis using cS by simp
  next
    case False
    then have ynz: "y \<noteq> 0" unfolding y_def using Kpos by simp
    have yy: "0 < y^2" using ynz by simp
    have G: "4 / pi^2 * (1 - e)^3 * (y^2) * (real K * real N / real r) \<le> (real K)^2 * (sin y)^2" proof -
      have "4 / pi^2 * (1 - e)^3 * y^2 * (real K * real N / real r) \<le> mu * (sin y)^2 * (real K * real N / real r)" using key by (intro mult_right_mono) auto
      also have "mu * (sin y)^2 * (real K * real N / real r) = (real K)^2 * (sin y)^2"
        unfolding mu_def e_def using Rpos Npos by (simp add: field_simps power2_eq_square)
      finally show ?thesis .
    qed
    have b2: "(b / 2)^2 * (real K)^2 = y^2" unfolding y_def by (simp add: field_simps)
    have H0: "(sin y)^2 * (real K)^2 \<le> (cmod S)\<^sup>2 * (b/2)^2 * (real K)^2" by (rule mult_right_mono[OF E2]) simp
    have E: "(cmod S)\<^sup>2 * (b/2)^2 * (real K)^2 = (cmod S)\<^sup>2 * y^2" by (simp add: mult.assoc b2)
    have H: "(sin y)^2 * (real K)^2 \<le> (cmod S)\<^sup>2 * y^2" by (rule order_trans[OF H0 E[THEN order_eq_refl]])
    have key2: "4 / (pi^2 * real r) * (1 - e)^3 * (real K * real N) * y^2 \<le> (cmod S)\<^sup>2 * y^2" proof -
      have "4 / (pi^2 * real r) * (1 - e)^3 * (real K * real N) * y^2 = 4 / pi^2 * (1 - e)^3 * y^2 * (real K * real N / real r)" by (simp add: field_simps)
      also have "\<dots> \<le> (real K)^2 * (sin y)^2" using G by simp
      also have "\<dots> \<le> (cmod S)\<^sup>2 * y^2" using H by (simp add: algebra_simps)
      finally show ?thesis .
    qed
    show ?thesis by (rule mult_right_le_imp_le[OF key2 yy])
  qed
  show ?thesis unfolding Sdef e_def by (rule G[unfolded e_def])
qed
lemma state_periodic:
  assumes "0 < r" "x0 < r" "x0 < N"
  shows "is_state N (periodic_state N r x0)"
proof -
  have K0: "(0::real) < real (kc N r x0)" using assms by (simp add: kc_def)
  have s2: "sqrt (real (kc N r x0)) * sqrt (real (kc N r x0)) = real (kc N r x0)" using real_sqrt_mult_self[of "real (kc N r x0)"] K0 by simp
  have sne: "sqrt (real (kc N r x0)) \<noteq> 0" using K0 by simp
  have sq: "(1 / sqrt (real (kc N r x0))) * (1 / sqrt (real (kc N r x0))) = 1 / real (kc N r x0)" using s2 sne by (simp add: field_simps)
  have cc: "\<And>a::real. cnj (complex_of_real a) * complex_of_real a = complex_of_real (a * a)" by (simp add: of_real_mult)
  have h: "\<And>i. cnj (periodic_state N r x0 i) * periodic_state N r x0 i = (if i < N \<and> i mod r = x0 then complex_of_real (1 / real (kc N r x0)) else 0)" proof -
    fix i
    show "cnj (periodic_state N r x0 i) * periodic_state N r x0 i = (if i < N \<and> i mod r = x0 then complex_of_real (1 / real (kc N r x0)) else 0)" proof (cases "i < N \<and> i mod r = x0")
      case True
      have hP: "i < N \<and> i mod r = x0" using True by simp
      have e1: "(if i < N \<and> i mod r = x0 then complex_of_real (1 / sqrt (real (kc N r x0))) else 0) = complex_of_real (1 / sqrt (real (kc N r x0)))" by (rule if_P[OF hP])
      have e2: "(if i < N \<and> i mod r = x0 then complex_of_real (1 / real (kc N r x0)) else 0) = complex_of_real (1 / real (kc N r x0))" by (rule if_P[OF hP])
      show ?thesis unfolding periodic_state_kc[OF assms] e1 e2 by (simp only: cc sq)
    next
      case False
      have hP: "\<not> (i < N \<and> i mod r = x0)" using False by simp
      have e0: "(if i < N \<and> i mod r = x0 then complex_of_real (1 / sqrt (real (kc N r x0))) else 0) = 0" by (rule if_not_P[OF hP])
      have e0': "(if i < N \<and> i mod r = x0 then complex_of_real (1 / real (kc N r x0)) else 0) = 0" by (rule if_not_P[OF hP])
      show ?thesis unfolding periodic_state_kc[OF assms] e0 e0' by simp
    qed
  qed
  have "inner N (periodic_state N r x0) (periodic_state N r x0) = (\<Sum>i<N. if i < N \<and> i mod r = x0 then complex_of_real (1 / real (kc N r x0)) else 0)" by (simp add: inner_def h)
  also have "\<dots> = (\<Sum>m<kc N r x0. complex_of_real (1 / real (kc N r x0)))"
    by (rule sum_kc[OF assms, of "\<lambda>_. complex_of_real (1 / real (kc N r x0))"])
  also have "\<dots> = 1" using K0 by (simp add: field_simps)
  finally show ?thesis unfolding is_state_def .
qed
theorem shor_peak:
  assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r" and j: "j < N"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "is_state N (periodic_state N r x0) \<and> 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
proof -
  have xN: "x0 < N" using x0 rN by simp
  have hb: "N - x0 \<le> kc N r x0 * r" and hb2: "kc N r x0 * r < N - x0 + r" using kc_bounds[OF r x0 xN] by auto
  have K1: "1 \<le> kc N r x0" by (simp add: kc_def)
  have hK1: "real N - real r \<le> real (kc N r x0) * real r" proof -
    have "real (N - x0) \<le> real (kc N r x0 * r)" using hb by (simp only: of_nat_le_iff)
    moreover have "real (N - x0) = real N - real x0" using xN by (simp add: of_nat_diff)
    ultimately show ?thesis using x0 by (simp add: of_nat_mult)
  qed
  have hK2: "real (kc N r x0) * real r < real N + real r" proof -
    have "real (kc N r x0 * r) < real (N - x0 + r)" using hb2 by (simp only: of_nat_less_iff)
    moreover have "real (N - x0 + r) \<le> real N + real r" using xN by (simp add: of_nat_diff)
    ultimately show ?thesis by (simp add: of_nat_mult)
  qed
  have near_r: "2 * \<bar>real j * real r - real_of_int c * real N\<bar> \<le> real r" proof -
    have "real_of_int (2 * \<bar>int j * int r - c * int N\<bar>) \<le> real_of_int (int r)" using near by (simp only: of_int_le_iff)
    then show ?thesis by (simp add: abs_mult)
  qed
  have st: "is_state N (periodic_state N r x0)" using state_periodic[OF r x0 xN ] by simp
  have bnd: "4 / (pi^2 * real r) * (1 - real r / real N)^3 \<le> prob (qft N (periodic_state N r x0)) j" proof -
    have T: "(\<Sum>m<kc N r x0. cis (2 * pi * real j * real (x0 + r * m) / real N)) = cis (2 * pi * real j * real x0 / real N) * (\<Sum>m<kc N r x0. (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m)" by (rule T_eq) (use r xN in simp)
    have cnorm: "cmod (cis (2 * pi * real j * real x0 / real N)) = 1" by simp
    have TL: "4 / (pi^2 * real r) * (1 - real r / real N)^3 * (real (kc N r x0) * real N) \<le> (cmod (\<Sum>m<kc N r x0. (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m))\<^sup>2" by (rule T_lower[OF r rN K1 hK1 hK2 near_r])
    have Npos: "(0::real) < real N" using rN r by simp
    have KNpos: "(0::real) < real (kc N r x0) * real N" using K1 Npos by simp
    have eq: "prob (qft N (periodic_state N r x0)) j = (cmod (\<Sum>m<kc N r x0. (cis (2 * pi * (real j * real r - real_of_int c * real N) / real N)) ^ m))\<^sup>2 / (real (kc N r x0) * real N)" using prob_periodic[OF r x0 xN] T cnorm by (simp add: norm_mult)
    show ?thesis unfolding eq by (rule iffD2[OF pos_le_divide_eq[OF KNpos] TL])
  qed
  show ?thesis using st bnd by (intro conjI)
qed
lemma abs_twice_bounds:
  fixes x y :: int
  assumes "2 * \<bar>x\<bar> \<le> y"
  shows "- y \<le> 2 * x \<and> 2 * x \<le> y"
proof -
  have "- \<bar>x\<bar> \<le> x" and "x \<le> \<bar>x\<bar>" by auto
  with assms show ?thesis by linarith
qed
lemma recover_core:
  fixes b r N Y d1 d2 :: int
  assumes bZ: "0 < b" and rZ: "0 < r" and d2U: "d2 \<le> r" and d2L: "- r \<le> d2"
    and d1U: "d1 \<le> b" and d1L: "- b \<le> d1"
    and iden: "2 * (N * Y) = b * d2 - r * d1"
    and rb: "r * b < N" and NZ: "0 < N"
  shows "Y = 0"
proof -
  have q1: "b * d2 \<le> b * r" using d2U bZ by (intro mult_left_mono) auto
  have q2: "b * (- r) \<le> b * d2" using d2L bZ by (intro mult_left_mono) auto
  have q3: "r * (- b) \<le> r * d1" using d1L rZ by (intro mult_left_mono) auto
  have q4: "r * d1 \<le> r * b" using d1U rZ by (intro mult_left_mono) auto
  have e1: "b * (- r) = - (r * b)" by (simp add: mult.commute)
  have e2: "r * (- b) = - (r * b)" by simp
  have e3: "b * r = r * b" by (simp add: mult.commute)
  have up: "N * Y \<le> r * b" using iden q1 q3 e1 e2 e3 by linarith
  have lo: "- (r * b) \<le> N * Y" using iden q2 q4 e1 e2 e3 by linarith
  have "Y \<ge> 1 \<or> Y \<le> -1 \<or> Y = 0" by presburger
  then show ?thesis
  proof (elim disjE)
    assume "Y \<ge> 1"
    then have "N * 1 \<le> N * Y" using NZ by (intro mult_left_mono) auto
    with up rb have False by linarith
    then show ?thesis by blast
  next
    assume "Y \<le> -1"
    then have "N * Y \<le> N * (-1)" using NZ by (intro mult_left_mono) auto
    with lo rb have False by linarith
    then show ?thesis by blast
  qed
qed
lemma recover_peak:
  assumes rr: "r * r < N" and r0: "0 < r" and cr: "c < r" and cop: "coprime c r"
    and near: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r"
  shows "recover N j = r"
proof -
  have rle: "r \<le> r * r" by (rule le_square)
  have rN: "r < N" using rr rle r0 by linarith
  have rZ: "(0::int) < int r" using r0 by simp
  have NZ: "(0::int) < int N" using rN r0 by simp
  have rrZ: "int r * int r < int N" using rr by (metis of_nat_less_iff of_nat_mult)
  show ?thesis proof (unfold recover_def, rule Least_equality)
    show "0 < r \<and> (\<exists>a::int. 2 * \<bar>int j * int r - a * int N\<bar> \<le> int r)" using r0 near by auto
  next
    fix b assume hb: "0 < b \<and> (\<exists>a::int. 2 * \<bar>int j * int b - a * int N\<bar> \<le> int b)"
    then obtain a' where hb0: "0 < b"
      and hnear: "2 * \<bar>int j * int b - a' * int N\<bar> \<le> int b" by auto
    show "r \<le> b" proof (rule ccontr)
      assume "\<not> r \<le> b"
      then have blt: "b < r" by simp
      have bZ: "(0::int) < int b" using hb0 by simp
      have blZ: "int b < int r" using blt by simp
      have rb_le: "int r * int b \<le> int r * int r" using blZ rZ by (intro mult_left_mono) auto
      have rbN: "int r * int b < int N" using rb_le rrZ by linarith
      have d2b: "- int r \<le> 2 * (int j * int r - int c * int N) \<and> 2 * (int j * int r - int c * int N) \<le> int r" using abs_twice_bounds[OF near] .
      have d1b: "- int b \<le> 2 * (int j * int b - a' * int N) \<and> 2 * (int j * int b - a' * int N) \<le> int b" using abs_twice_bounds[OF hnear] .
      have iden: "2 * (int N * (a' * int r - int c * int b)) = int b * (2 * (int j * int r - int c * int N)) - int r * (2 * (int j * int b - a' * int N))" by (simp add: algebra_simps)
      have Yz: "a' * int r - int c * int b = 0" by (rule recover_core[OF bZ rZ conjunct2[OF d2b] conjunct1[OF d2b] conjunct2[OF d1b] conjunct1[OF d1b] iden rbN NZ])
      have hcb: "int c * int b = a' * int r" using Yz by linarith
      have dvdZ: "int r dvd int (c * b)"
        unfolding dvd_def using hcb by (simp add: mult.commute)
      have dvdN: "r dvd c * b" using dvdZ by (rule int_dvd_int_iff[THEN iffD1])
      have cop': "coprime r c" using cop by (simp add: coprime_commute)
      have rb: "r dvd b" using dvdN cop' coprime_dvd_mult_right_iff by blast
      have "r \<le> b" using rb hb0 by (intro Nat.dvd_imp_le) auto
      with blt show False by simp
    qed
  qed
qed
lemma abs_from_bounds:
  fixes u A R :: int
  assumes "- R \<le> 2 * u - 2 * A" and "2 * u - 2 * A \<le> R"
  shows "2 * \<bar>u - A\<bar> \<le> R"
proof -
  have e: "2 * u - 2 * A = 2 * (u - A)" by (simp add: algebra_simps)
  have h1: "- R \<le> 2 * (u - A)" using assms e by linarith
  have h2: "2 * (u - A) \<le> R" using assms e by linarith
  have k1: "\<bar>2 * (u - A)\<bar> \<le> R" using h1 h2 by (simp add: abs_le_iff)
  have k3: "\<bar>(2::int)\<bar> = 2" by simp
  have k2: "\<bar>2 * (u - A)\<bar> = 2 * \<bar>u - A\<bar>" by (simp only: abs_mult k3)
  show ?thesis using k1 k2 by linarith
qed
lemma dist_bounds:
  fixes u A R :: int
  assumes "2 * \<bar>u - A\<bar> \<le> R"
  shows "- R \<le> 2 * u - 2 * A \<and> 2 * u - 2 * A \<le> R"
proof -
  have e: "2 * u - 2 * A = 2 * (u - A)" by (simp add: algebra_simps)
  have hh: "- R \<le> 2 * (u - A) \<and> 2 * (u - A) \<le> R" using abs_twice_bounds[OF assms] .
  have a: "- R \<le> 2 * u - 2 * A" using hh e by linarith
  have b: "2 * u - 2 * A \<le> R" using hh e by linarith
  show ?thesis using a b by blast
qed
lemma div_near:
  assumes eq: "2 * r * q + s = 2 * c * N + r" and hs: "s < 2 * r"
  shows "2 * \<bar>int q * int r - int c * int N\<bar> \<le> int r"
proof -
  have eqZ: "int (2 * r * q + s) = int (2 * c * N + r)" by (rule arg_cong[of _ _ int, OF eq])
  have hX: "2 * (int q * int r) + int s = 2 * (int c * int N) + int r" using eqZ by (simp add: algebra_simps)
  have s0: "(0::int) \<le> int s" by simp
  have s2: "int s < 2 * int r" using hs by simp
  have hb: "2 * (int q * int r) - 2 * (int c * int N) \<le> int r" using hX s0 by linarith
  have hb': "- int r \<le> 2 * (int q * int r) - 2 * (int c * int N)" using hX s2 by linarith
  show ?thesis using abs_from_bounds[OF hb' hb] .
qed
lemma peak_point:
  fixes r c N :: nat
  assumes rN: "r < N" and r0: "0 < r" and cr: "c < r"
  shows "(2 * c * N + r) div (2 * r) < N"
proof -
  have hdm: "2 * r * ((2 * c * N + r) div (2 * r)) + (2 * c * N + r) mod (2 * r) = 2 * c * N + r" using mod_mult_div_eq[of "2 * c * N + r" "2 * r"] by (simp add: ac_simps)
  show ?thesis proof (rule ccontr)
    assume "\<not> (2 * c * N + r) div (2 * r) < N"
    then have hq: "N \<le> (2 * c * N + r) div (2 * r)" by simp
    have h1: "2 * r * N \<le> 2 * r * ((2 * c * N + r) div (2 * r))" using hq by (intro mult_left_mono) auto
    have h2: "(c + 1) * N \<le> r * N" using cr by (intro mult_right_mono) auto
    have h3: "2 * r * ((2 * c * N + r) div (2 * r)) \<le> 2 * c * N + r" using hdm by simp
    have h4: "2 * r * N \<le> 2 * c * N + r" using h1 h3 by linarith
    have h5: "2 * c * N + 2 * N \<le> 2 * r * N" using h2 by (simp add: algebra_simps)
    show False using h4 h5 rN by linarith
  qed
qed
lemma peak_inj_core:
  fixes c c' N u R :: int
  assumes h1: "- R \<le> 2 * u - 2 * (c * N)" and h1': "2 * u - 2 * (c * N) \<le> R"
    and h2: "- R \<le> 2 * u - 2 * (c' * N)" and h2': "2 * u - 2 * (c' * N) \<le> R"
    and NZ: "0 < N" and RN: "R < N"
  shows "c = c'"
proof -
  have k1: "2 * (c' * N) - 2 * (c * N) \<le> 2 * R" using h1' h2 by linarith
  have k2: "- (2 * R) \<le> 2 * (c' * N) - 2 * (c * N)" using h1 h2' by linarith
  have "c' - c \<ge> 1 \<or> c' - c \<le> -1 \<or> c' - c = 0" by presburger
  then show ?thesis
  proof (elim disjE)
    assume "c' - c \<ge> 1"
    then have m: "(c + 1) * N \<le> c' * N" using NZ by (intro mult_right_mono) auto
    have e: "(c + 1) * N = c * N + N" by (simp add: algebra_simps)
    show ?thesis using m e k1 RN by linarith
  next
    assume "c' - c \<le> -1"
    then have m: "c' * N \<le> (c - 1) * N" using NZ by (intro mult_right_mono) auto
    have e: "(c - 1) * N = c * N - N" by (simp add: algebra_simps)
    show ?thesis using m e k2 RN by linarith
  next
    assume "c' - c = 0"
    then show ?thesis by simp
  qed
qed
lemma peak_inj:
  fixes r c c' N j :: nat
  assumes rN: "r < N" and cr: "c < r" and c'r: "c' < r"
    and h1: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r"
    and h2: "2 * \<bar>int j * int r - int c' * int N\<bar> \<le> int r"
  shows "c = c'"
proof -
  have rN': "int r < int N" using rN by simp
  have NZ: "(0::int) < int N" using rN' by linarith
  have b1: "- int r \<le> 2 * (int j * int r) - 2 * (int c * int N) \<and> 2 * (int j * int r) - 2 * (int c * int N) \<le> int r" using dist_bounds[OF h1] by simp
  have b2: "- int r \<le> 2 * (int j * int r) - 2 * (int c' * int N) \<and> 2 * (int j * int r) - 2 * (int c' * int N) \<le> int r" using dist_bounds[OF h2] by simp
  have "int c = int c'" using peak_inj_core[OF conjunct1[OF b1] conjunct2[OF b1] conjunct1[OF b2] conjunct2[OF b2] NZ rN'] .
  then show ?thesis by simp
qed
theorem shor_general_success:
  assumes r: "0 < r" and rr: "r * r < N" and x0: "x0 < r"
  shows "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3 \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
proof -
  have rle: "r \<le> r * r" by (rule le_square)
  have rN: "r < N" using r rr rle by linarith
  have rPos: "(0::real) < real r" using r by simp
  have piPos: "(0::real) < pi" by (rule pi_gt_zero)
  define jc where "jc = (\<lambda>c. (2 * c * N + r) div (2 * r))"
  define C where "C = {c. c < r \<and> coprime c r}"
  define B where "B = {j. j < N \<and> recover N j = r}"
  have fB: "finite B" unfolding B_def by (rule finite_subset[of _ "{..<N}"]) auto
  have peak: "\<And>c. c < r \<Longrightarrow> jc c < N \<and> 2 * \<bar>int (jc c) * int r - int c * int N\<bar> \<le> int r" proof -
    fix c assume cr: "c < r"
    have lt: "(2 * c * N + r) div (2 * r) < N" using peak_point[OF rN r cr] .
    have eq: "2 * r * ((2 * c * N + r) div (2 * r)) + (2 * c * N + r) mod (2 * r) = 2 * c * N + r" using mod_mult_div_eq[of "2 * c * N + r" "2 * r"] by (simp add: ac_simps)
    have hs: "(2 * c * N + r) mod (2 * r) < 2 * r" using r by (intro mod_less_divisor) auto
    have near: "2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int r - int c * int N\<bar> \<le> int r" using div_near[OF eq hs] .
    show "jc c < N \<and> 2 * \<bar>int (jc c) * int r - int c * int N\<bar> \<le> int r"
      unfolding jc_def using lt near by simp
  qed
  have inj: "inj_on jc C" proof (rule inj_onI)
    fix c c' assume hc: "c \<in> C" and hc': "c' \<in> C" and eq: "jc c = jc c'"
    have cr: "c < r" and cr': "c' < r" using hc hc' unfolding C_def by auto
    have n1: "2 * \<bar>int (jc c') * int r - int c * int N\<bar> \<le> int r" using peak[OF cr] eq by simp
    have n2: "2 * \<bar>int (jc c') * int r - int c' * int N\<bar> \<le> int r" using peak[OF cr'] by simp
    show "c = c'" using peak_inj[OF rN cr cr' n1 n2] .
  qed
  have sub: "jc ` C \<subseteq> B" proof (rule subsetI)
    fix j assume "j \<in> jc ` C"
    then obtain c where hc: "c \<in> C" and jdef: "j = jc c" by auto
    have cr: "c < r" and cop: "coprime c r" using hc unfolding C_def by auto
    have near: "2 * \<bar>int (jc c) * int r - int c * int N\<bar> \<le> int r" using peak[OF cr] by simp
    have jlt: "jc c < N" using peak[OF cr] by simp
    have rec: "recover N (jc c) = r" using recover_peak[OF rr r cr cop near] .
    show "j \<in> B" using jdef jlt rec unfolding B_def by simp
  qed
  define v where "v = qft N (periodic_state N r x0)"
  have nn: "\<And>b. 0 \<le> prob v b" unfolding prob_def by simp
  have s1: "(\<Sum>j \<in> jc ` C. prob v j) = (\<Sum>c \<in> C. prob v (jc c))" using sum.reindex[OF inj] by (simp add: o_def)
  have s2: "(\<Sum>j \<in> jc ` C. prob v j) \<le> (\<Sum>j \<in> B. prob v j)" by (rule sum_mono2[OF fB sub]) (simp add: nn)
  have K_le: "\<And>c. c \<in> C \<Longrightarrow> 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob v (jc c)" proof -
    fix c assume hc: "c \<in> C"
    have cr: "c < r" using hc unfolding C_def by auto
    have near: "2 * \<bar>int (jc c) * int r - int c * int N\<bar> \<le> int r" using peak[OF cr] by simp
    have jlt: "jc c < N" using peak[OF cr] by simp
    have "is_state N (periodic_state N r x0) \<and> 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) (jc c)" using shor_peak[OF r rN x0 jlt near] .
    then show "4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob v (jc c)"
      unfolding v_def by simp
  qed
  have s4: "(\<Sum>c \<in> C. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3) \<le> (\<Sum>c \<in> C. prob v (jc c))" by (rule sum_mono) (rule K_le)
  have s5: "(\<Sum>c \<in> C. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3) = real (card C) * (4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3)" by simp
  have s6: "4 / pi\<^sup>2 * (real (card C) / real r) * (1 - real r / real N) ^ 3 = real (card C) * (4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3)" using rPos piPos by (simp add: field_simps)
  have goal_C: "4 / pi\<^sup>2 * (real (card C) / real r) * (1 - real r / real N) ^ 3 \<le> (\<Sum>j \<in> B. prob v j)" using s6 s5 s4 s1 s2 by linarith
  show ?thesis using goal_C unfolding C_def B_def v_def by simp
qed
end
