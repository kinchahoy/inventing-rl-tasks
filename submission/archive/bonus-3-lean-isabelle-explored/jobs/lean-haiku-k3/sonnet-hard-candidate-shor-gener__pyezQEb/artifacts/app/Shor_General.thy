theory Shor_General
  imports Quantum_Basics
begin

theorem shor_factor:
  assumes n: "1 < n" and ord: "is_order n a r" and even: "even r"
    and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
proof -
  from even obtain k where hk2: "r = 2 * k" by (rule evenE)
  have hk: "r = k + k" using hk2 by simp
  have hmk: "r div 2 = k" using hk2 by simp
  have r_pos: "0 < r" using ord by (simp add: is_order_def)
  have hpos: "0 < k" using r_pos hk by linarith
  have hkr: "k < r" using hk r_pos by linarith
  have h1: "a ^ r mod n = 1" using ord by (simp add: is_order_def)
  have hmin: "\<And>j. 0 < j \<Longrightarrow> j < r \<Longrightarrow> a ^ j mod n \<noteq> 1"
    using ord by (simp add: is_order_def)
  have nm: "a ^ k mod n \<noteq> n - 1" using not_minus_one hmk by simp
  obtain x where hx: "x = a ^ k" by blast
  have hsq_eq: "a ^ r = x * x" by (simp add: hk hx power_add)
  have hsq: "x * x mod n = 1" using h1 hsq_eq by simp
  have nm': "x mod n \<noteq> n - 1" using nm hx by simp
  have x_pos: "0 < x"
  proof (rule ccontr)
    assume "\<not> 0 < x"
    then have "x = 0" by simp
    with hsq show False by simp
  qed
  obtain y where hy: "x = y + 1" using x_pos by (cases x) auto
  have prod: "y * (y + 2) + 1 = x * x" by (simp add: hy algebra_simps power2_eq_square)
  (* n divides y(y+2) = (x-1)(x+1) *)
  have dvd_prod: "n dvd y * (y + 2)"
  proof -
    have hmod: "(y * (y + 2) + 1) mod n = 1" using hsq prod by simp
    have e: "n * ((y * (y + 2) + 1) div n) + (y * (y + 2) + 1) mod n = y * (y + 2) + 1"
      by (metis div_mult_mod_eq mult.commute)
    have hq: "y * (y + 2) = n * ((y * (y + 2) + 1) div n)" using e hmod by linarith
    show ?thesis unfolding dvd_def using hq by blast
  qed
  have d_dvd: "gcd y n dvd n" by simp
  have d_pos: "0 < gcd y n"
  proof (rule ccontr)
    assume "\<not> 0 < gcd y n"
    then have "gcd y n = 0" by simp
    then have "n = 0" using d_dvd by simp
    with n show False by simp
  qed
  (* gcd = 1 would force n | x+1, i.e. x mod n = n-1 *)
  have d_ne1: "gcd y n \<noteq> 1"
  proof
    assume d1: "gcd y n = 1"
    have g1: "gcd n y = 1" using d1 by (metis gcd.commute)
    have cop: "coprime n y" by (simp add: coprime_iff_gcd_eq_1 g1)
    have dvd_x1: "n dvd x + 1"
    proof -
      have "n dvd y + 2" by (metis cop dvd_prod coprime_dvd_mult_right_iff)
      then show ?thesis using hy by simp
    qed
    obtain q where hq: "x + 1 = n * q" using dvd_x1 by (auto simp: dvd_def)
    have e: "n * (x div n) + x mod n = x" by (metis div_mult_mod_eq mult.commute)
    have sl: "x mod n < n" using n by simp
    have hs: "x mod n + 1 = n"
    proof (cases "q \<le> x div n")
      case True
      have h1: "n * q \<le> n * (x div n)" by (rule mult_left_mono[OF True zero_le])
      show ?thesis using hq e h1 by linarith
    next
      case False
      then have hq1: "x div n + 1 \<le> q" by simp
      have h2: "n * (x div n + 1) \<le> n * q" by (rule mult_left_mono[OF hq1 zero_le])
      have h3: "n * (x div n + 1) = n * (x div n) + n" by (simp add: algebra_simps)
      show ?thesis using hq e h2 h3 sl by linarith
    qed
    have "x mod n = n - 1" using hs by arith
    with nm' show False by simp
  qed
  (* gcd = n would force x = 1 (mod n), contradicting minimality of the order *)
  have d_ne_n: "gcd y n \<noteq> n"
  proof
    assume dn: "gcd y n = n"
    have gy: "gcd y n dvd y" by simp
    have "n dvd y" using dn gy by simp
    then obtain q where yq: "y = n * q" by (auto simp: dvd_def)
    have xm0: "x = 1 + q * n" using hy yq by (simp add: algebra_simps)
    have m1: "1 mod n = 1" by (rule mod_less[OF n])
    have xm: "x mod n = 1" by (simp only: xm0 mod_mult_self1 m1)
    have "a ^ k mod n = 1" using hx xm by simp
    with hmin hpos hkr show False by blast
  qed
  have d_le: "gcd y n \<le> n" using d_dvd n by (intro Nat.dvd_imp_le) auto
  have ey: "a ^ (r div 2) - 1 = y"
  proof -
    have a1: "a ^ (r div 2) = x" using hmk hx by simp
    show ?thesis using a1 hy by simp
  qed
  have d_gt: "1 < gcd y n" using d_pos d_ne1 by arith
  have d_lt: "gcd y n < n" using d_le d_ne_n by arith
  show ?thesis unfolding ey using d_gt d_lt by blast
qed



lemma an_psi:
  assumes "0 \<le> x" "x \<le> pi"
  shows "x * cos x \<le> sin x"
proof -
  define f where "f = (\<lambda>t::real. sin t - t * cos t)"
  have "f 0 \<le> f x"
  proof (rule DERIV_nonneg_imp_nondecreasing[OF assms(1)])
    fix t assume h: "0 \<le> t" "t \<le> x"
    note d0 = DERIV_diff[OF DERIV_sin DERIV_mult[OF DERIV_ident DERIV_cos]]
    have "0 \<le> t * sin t"
      using h assms by (intro mult_nonneg_nonneg sin_ge_zero) linarith+
    have yy: "0 \<le> cos t - (1 * cos t + - sin t * t)" using \<open>0 \<le> t * sin t\<close> by (simp add: algebra_simps)
    show "\<exists>y. DERIV f t :> y \<and> y \<ge> 0" unfolding f_def using d0 yy by blast
  qed
  have h0: "f 0 = 0" by (simp add: f_def)
  have hx: "f x = sin x - x * cos x" by (simp add: f_def)
  from \<open>f 0 \<le> f x\<close> h0 hx show ?thesis by linarith
qed

lemma an_jordan:
  assumes z0: "0 \<le> z" and z1: "z \<le> pi / 2"
  shows "2 / pi * z \<le> sin z"
proof (cases "z = 0")
  case True
  then show ?thesis by simp
next
  case False
  with z0 have zpos: "0 < z" by linarith
  define q where "q = (\<lambda>x::real. sin x / x)"
  have mono: "q (pi / 2) \<le> q z"
  proof (rule DERIV_nonpos_imp_nonincreasing[OF z1])
    fix t assume h: "z \<le> t" "t \<le> pi / 2"
    have tpos: "0 < t" using h zpos by linarith
    have tpi: "t \<le> pi" using h pi_ge_two by linarith
    have tne: "t \<noteq> 0" using tpos by simp
    note d0 = DERIV_divide[OF DERIV_sin DERIV_ident tne]
    have psi: "t * cos t \<le> sin t" using an_psi[OF less_imp_le[OF tpos] tpi] .
    have num: "cos t * t - sin t * 1 \<le> 0"
      using psi by (simp add: algebra_simps)
    have sgn: "(cos t * t - sin t * 1) / (t * t) \<le> 0"
      by (rule divide_nonpos_nonneg[OF num]) simp
    show "\<exists>y. DERIV q t :> y \<and> y \<le> 0"
      using d0 sgn unfolding q_def by blast
  qed
  have qpi: "q (pi / 2) = 2 / pi" by (simp add: q_def)
  have qz: "q z = sin z / z" by (simp add: q_def)
  from mono qpi qz have "2 / pi \<le> sin z / z" by simp
  from mult_right_mono[OF this less_imp_le[OF zpos]] have "2 / pi * z \<le> sin z / z * z" .
  moreover have "sin z / z * z = sin z" using False by simp
  ultimately show ?thesis by linarith
qed

lemma an_cis_pow:
  fixes g :: real and t :: nat
  shows "cis (2 * g) ^ t = cis (2 * g * real t)"
proof (induct t)
  case 0 then show ?case by simp
next
  case (Suc t)
  have "cis (2 * g) ^ Suc t = cis (2 * g * real t) * cis (2 * g)"
    using Suc by simp
  also have "\<dots> = cis (2 * g * real t + 2 * g)" by (simp add: cis_mult)
  also have "\<dots> = cis (2 * g * real (Suc t))" by (simp add: algebra_simps)
  finally show ?case .
qed

lemma an_norm_cis:
  fixes x :: real
  shows "cmod (cis (2 * x) - 1) ^ 2 = 4 * (sin x)^2"
proof -
  have pyth: "sin x ^ 2 + cos x ^ 2 = 1" by (rule sin_cos_squared_add)
  have a: "cmod (cis (2 * x) - 1) ^ 2 = (cos (2 * x) - 1)^2 + (sin (2 * x))^2"
    by (simp add: cmod_power2)
  have b: "(cos (2 * x) - 1)^2 + (sin (2 * x))^2 = 4 * sin x ^ 2 * (sin x ^ 2 + cos x ^ 2)"
    by (simp only: cos_double_sin sin_double) algebra
  have chain: "cmod (cis (2 * x) - 1) ^ 2 = 4 * sin x ^ 2 * (sin x ^ 2 + cos x ^ 2)"
    by (rule trans[OF a b])
  show ?thesis by (simp add: chain pyth)
qed

lemma an_geom:
  fixes g :: real and K :: nat
  shows "(cmod (\<Sum>t<K. cis (2 * g * real t)))^2 * (sin g)^2 = (sin (g * real K))^2"
proof -
  have geo: "(\<Sum>t<K. cis (2 * g) ^ t) * (cis (2 * g) - 1) = cis (2 * g) ^ K - 1"
    by (induct K) (simp_all add: algebra_simps)
  have sumeq: "(\<Sum>t<K. cis (2 * g) ^ t) = (\<Sum>t<K. cis (2 * g * real t))"
    by (simp add: an_cis_pow)
  have powK: "cis (2 * g) ^ K = cis (2 * (g * real K))"
    by (rule trans[OF an_cis_pow[of g K]]) (simp add: algebra_simps)
  have norm: "cmod (\<Sum>t<K. cis (2 * g * real t)) * cmod (cis (2 * g) - 1)
      = cmod (cis (2 * (g * real K)) - 1)"
  proof -
    have "cmod ((\<Sum>t<K. cis (2 * g) ^ t) * (cis (2 * g) - 1)) = cmod (cis (2 * g) ^ K - 1)"
      using geo by simp
    thus ?thesis by (simp add: norm_mult sumeq powK)
  qed
  have sq: "(cmod (\<Sum>t<K. cis (2 * g * real t)))^2 * (cmod (cis (2 * g) - 1))^2
      = (cmod (cis (2 * (g * real K)) - 1))^2"
    using arg_cong[OF norm, of "\<lambda>z::real. z^2"] by (simp add: power_mult_distrib)
  have e1: "cmod (cis (2 * g) - 1) ^ 2 = 4 * (sin g)^2" by (rule an_norm_cis)
  have e2: "cmod (cis (2 * (g * real K)) - 1) ^ 2 = 4 * (sin (g * real K))^2" by (rule an_norm_cis)
  have f1: "(cmod (\<Sum>t<K. cis (2 * g * real t)))^2 * (4 * sin g ^ 2) = (cmod (\<Sum>t<K. cis (2 * g * real t)))^2 * cmod (cis (2 * g) - 1) ^ 2"
    using e1 by simp
  have f2: "4 * sin (g * real K) ^ 2 = cmod (cis (2 * (g * real K)) - 1) ^ 2"
    using e2 by simp
  show ?thesis using sq f1 f2 by linarith
qed

lemma an_peak: fixes r N g :: real and K :: nat
  assumes "0 < r" "r < N" "N - r < real K * r" "real K * r < N + r" "\<bar>g\<bar> \<le> pi * r / (2 * N)"
  shows "4 / (pi^2 * r) * (1 - r / N)^3 * (N * real K) \<le> (cmod (\<Sum>t<K. cis (2 * g * real t)))^2"
  sorry


lemma pk_ceil:
  fixes X r :: nat assumes r: "0 < r" shows "\<exists>K. X \<le> r * K \<and> r * K < X + r"
proof -
  have dm: "r * (X div r) + X mod r = X" using div_mult_mod_eq[of X r] by (simp add: ac_simps)
  have sm: "X mod r < r" using r by simp
  show ?thesis
  proof (cases "X mod r = 0")
    case True
    then have "X = r * (X div r)" using dm by simp
    then show ?thesis using r by (intro exI[of _ "X div r"]) simp
  next
    case False
    then have s: "0 < X mod r" by simp
    have "r * (X div r + 1) = r * (X div r) + r" by (simp add: algebra_simps)
    then show ?thesis using dm sm s by (intro exI[of _ "X div r + 1"]) linarith
  qed
qed

lemma pk_enum:
  fixes N r x0 :: nat
  assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r"
  shows "\<exists>K. 0 < K \<and> {i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}
    \<and> N < K * r + r \<and> K * r < N + r"
proof -
  have hle: "x0 \<le> N" using rN x0 by linarith
  obtain X where hX: "N = x0 + X" using hle by (metis le_iff_add add.commute)
  obtain K where hK: "X \<le> r * K" "r * K < X + r" using pk_ceil[OF r, of X] by blast
  have K0: "0 < K"
  proof (rule ccontr)
    assume "\<not> 0 < K"
    then have "K = 0" by simp
    then show False using hK hX x0 rN by simp
  qed
  have hset: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
  proof (intro set_eqI)
    fix i
    show "i \<in> {i. i < N \<and> i mod r = x0} \<longleftrightarrow> i \<in> (\<lambda>t. x0 + r * t) ` {..<K}"
    proof
      assume h: "i \<in> {i. i < N \<and> i mod r = x0}"
      then have iN: "i < N" and imod: "i mod r = x0" by auto
      have dm: "r * (i div r) + i mod r = i" using div_mult_mod_eq[of i r] by (simp add: ac_simps)
      have "x0 + r * (i div r) = i" using dm imod by simp
      moreover have "i div r < K"
      proof (rule ccontr)
        assume "\<not> i div r < K"
        then have "K \<le> i div r" by simp
        then have "r * K \<le> r * (i div r)" by (rule mult_le_mono2)
        then show False using hK hX iN calculation by linarith
      qed
      ultimately show "i \<in> (\<lambda>t. x0 + r * t) ` {..<K}" by force
    next
      assume "i \<in> (\<lambda>t. x0 + r * t) ` {..<K}"
      then obtain t where ht: "t < K" and hi: "i = x0 + r * t" by auto
      have "r * (t + 1) \<le> r * K" using ht by (intro mult_le_mono2) simp
      then have "r * t < X" using hK by (simp add: algebra_simps)
      then have "i < N" using hi hX by linarith
      moreover have "i mod r = x0" using hi x0 by (simp add: mod_mult_self1)
      ultimately show "i \<in> {i. i < N \<and> i mod r = x0}" by simp
    qed
  qed
  have hK': "X \<le> K * r" "K * r < X + r" using hK by (simp_all add: mult.commute)
  have b1: "N < K * r + r" using hK' hX x0 by linarith
  have b2: "K * r < N + r" using hK' hX by linarith
  show ?thesis using K0 hset b1 b2 by blast
qed

lemma pk_sum:
  fixes N r x0 K :: nat and h :: "nat \<Rightarrow> complex"
  assumes r: "0 < r" and hs: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
  shows "(\<Sum>k<N. if k < N \<and> k mod r = x0 then h k else 0) = (\<Sum>t<K. h (x0 + r * t))"
proof -
  have inj: "inj_on (\<lambda>t. x0 + r * t) {..<K}"
    using r by (intro inj_onI) simp
  have s1: "(\<Sum>k<N. if k < N \<and> k mod r = x0 then h k else 0) = (\<Sum>k \<in> {k \<in> {..<N}. k < N \<and> k mod r = x0}. h k)"
    by (rule sym[OF sum.inter_filter[OF finite_lessThan]])
  have s2: "{k \<in> {..<N}. k < N \<and> k mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
    using hs by auto
  show ?thesis unfolding s1 s2 by (simp add: sum.reindex[OF inj] comp_def)
qed

lemma pk_card:
  fixes N r x0 K :: nat
  assumes r: "0 < r" and hs: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
  shows "card {i. i < N \<and> i mod r = x0} = K"
proof -
  have inj: "inj_on (\<lambda>t. x0 + r * t) {..<K}"
    using r by (intro inj_onI) simp
  show ?thesis using hs by (simp add: card_image[OF inj])
qed

lemma pk_ps:
  fixes N r x0 K :: nat
  assumes r: "0 < r" and hs: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
  shows "periodic_state N r x0 = (\<lambda>k. if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real K)) else 0)"
  unfolding periodic_state_def by (subst pk_card[OF r hs]) rule

lemma pk_is_state:
  fixes N r x0 K :: nat
  assumes r: "0 < r" and K0: "0 < K" and hs: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
  shows "is_state N (periodic_state N r x0)"
proof -
  have sq: "complex_of_real (1 / sqrt (real K)) * complex_of_real (1 / sqrt (real K)) = complex_of_real (1 / real K)"
  proof -
    have "(1 / sqrt (real K)) * (1 / sqrt (real K)) = 1 / real K"
      using K0 by (simp add: real_sqrt_mult_self)
    then show ?thesis by (simp only: of_real_mult[symmetric])
  qed
  have "inner N (periodic_state N r x0) (periodic_state N r x0) = (\<Sum>k<N. if k < N \<and> k mod r = x0 then complex_of_real (1 / real K) else 0)"
    unfolding inner_def pk_ps[OF r hs]
  proof (intro sum.cong refl)
    fix k
    have aux: "\<And>P c. cnj (if P then c else 0) * (if P then c else 0) = (if P then cnj c * c else 0)"
      by auto
    show "cnj (if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real K)) else 0)
        * (if k < N \<and> k mod r = x0 then complex_of_real (1 / sqrt (real K)) else 0)
        = (if k < N \<and> k mod r = x0 then complex_of_real (1 / real K) else 0)"
      by (simp only: aux complex_cnj_complex_of_real sq)
  qed
  also have "\<dots> = (\<Sum>t<K. complex_of_real (1 / real K))"
    using pk_sum[OF r hs, of "\<lambda>_. complex_of_real (1 / real K)"] by simp
  also have "\<dots> = 1"
    using K0 by (simp add: field_simps)
  finally show ?thesis unfolding is_state_def by simp
qed


lemma pk_hg:
  fixes N r x0 j t :: nat and c :: int and g :: real
  assumes N0: "0 < N" and g_def: "g = pi * (real j * real r - real_of_int c * real N) / real N"
  shows "cis (2 * pi * real j * real (x0 + r * t) / real N)
    = cis (2 * pi * real j * real x0 / real N) * cis (2 * g * real t)"
proof -
  have Nz: "real N \<noteq> 0" using N0 by simp
  have split: "2 * pi * real j * real (x0 + r * t) / real N
      = (2 * pi * real j * real x0 / real N + 2 * g * real t) + 2 * pi * (real_of_int c * real t)"
    unfolding g_def using Nz by (simp add: field_simps)
  have mem: "real_of_int c * real t \<in> \<int>"
  proof -
    have "real_of_int c * real t = real_of_int (c * int t)" by simp
    then show ?thesis by (simp only: Ints_of_int)
  qed
  have per: "cis (2 * pi * (real_of_int c * real t)) = 1"
    using cis_multiple_2pi[OF mem] by (simp add: algebra_simps)
  have F1: "cis ((2 * pi * real j * real x0 / real N + 2 * g * real t) + 2 * pi * (real_of_int c * real t))
      = cis (2 * pi * real j * real x0 / real N + 2 * g * real t) * cis (2 * pi * (real_of_int c * real t))"
    by (rule cis_mult[symmetric])
  have F2: "cis (2 * pi * real j * real x0 / real N + 2 * g * real t)
      = cis (2 * pi * real j * real x0 / real N) * cis (2 * g * real t)"
    by (rule cis_mult[symmetric])
  show ?thesis unfolding split using F1 F2 per by simp
qed


lemma pk_near:
  fixes j r N :: nat and c :: int
  assumes "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "2 * \<bar>real j * real r - real_of_int c * real N\<bar> \<le> real r"
proof -
  have E: "real_of_int (int j * int r - c * int N) = real j * real r - real_of_int c * real N"
    by (simp add: algebra_simps)
  have "real_of_int (2 * \<bar>int j * int r - c * int N\<bar>) \<le> real_of_int (int r)"
    using assms by (simp only: of_int_le_iff)
  then show ?thesis using E by (simp add: abs_mult abs_real_def) 
qed

lemma pk_prob:
  fixes N r x0 j K :: nat and g :: real
  assumes r: "0 < r" and N0: "0 < N" and K0: "0 < K"
    and hs: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
    and hg: "\<forall>t. cis (2 * pi * real j * real (x0 + r * t) / real N)
      = cis (2 * pi * real j * real x0 / real N) * cis (2 * g * real t)"
  shows "prob (qft N (periodic_state N r x0)) j = (cmod (\<Sum>t<K. cis (2 * g * real t)))^2 / (real N * real K)"
proof -
  let ?cc = "complex_of_real (1 / sqrt (real K))"
  let ?cN = "complex_of_real (sqrt (real N))"
  let ?a = "cis (2 * pi * real j * real x0 / real N)"
  let ?S = "\<Sum>t<K. cis (2 * g * real t)"
  have step1: "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = (\<Sum>t<K. cis (2 * pi * real j * real (x0 + r * t) / real N) * ?cc)"
  proof -
    have aux: "\<And>k. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k
        = (if k < N \<and> k mod r = x0 then cis (2 * pi * real j * real k / real N) * ?cc else 0)"
      using pk_ps[OF r hs] by auto
    have "(\<Sum>k<N. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
        = (\<Sum>k<N. if k < N \<and> k mod r = x0 then cis (2 * pi * real j * real k / real N) * ?cc else 0)"
      using aux by simp
    also have "\<dots> = (\<Sum>t<K. cis (2 * pi * real j * real (x0 + r * t) / real N) * ?cc)"
      using pk_sum[OF r hs, of "\<lambda>k. cis (2 * pi * real j * real k / real N) * ?cc"] by simp
    finally show ?thesis .
  qed
  have step2: "(\<Sum>t<K. cis (2 * pi * real j * real (x0 + r * t) / real N) * ?cc) = ?a * ?cc * ?S"
  proof -
    have "(\<Sum>t<K. cis (2 * pi * real j * real (x0 + r * t) / real N) * ?cc)
        = (\<Sum>t<K. ?a * ?cc * cis (2 * g * real t))"
      using hg by (intro sum.cong refl) (simp add: mult.commute mult.left_commute)
    also have "\<dots> = ?a * ?cc * ?S" by (simp add: sum_distrib_left)
    finally show ?thesis .
  qed
  have qeq: "qft N (periodic_state N r x0) j = ?a * ?cc * ?S / ?cN"
    unfolding qft_def using step1 step2 by simp
  have K2: "sqrt (real K) ^ 2 = real K" using K0 by simp
  have N2: "sqrt (real N) ^ 2 = real N" using N0 by simp
  have nrm: "cmod (qft N (periodic_state N r x0) j) = cmod ?S * (1 / sqrt (real K)) / sqrt (real N)"
  proof -
    have "cmod (?a * ?cc * ?S / ?cN) = cmod ?a * cmod ?cc * cmod ?S / cmod ?cN"
      by (simp add: norm_divide norm_mult)
    moreover have "cmod ?a = 1" by simp
    moreover have ccn: "cmod ?cc = 1 / sqrt (real K)" by (simp only: norm_of_real abs_of_nonneg[OF divide_nonneg_pos[OF zero_le_one]]) simp
    moreover have cNn: "cmod ?cN = sqrt (real N)" by (simp only: norm_of_real abs_of_nonneg[OF real_sqrt_ge_zero]) 
    ultimately show ?thesis using qeq by simp
  qed
  show ?thesis
    unfolding prob_def nrm
    by (simp add: power_divide power_mult_distrib K2 N2 field_simps)
qed

theorem shor_peak:
  assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r" and j: "j < N"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "is_state N (periodic_state N r x0) \<and>
    4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
proof -
  obtain K where K0: "0 < K" and hs: "{i. i < N \<and> i mod r = x0} = (\<lambda>t. x0 + r * t) ` {..<K}"
    and bK1: "N < K * r + r" and bK2: "K * r < N + r"
    using pk_enum[OF r rN x0] by blast
  have N0: "0 < N" using rN r by simp
  have Rn: "0 < real N" using N0 by simp
  define g where "g = pi * (real j * real r - real_of_int c * real N) / real N"
  have he: "2 * \<bar>real j * real r - real_of_int c * real N\<bar> \<le> real r"
    using pk_near[OF near] .
  have gbd: "\<bar>g\<bar> \<le> pi * real r / (2 * real N)"
  proof -
    have "\<bar>g\<bar> = pi * \<bar>real j * real r - real_of_int c * real N\<bar> / real N"
      unfolding g_def using Rn by (simp add: abs_divide abs_mult)
    also have "\<dots> = (pi * (2 * \<bar>real j * real r - real_of_int c * real N\<bar>)) / (2 * real N)"
      using Rn by (simp add: field_simps)
    also have "\<dots> \<le> (pi * real r) / (2 * real N)"
      using he Rn pi_gt_zero by (intro divide_right_mono mult_left_mono) auto
    finally show ?thesis by (simp add: algebra_simps)
  qed
  have c1: "real N < real K * real r + real r"
    using bK1 by (metis of_nat_add of_nat_less_iff of_nat_mult)
  have c2: "real K * real r < real N + real r"
    using bK2 by (metis of_nat_add of_nat_less_iff of_nat_mult)
  have an: "4 / (pi^2 * real r) * (1 - real r / real N)^3 * (real N * real K)
      \<le> (cmod (\<Sum>t<K. cis (2 * g * real t)))^2"
    using an_peak[where r="real r" and N="real N" and g=g and K=K] r rN c1 c2 gbd by (simp add: algebra_simps)
  have hg: "\<forall>t. cis (2 * pi * real j * real (x0 + r * t) / real N)
      = cis (2 * pi * real j * real x0 / real N) * cis (2 * g * real t)"
    by (intro allI) (rule pk_hg[OF N0 g_def])
  have prob_eq: "prob (qft N (periodic_state N r x0)) j = (cmod (\<Sum>t<K. cis (2 * g * real t)))^2 / (real N * real K)"
    by (rule pk_prob[OF r N0 K0 hs hg])
  have pos: "0 < real N * real K" using Rn K0 by simp
  have bound: "4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
    unfolding prob_eq by (rule iffD2[OF pos_le_divide_eq[OF pos]]) (rule an)
  show ?thesis using pk_is_state[OF r K0 hs] bound by blast
qed


(* Rounding of c*N/r: j = (2cN + r) div (2r). *)

lemma cnt_round:
  fixes N r c :: nat
  assumes r: "0 < r" and rN: "r < N" and c: "c < r"
  shows "2 * ((2 * c * N + r) div (2 * r)) * r \<le> 2 * c * N + r"
    and "2 * c * N + r < 2 * ((2 * c * N + r) div (2 * r)) * r + 2 * r"
    and "(2 * c * N + r) div (2 * r) < N"
proof -
  let ?q = "(2 * c * N + r) div (2 * r)"
  let ?s = "(2 * c * N + r) mod (2 * r)"
  have dm: "?q * (2 * r) + ?s = 2 * c * N + r"
    by (rule div_mult_mod_eq)
  have sl: "?s < 2 * r"
    using r by simp
  have e: "2 * ?q * r = ?q * (2 * r)"
    by (simp add: algebra_simps)
  show "2 * ?q * r \<le> 2 * c * N + r"
    using dm e by linarith
  show "2 * c * N + r < 2 * ?q * r + 2 * r"
    using dm e sl by linarith
  show "?q < N"
  proof (rule ccontr)
    assume "\<not> ?q < N"
    then have hN: "N \<le> ?q" by simp
    have h1: "N * (2 * r) \<le> ?q * (2 * r)"
      by (rule mult_right_mono[OF hN]) simp
    have c1: "c + 1 \<le> r" using c by simp
    have h2: "(c + 1) * N \<le> r * N"
      by (rule mult_right_mono[OF c1]) simp
    have h3: "(c + 1) * N = c * N + N"
      by (simp add: algebra_simps)
    have hup: "?q * (2 * r) \<le> 2 * c * N + r"
      using dm by linarith
    have "N * (2 * r) = 2 * (r * N)" by (simp add: algebra_simps)
    then show False using h1 h2 h3 hup rN by linarith
  qed
qed

lemma cnt_gap:
  fixes q c d N r :: nat
  assumes rN: "r < N" and cd: "c < d"
    and h1: "2 * q * r \<le> 2 * c * N + r"
    and h2: "2 * d * N + r < 2 * q * r + 2 * r"
  shows False
proof -
  have s1: "c + 1 \<le> d" using cd by simp
  have s2: "(c + 1) * N \<le> d * N"
    by (rule mult_right_mono[OF s1]) simp
  have s3: "(c + 1) * N = c * N + N"
    by (simp add: algebra_simps)
  show False using s2 s3 h1 h2 rN by linarith
qed

lemma cnt_int_aux:
  fixes x q R C NN :: int
  assumes hx: "x = q * R - C * NN"
    and i1: "2 * q * R \<le> 2 * C * NN + R" and i2: "2 * C * NN + R < 2 * q * R + 2 * R"
  shows "2 * \<bar>x\<bar> \<le> R"
proof -
  have c1: "2 * x \<le> R" using hx i1 by linarith
  have c3: "-(2 * x) \<le> R" using hx i2 by linarith
  have ab: "\<bar>2 * x\<bar> \<le> R"
    by (simp only: abs_le_iff) (rule conjI[OF c1 c3])
  have "\<bar>2 * x\<bar> = 2 * \<bar>x\<bar>"
    by (simp add: abs_mult)
  with ab show ?thesis by linarith
qed

lemma cnt_near:
  fixes N r c :: nat
  assumes r: "0 < r" and rN: "r < N" and c: "c < r"
  shows "2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int r - int c * int N\<bar> \<le> int r"
proof -
  have h1: "2 * ((2 * c * N + r) div (2 * r)) * r \<le> 2 * c * N + r"
    using cnt_round(1)[OF r rN c] .
  have h2: "2 * c * N + r < 2 * ((2 * c * N + r) div (2 * r)) * r + 2 * r"
    using cnt_round(2)[OF r rN c] .
  have i1a: "int (2 * ((2 * c * N + r) div (2 * r)) * r) \<le> int (2 * c * N + r)"
    by (rule iffD2[OF of_nat_le_iff h1])
  have i2a: "int (2 * c * N + r) < int (2 * ((2 * c * N + r) div (2 * r)) * r + 2 * r)"
    by (rule iffD2[OF of_nat_less_iff h2])
  have i1: "2 * int ((2 * c * N + r) div (2 * r)) * int r \<le> 2 * int c * int N + int r"
    using i1a by simp
  have i2: "2 * int c * int N + int r < 2 * int ((2 * c * N + r) div (2 * r)) * int r + 2 * int r"
    using i2a by simp
  show ?thesis
    using cnt_int_aux[OF refl i1 i2] .
qed

lemma cnt_core:
  fixes x y R B NN A C :: int
  assumes hR: "0 < R" and hRN: "R * R < NN" and hB: "0 < B" and hBR: "B < R"
    and key: "NN * (A * R - C * B) = B * x - R * y"
    and h1: "2 * \<bar>x\<bar> \<le> R" and h2: "2 * \<bar>y\<bar> \<le> B"
  shows "A * R = C * B"
proof -
  have hNN: "0 < NN" using hRN mult_pos_pos[OF hR hR] by linarith
  have hB0: "0 \<le> B" using hB by simp
  have hR0: "0 \<le> R" using hR by simp
  have hNN0: "0 \<le> NN" using hNN by simp
  have ex: "2 * \<bar>B * x\<bar> = B * (2 * \<bar>x\<bar>)"
    by (simp add: abs_mult abs_of_nonneg hB0 algebra_simps)
  have bx: "2 * \<bar>B * x\<bar> \<le> B * R"
    by (subst ex) (rule mult_left_mono[OF h1 hB0])
  have ey: "2 * \<bar>R * y\<bar> = R * (2 * \<bar>y\<bar>)"
    by (simp add: abs_mult abs_of_nonneg hR0 algebra_simps)
  have ry: "2 * \<bar>R * y\<bar> \<le> R * B"
    by (subst ey) (rule mult_left_mono[OF h2 hR0])
  have tri: "\<bar>B * x - R * y\<bar> \<le> \<bar>B * x\<bar> + \<bar>R * y\<bar>"
    by (rule abs_triangle_ineq4)
  have big0: "\<bar>B * x - R * y\<bar> \<le> B * R"
    using tri bx ry by (simp add: mult.commute)
  have absNN: "\<bar>NN * (A * R - C * B)\<bar> = NN * \<bar>A * R - C * B\<bar>"
    by (simp add: abs_mult abs_of_nonneg hNN0)
  have big: "NN * \<bar>A * R - C * B\<bar> \<le> B * R"
    using big0 key absNN by simp
  have BR: "B * R < NN"
  proof -
    have "B * R < R * R" using mult_strict_right_mono[OF hBR hR] by linarith
    then show ?thesis using hRN by linarith
  qed
  have lt1: "\<bar>A * R - C * B\<bar> < 1"
  proof (rule ccontr)
    assume "\<not> \<bar>A * R - C * B\<bar> < 1"
    then have h1': "1 \<le> \<bar>A * R - C * B\<bar>" by simp
    have "NN * 1 \<le> NN * \<bar>A * R - C * B\<bar>" by (rule mult_left_mono[OF h1' hNN0])
    then show False using big BR by simp
  qed
  have z12: "A * R - C * B < 1 \<and> -(A * R - C * B) < 1" using iffD1[OF abs_less_iff lt1] .
  have z3: "A * R - C * B \<le> 0" using z12 by linarith
  have z4: "0 \<le> A * R - C * B" using z12 by linarith
  show ?thesis using z3 z4 by linarith
qed

lemma cnt_recover:
  fixes N r c :: nat
  assumes r: "0 < r" and rr: "r * r < N" and c: "c < r" and cop: "coprime c r"
  shows "recover N ((2 * c * N + r) div (2 * r)) = r"
proof -
  have r1: "1 * r \<le> r * r" using mult_right_mono[of 1 r r] r by simp
  have rN: "r < N" using rr r1 by linarith
  have near: "2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int r - int c * int N\<bar> \<le> int r"
    using cnt_near[OF r rN c] .
  have wit: "0 < r \<and> (\<exists>a::int. 2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int r - a * int N\<bar> \<le> int r)"
    using r near by blast
  have minimal: "\<And>b. 0 < b \<and> (\<exists>a::int. 2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int b - a * int N\<bar> \<le> int b) \<Longrightarrow> r \<le> b"
  proof -
    fix b :: nat
    assume hb: "0 < b \<and> (\<exists>a::int. 2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int b - a * int N\<bar> \<le> int b)"
    then obtain a where b0: "0 < b"
      and ha: "2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int b - a * int N\<bar> \<le> int b"
      by blast
    show "r \<le> b"
    proof (rule ccontr)
      assume "\<not> r \<le> b"
      then have brr: "b < r" by simp
      have rr0: "int (r * r) < int N" by (rule iffD2[OF of_nat_less_iff rr])
      have rr': "int r * int r < int N" using rr0 by simp
      have hR: "0 < int r" using r by simp
      have hB: "0 < int b" using b0 by simp
      have hBR: "int b < int r" using brr by simp
      have key: "int N * (a * int r - int c * int b)
          = int b * (int ((2 * c * N + r) div (2 * r)) * int r - int c * int N)
            - int r * (int ((2 * c * N + r) div (2 * r)) * int b - a * int N)"
        by (simp add: algebra_simps)
      have core: "a * int r = int c * int b"
        using cnt_core[OF hR rr' hB hBR key near ha] by linarith
      have core': "int c * int b = int r * a"
        by (metis core mult.commute)
      have dvdz: "int r dvd int (c * b)"
      proof (rule dvdI[where k=a])
        show "int (c * b) = int r * a" using core' by simp
      qed
      have dvdn: "r dvd c * b"
        by (rule iffD1[OF int_dvd_int_iff dvdz])
      have cr: "coprime r c" using cop by (simp add: coprime_commute)
      have rb: "r dvd b"
        by (rule iffD1[OF coprime_dvd_mult_right_iff[OF cr] dvdn])
      have "r \<le> b" using rb b0 by (rule dvd_imp_le)
      then show False using brr by simp
    qed
  qed
  have lsv: "(LEAST b. 0 < b \<and> (\<exists>a::int. 2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int b - a * int N\<bar> \<le> int b)) = r"
  proof (rule Least_equality)
    show "0 < r \<and> (\<exists>a::int. 2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int r - a * int N\<bar> \<le> int r)"
      using wit .
  next
    fix y :: nat
    assume "0 < y \<and> (\<exists>a::int. 2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int y - a * int N\<bar> \<le> int y)"
    then show "r \<le> y" using minimal by blast
  qed
  show ?thesis unfolding recover_def using lsv .
qed

theorem shor_general_success:
  assumes r: "0 < r" and rr: "r * r < N" and x0: "x0 < r"
  shows "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
    \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
proof -
  have r1: "1 * r \<le> r * r" using mult_right_mono[of 1 r r] r by simp
  have rN: "r < N" using rr r1 by linarith
  have Cfin: "finite {c. c < r \<and> coprime c r}"
    by (rule finite_subset[of _ "{..<r}"]) auto
  have Sfin: "finite {j. j < N \<and> recover N j = r}"
    by (rule finite_subset[of _ "{..<N}"]) auto
  have bound: "\<And>c. c \<in> {c. c < r \<and> coprime c r} \<Longrightarrow>
      4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3
        \<le> prob (qft N (periodic_state N r x0)) ((2 * c * N + r) div (2 * r))"
  proof -
    fix c :: nat
    assume hc: "c \<in> {c. c < r \<and> coprime c r}"
    then have c: "c < r" by simp
    have jN: "(2 * c * N + r) div (2 * r) < N" using cnt_round(3)[OF r rN c] .
    have near: "2 * \<bar>int ((2 * c * N + r) div (2 * r)) * int r - int c * int N\<bar> \<le> int r"
      using cnt_near[OF r rN c] .
    have pk: "is_state N (periodic_state N r x0) \<and>
        4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3
          \<le> prob (qft N (periodic_state N r x0)) ((2 * c * N + r) div (2 * r))"
      using shor_peak[OF r rN x0 jN near] .
    show "4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3
        \<le> prob (qft N (periodic_state N r x0)) ((2 * c * N + r) div (2 * r))"
      using pk by simp
  qed
  have inj: "inj_on (\<lambda>c. (2 * c * N + r) div (2 * r)) {c. c < r \<and> coprime c r}"
  proof (rule inj_onI)
    fix c d :: nat
    assume hc: "c \<in> {c. c < r \<and> coprime c r}" and hd: "d \<in> {c. c < r \<and> coprime c r}"
      and eq: "(2 * c * N + r) div (2 * r) = (2 * d * N + r) div (2 * r)"
    have c: "c < r" using hc by simp
    have d: "d < r" using hd by simp
    have c1: "2 * ((2 * c * N + r) div (2 * r)) * r \<le> 2 * c * N + r"
      using cnt_round(1)[OF r rN c] .
    have c2: "2 * c * N + r < 2 * ((2 * c * N + r) div (2 * r)) * r + 2 * r"
      using cnt_round(2)[OF r rN c] .
    have d1: "2 * ((2 * d * N + r) div (2 * r)) * r \<le> 2 * d * N + r"
      using cnt_round(1)[OF r rN d] .
    have d2: "2 * d * N + r < 2 * ((2 * d * N + r) div (2 * r)) * r + 2 * r"
      using cnt_round(2)[OF r rN d] .
    have d1': "2 * ((2 * c * N + r) div (2 * r)) * r \<le> 2 * d * N + r"
      using d1 eq by simp
    have d2': "2 * d * N + r < 2 * ((2 * c * N + r) div (2 * r)) * r + 2 * r"
      using d2 eq by simp
    show "c = d"
    proof (rule ccontr)
      assume ne: "c \<noteq> d"
      show False
      proof (cases "c < d")
        case True
        show False by (rule cnt_gap[OF rN True c1 d2'])
      next
        case False
        then have dc: "d < c" using ne by simp
        show False by (rule cnt_gap[OF rN dc d1' c2])
      qed
    qed
  qed
  have img: "(\<lambda>c. (2 * c * N + r) div (2 * r)) ` {c. c < r \<and> coprime c r}
      \<subseteq> {j. j < N \<and> recover N j = r}"
  proof (rule subsetI)
    fix j :: nat
    assume "j \<in> (\<lambda>c. (2 * c * N + r) div (2 * r)) ` {c. c < r \<and> coprime c r}"
    then obtain c where hc: "c < r \<and> coprime c r" and hj: "j = (2 * c * N + r) div (2 * r)"
      by blast
    have "j < N" using hj cnt_round(3)[OF r rN hc[THEN conjunct1]] by simp
    moreover have "recover N j = r"
      using hj cnt_recover[OF r rr hc[THEN conjunct1] hc[THEN conjunct2]] by simp
    ultimately show "j \<in> {j. j < N \<and> recover N j = r}" by simp
  qed
  have pnn: "\<And>j. 0 \<le> prob (qft N (periodic_state N r x0)) j"
    by (simp add: prob_def)
  have eqc: "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
      = (\<Sum>c \<in> {c. c < r \<and> coprime c r}. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3)"
  proof -
    have pz: "pi \<noteq> 0" using pi_gt_zero by simp
    have rz: "real r \<noteq> 0" using r by simp
    have Nz: "real N \<noteq> 0" using rN r by simp
    show ?thesis by (simp add: sum_constant field_simps pz rz Nz)
  qed
  show ?thesis
  proof -
    have "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
        = (\<Sum>c \<in> {c. c < r \<and> coprime c r}. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3)"
      using eqc .
    also have "\<dots> \<le> (\<Sum>c \<in> {c. c < r \<and> coprime c r}.
        prob (qft N (periodic_state N r x0)) ((2 * c * N + r) div (2 * r)))"
      by (rule sum_mono) (rule bound)
    also have "\<dots> = (\<Sum>j \<in> (\<lambda>c. (2 * c * N + r) div (2 * r)) ` {c. c < r \<and> coprime c r}.
        prob (qft N (periodic_state N r x0)) j)"
      by (simp add: sum.reindex[OF inj] comp_def)
    also have "\<dots> \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
      by (rule sum_mono2[OF Sfin img]) (simp add: prob_def)
    finally show ?thesis .
  qed
qed


end
