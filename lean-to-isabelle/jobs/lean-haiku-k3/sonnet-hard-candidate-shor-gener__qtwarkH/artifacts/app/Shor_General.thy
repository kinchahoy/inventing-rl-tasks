theory Shor_General imports Quantum_Basics
begin
text \<open>Pure number theory behind the classical step: if \<open>y(y+2) \<equiv> 0\<close> mod \<open>n\<close>, and
  \<open>y+1\<close> is neither \<open>1\<close> nor \<open>n-1\<close> mod \<open>n\<close>, then \<open>gcd y n\<close> is a nontrivial factor of \<open>n\<close>.\<close>
lemma sf_core: fixes n y :: nat assumes n: "1 < n" and dv: "n dvd y * (y + 2)"
    and ne1: "(y + 1) mod n \<noteq> 1" and nem1: "(y + 1) mod n \<noteq> n - 1"
  shows "1 < gcd y n \<and> gcd y n < n"
proof - have npos: "0 < n" using n by simp have gpos: "0 < gcd y n" using npos by simp
  have gle: "gcd y n \<le> n" using npos by (intro dvd_imp_le) auto
  have g1: "gcd y n \<noteq> 1"
  proof assume g1: "gcd y n = 1" have cop: "coprime n y" using g1 gcd.commute[of n y] by (metis coprime_iff_gcd_eq_1 One_nat_def)
    have dvd2: "n dvd y + 2" using dv cop by (metis coprime_dvd_mult_right_iff dvd_mult_left dvd_mult_right dvd_mult mult.commute)
    then obtain q where q: "y + 2 = n * q" by blast
    then obtain q' where q': "q = q' + 1" by (cases q) auto
    have key: "y + 2 = n * q' + n" using q q' by (simp add: algebra_simps)
    obtain t where t: "t = n * q'" by blast
    then have key': "y + 2 = t + n" using key by simp
    have e: "y + 1 = (n - 1) + t" using key' n by linarith
    have "(y + 1) mod n = n - 1"
    proof - have "(y + 1) mod n = ((n - 1) + n * q') mod n" using e t by simp also have "\<dots> = (n - 1) mod n"
        by (simp add: mod_mult_self1)
      also have "\<dots> = n - 1" using n by (intro mod_less) simp
      finally show ?thesis .
    qed
    with nem1 show False by contradiction
  qed
  have g2: "gcd y n \<noteq> n"
  proof assume gn: "gcd y n = n" have "n dvd y" using gn by (metis gcd_dvd1) then obtain k where k: "y = n * k" by blast
    have m1: "(1 + k * n) mod n = 1 mod n" by (rule mod_mult_self1)
    have m2: "1 mod n = 1" by (rule mod_less[OF n])
    have yk: "y + 1 = 1 + k * n" using k by (simp add: mult.commute)
    have "(y + 1) mod n = 1" using yk m1 m2 by simp
    with ne1 show False by contradiction
  qed
  show ?thesis using gpos g1 g2 gle by linarith
qed
theorem shor_factor: assumes n: "1 < n" and ord: "is_order n a r" and even: "even r" and not_minus_one: "a ^ (r div 2) mod n \<noteq> n - 1"
  shows "1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n"
proof -
  have ord': "0 < r \<and> a ^ r mod n = 1 \<and> (\<forall>k. 0 < k \<longrightarrow> k < r \<longrightarrow> a ^ k mod n \<noteq> 1)"
    using ord unfolding is_order_def by blast
  then have hr: "0 < r" and har: "a ^ r mod n = 1"
    and hmin: "\<forall>k. 0 < k \<longrightarrow> k < r \<longrightarrow> a ^ k mod n \<noteq> 1"
    by blast+
  obtain s where hs: "r = 2 * s" using even by (auto elim: evenE)
  have hsr: "r div 2 = s" using hs by simp
  have hs0: "0 < s" using hr hs by simp
  have hsr2: "s < r" using hs0 hs by simp
  have ha0: "a \<noteq> 0"
  proof assume "a = 0" then have "a ^ r = 0" using hr by (simp add: zero_power) with har show False by simp
  qed
  have ha1: "0 < a" using ha0 by simp
  have hpos: "0 < a ^ s" using ha1 by (rule zero_less_power)
  have hy0: "a ^ s = (a ^ s - 1) + 1" using hpos by simp
  obtain y where hy': "y = a ^ s - 1" by blast
  have hy: "a ^ s = y + 1" using hy0 hy' by simp
  have hsq: "a ^ r = (y + 1) * (y + 1)"
  proof - have "a ^ r = a ^ s * a ^ s" by (simp add: hs mult_2 power_add) then show ?thesis using hy by simp
  qed
  have dv: "n dvd y * (y + 2)"
  proof - have dm: "n * (a ^ r div n) + a ^ r mod n = a ^ r" by (simp add: mult.commute div_mult_mod_eq)
    have e: "(y + 1) * (y + 1) = y * (y + 2) + 1" by (simp add: algebra_simps)
    have "y * (y + 2) = n * (a ^ r div n)" using dm har hsq e by linarith
    then show ?thesis unfolding dvd_def by blast
  qed
  have ne1: "(y + 1) mod n \<noteq> 1"
  proof - have "a ^ s mod n \<noteq> 1" using hmin hs0 hsr2 by blast then show ?thesis using hy by simp
  qed
  have nem1: "(y + 1) mod n \<noteq> n - 1"
  proof - have "a ^ s mod n \<noteq> n - 1" using not_minus_one hsr by simp then show ?thesis using hy by simp
  qed
  have ymain: "a ^ (r div 2) - 1 = y" using hsr hy hy' by simp
  show ?thesis using sf_core[OF n dv ne1 nem1] ymain by simp
qed
lemma jd_u: fixes t :: real assumes t0: "0 \<le> t" and tpi: "t \<le> pi" shows "t * cos t \<le> sin t"
proof - have der: "\<And>x::real. DERIV (\<lambda>x::real. sin x - x * cos x) x :> cos x - (1 * cos x + - sin x * x)" proof - fix x :: real
    show "DERIV (\<lambda>x::real. sin x - x * cos x) x :> cos x - (1 * cos x + - sin x * x)"
      by (rule DERIV_diff[OF DERIV_sin DERIV_mult[OF DERIV_ident DERIV_cos]])
  qed
  have step: "\<And>x::real. 0 \<le> x \<Longrightarrow> x \<le> t \<Longrightarrow>
      \<exists>y. DERIV (\<lambda>x::real. sin x - x * cos x) x :> y \<and> 0 \<le> y"
  proof - fix x :: real assume "0 \<le> x" "x \<le> t" then have "0 \<le> x * sin x"
      using tpi sin_ge_zero[of x] by (auto intro!: mult_nonneg_nonneg)
    moreover have "cos x - (1 * cos x + - sin x * x) = x * sin x" by algebra
    ultimately show "\<exists>y. DERIV (\<lambda>x::real. sin x - x * cos x) x :> y \<and> 0 \<le> y" using der[of x] by metis
  qed
  have "(\<lambda>x::real. sin x - x * cos x) 0 \<le> (\<lambda>x::real. sin x - x * cos x) t"
    by (rule DERIV_nonneg_imp_nondecreasing[OF t0 step])
  then show ?thesis by simp
qed
lemma jd_half: fixes t :: real assumes t0: "0 < t" and tpi: "t \<le> pi / 2" shows "2 / pi * t \<le> sin t"
proof - have der: "\<And>x::real. x \<noteq> 0 \<Longrightarrow> DERIV (\<lambda>x::real. sin x / x) x :> (cos x * x - sin x * 1) / (x * x)"
  proof - fix x :: real assume hx: "x \<noteq> 0" show "DERIV (\<lambda>x::real. sin x / x) x :> (cos x * x - sin x * 1) / (x * x)"
      by (rule DERIV_divide[OF DERIV_sin DERIV_ident hx])
  qed
  have step: "\<And>x::real. t \<le> x \<Longrightarrow> x \<le> pi / 2 \<Longrightarrow>
      \<exists>y. DERIV (\<lambda>x::real. sin x / x) x :> y \<and> y \<le> 0"
  proof - fix x :: real assume "t \<le> x" "x \<le> pi / 2" then have x0: "0 < x" using t0 by simp
    have "x * cos x \<le> sin x" using jd_u[of x] x0 \<open>x \<le> pi / 2\<close> by linarith
    then have num: "cos x * x - sin x * 1 \<le> 0" by (simp add: mult.commute)
    have "(cos x * x - sin x * 1) / (x * x) \<le> 0" using divide_nonpos_pos[OF num] mult_pos_pos[OF x0 x0] by simp
    then show "\<exists>y. DERIV (\<lambda>x::real. sin x / x) x :> y \<and> y \<le> 0" using der[of x] x0 by blast
  qed
  have "(\<lambda>x::real. sin x / x) (pi / 2) \<le> (\<lambda>x::real. sin x / x) t" by (rule DERIV_nonpos_imp_nonincreasing[OF tpi step])
  then have h: "2 / pi \<le> sin t / t" using t0 by simp
  show ?thesis using h t0 by (simp add: pos_le_divide_eq field_simps)
qed
lemma jd_bound: fixes t s :: real assumes s0: "0 \<le> s" and st: "s \<le> t" and sp: "s \<le> pi - t" and tpi: "t \<le> pi"
  shows "2 / pi * s \<le> sin t"
proof (cases "t \<le> pi / 2") case pos: True have "2 / pi * t \<le> sin t" proof (cases "t = 0") case True then show ?thesis by simp next
    case nz: False
    then have "0 < t" using st s0 by linarith
    then show ?thesis using jd_half[OF _ pos] by simp
  qed
  moreover have "2 / pi * s \<le> 2 / pi * t" using st by (intro mult_left_mono) auto
  ultimately show ?thesis by linarith
next case neg: False have "2 / pi * s \<le> 2 / pi * (pi - t)" using sp by (intro mult_left_mono) auto
  moreover have "2 / pi * (pi - t) \<le> sin (pi - t)"
  proof (cases "pi - t = 0") case True then show ?thesis by simp
  next case nz: False have h1: "0 < pi - t" using tpi nz by linarith have h2: "pi - t \<le> pi / 2" using neg by linarith
    show ?thesis using jd_half[OF h1 h2] by simp
  qed
  ultimately show ?thesis by simp
qed
lemma dl_geom: fixes z :: complex shows "(\<Sum>m<L. z ^ m) * (z - 1) = z ^ L - 1" by (induct L) (simp_all add: algebra_simps)
lemma dl_cis_pow: "cis x ^ n = cis (real n * x)" by (induct n) (simp_all add: cis_mult algebra_simps)
lemma dl_re_cis: "Re (cis x) = cos x" using cos_n_Re_cis_pow_n[of 1 x] by simp
lemma dl_im_cis: "Im (cis x) = sin x" using sin_n_Im_cis_pow_n[of 1 x] by simp
lemma dl_cis_minus1: "cmod (cis x - 1) = 2 * \<bar>sin (x / 2)\<bar>"
proof - have hc: "cos x = 1 - 2 * sin (x / 2) ^ 2" using cos_double_sin[of "x / 2"] by simp have hs: "sin x = 2 * sin (x / 2) * cos (x / 2)"
    using sin_double[of "x / 2"] by simp
  have pyth: "sin (x / 2) ^ 2 + cos (x / 2) ^ 2 = 1" by simp
  have e: "(cos x - 1) ^ 2 + (sin x) ^ 2 = (2 * sin (x / 2)) ^ 2 * (sin (x / 2) ^ 2 + cos (x / 2) ^ 2)" by (simp only: hc hs) algebra
  have sq: "(cmod (cis x - 1))\<^sup>2 = (2 * sin (x / 2))\<^sup>2" using e pyth by (simp add: cmod_power2 dl_re_cis dl_im_cis)
  have "cmod (cis x - 1) = \<bar>2 * sin (x / 2)\<bar>" by (rule power2_eq_imp_eq[OF _ norm_ge_zero abs_ge_zero]) (simp add: sq abs_power2)
  then show ?thesis by (simp add: abs_mult)
qed
lemma dl_abs_sin: assumes hx: "\<bar>x\<bar> \<le> pi" shows "\<bar>sin x\<bar> = sin \<bar>x\<bar>"
proof - have h0: "0 \<le> sin \<bar>x\<bar>" using sin_ge_zero[of "\<bar>x\<bar>"] hx by simp show ?thesis proof (cases "0 \<le> x")
    case True
    have xp: "x \<le> pi" using hx True by (simp add: abs_of_nonneg)
    show ?thesis by (simp add: abs_of_nonneg True sin_ge_zero[OF True xp])
  next case False then have ax: "\<bar>x\<bar> = - x" by simp have e: "sin x = - sin \<bar>x\<bar>" using ax by simp
    show ?thesis using h0 by (simp add: e)
  qed
qed
lemma dl_cancel: fixes a b c :: real assumes h: "a * c \<le> b * c" and c: "0 < c" shows "a \<le> b"
proof (rule ccontr) assume "\<not> a \<le> b" then have "b < a" by simp then have "b * c < a * c" using c by (rule mult_strict_right_mono)
  then show False using h by linarith
qed
lemma dir_lower: fixes N r L :: nat and d :: int assumes r: "0 < r" and rN: "r < N" and L1: "L * r \<le> N + r" and L2: "N \<le> L * r + r"
    and d: "2 * \<bar>d\<bar> \<le> int r"
  shows "2 / pi * (real N - real r) / real r \<le> cmod (\<Sum>m \<in> {..<L}. cis (2 * pi * real_of_int d * real m / real N))"
proof - have r0: "(0::real) < real r" using r by simp have rN0: "(real r :: real) < real N" using rN by simp
  have N0: "(0::real) < real N" using r0 rN0 by linarith
  have pipos: "(0::real) < pi" by simp
  have L1R: "real L * real r \<le> real N + real r" using L1 by (metis of_nat_add of_nat_le_iff of_nat_mult)
  have L2R: "real N \<le> real L * real r + real r" using L2 by (metis of_nat_add of_nat_le_iff of_nat_mult)
  have L0: "(0::real) \<le> real L" by simp
  obtain A where Adef: "A = (real N - real r) / real r" by blast
  have Ahalf: "2 / pi * (real N - real r) / real r = 2 / pi * A" using Adef by (simp add: field_simps)
  have A0: "0 \<le> A" using rN0 r0 by (auto simp: Adef intro!: divide_nonneg_nonneg)
  have AL: "A \<le> real L" unfolding Adef by (subst pos_divide_le_eq[OF r0]) (use L2R in linarith)
  have hAr: "A * real r = real N - real r" using r0 by (simp add: Adef)
  have hpi2: "2 / pi \<le> 1" by (subst pos_divide_le_eq[OF pipos]) (use pi_ge_two in linarith)
  have main: "2 / pi * A \<le> cmod (\<Sum>m \<in> {..<L}. cis (2 * pi * real_of_int d * real m / real N))"
  proof (cases "d = 0") case True have "(\<Sum>m \<in> {..<L}. cis (2 * pi * real_of_int d * real m / real N)) = (\<Sum>m \<in> {..<L}. 1)"
      using True by simp
    then have "cmod (\<Sum>m \<in> {..<L}. cis (2 * pi * real_of_int d * real m / real N)) = real L" by simp
    moreover have "2 / pi * A \<le> 1 * A" using A0 hpi2 by (intro mult_right_mono) auto
    ultimately show ?thesis using AL by linarith
  next case False obtain phi where phidef: "phi = pi * real_of_int d / real N" by blast obtain p where pdef: "p = \<bar>phi\<bar>" by blast
    have dR0: "(real_of_int d :: real) \<noteq> 0" using False by simp
    have dR: "2 * \<bar>(real_of_int d :: real)\<bar> \<le> real r"
    proof - have "2 * \<bar>(real_of_int d :: real)\<bar> = real_of_int (2 * \<bar>d\<bar>)" by simp
      also have "\<dots> \<le> real_of_int (int r)" using d by (intro of_int_le_iff[THEN iffD2]) simp
      finally show ?thesis by simp
    qed
    have phiN: "p * real N = pi * \<bar>(real_of_int d :: real)\<bar>" using N0 by (simp add: pdef phidef abs_divide abs_mult field_simps)
    have hp2: "2 * p * real N \<le> pi * real r"
    proof - have "2 * p * real N = pi * (2 * \<bar>(real_of_int d :: real)\<bar>)" using phiN by algebra
      also have "\<dots> \<le> pi * real r" using dR pipos by (intro mult_left_mono) auto
      finally show ?thesis .
    qed
    have phi0: "phi \<noteq> 0" using dR0 N0 by (simp add: phidef)
    have p0: "0 < p" using phi0 by (simp add: pdef)
    have ppi2: "p < pi / 2"
    proof - have h1: "pi * real r < pi * real N" using rN0 pipos by (intro mult_strict_left_mono) auto
      have h2: "2 * p * real N < pi * real N" using hp2 h1 by linarith
      have h3: "2 * p < pi"
      proof (rule ccontr) assume "\<not> 2 * p < pi" then have "pi \<le> 2 * p" by simp
        then have "pi * real N \<le> 2 * p * real N" using N0 by (intro mult_right_mono) auto
        then show False using h2 by linarith
      qed
      show ?thesis using h3 by linarith
    qed
    have hpi_gt: "p < pi" using ppi2 pipos by linarith
    have sinp: "0 < sin p" using p0 hpi_gt by (intro sin_gt_zero) auto
    have hphi: "\<bar>phi\<bar> \<le> pi" using pdef hpi_gt by simp
    have sf: "\<bar>sin phi\<bar> = sin p" using dl_abs_sin[OF hphi] pdef by simp
    obtain t where tdef: "t = real L * p" by blast
    have t0: "0 \<le> t" using tdef p0 L0 by simp
    have tpi: "t \<le> pi"
    proof - have e1: "real L * (2 * p * real N) \<le> real L * (pi * real r)" using hp2 L0 by (intro mult_left_mono) auto
      have e2: "pi * (real L * real r) \<le> pi * (real N + real r)" using L1R pipos by (intro mult_left_mono) auto
      have e3: "pi * (real N + real r) \<le> pi * (2 * real N)" using rN0 pipos by (intro mult_left_mono) auto
      have "t * (2 * real N) = real L * (2 * p * real N)" using tdef by algebra
      also have "\<dots> \<le> real L * (pi * real r)" using e1 by simp
      also have "\<dots> = pi * (real L * real r)" by algebra
      also have "\<dots> \<le> pi * (real N + real r)" using e2 by simp
      also have "\<dots> \<le> pi * (2 * real N)" using e3 by simp
      finally have tbound: "t * (2 * real N) \<le> pi * (2 * real N)" .
      have N2: "(0::real) < 2 * real N" using N0 by simp
      show ?thesis using dl_cancel[OF tbound N2] .
    qed
    have Lphi: "\<bar>real L * phi\<bar> = t" using tdef pdef L0 by (simp add: abs_mult)
    have hLphi: "\<bar>real L * phi\<bar> \<le> pi" using Lphi tpi by simp
    have sinL: "\<bar>sin (real L * phi)\<bar> = sin t" using dl_abs_sin[OF hLphi] Lphi by simp
    obtain G where Gdef: "G = (\<Sum>m<L. cis (2 * phi) ^ m)" by blast
    have hsum: "(\<Sum>m \<in> {..<L}. cis (2 * pi * real_of_int d * real m / real N)) = G"
      unfolding Gdef by (rule sum.cong[OF refl]) (simp add: dl_cis_pow phidef field_simps)
    have hgeo: "G * (cis (2 * phi) - 1) = cis (2 * phi) ^ L - 1" unfolding Gdef by (rule dl_geom)
    have hz1: "cmod (cis (2 * phi) - 1) = 2 * \<bar>sin phi\<bar>" using dl_cis_minus1[of "2 * phi"] by simp
    have hzL: "cmod (cis (2 * phi) ^ L - 1) = 2 * \<bar>sin (real L * phi)\<bar>"
    proof - have "cis (2 * phi) ^ L = cis (real L * (2 * phi))" by (rule dl_cis_pow)
      then have "cmod (cis (2 * phi) ^ L - 1) = cmod (cis (real L * (2 * phi)) - 1)" by simp
      also have "\<dots> = 2 * \<bar>sin (real L * (2 * phi) / 2)\<bar>" using dl_cis_minus1 by blast
      also have "\<dots> = 2 * \<bar>sin (real L * phi)\<bar>" by (simp add: field_simps)
      finally show ?thesis .
    qed
    have hn: "cmod G * (2 * \<bar>sin phi\<bar>) = 2 * \<bar>sin (real L * phi)\<bar>"
    proof - have "cmod G * cmod (cis (2 * phi) - 1) = cmod (G * (cis (2 * phi) - 1))" by (simp add: norm_mult)
      also have "\<dots> = cmod (cis (2 * phi) ^ L - 1)" using hgeo by simp
      also have "\<dots> = 2 * \<bar>sin (real L * phi)\<bar>" using hzL by simp
      finally show ?thesis using hz1 by simp
    qed
    have hn2: "cmod G * sin p = sin t"
    proof - have "2 * (cmod G * sin p) = 2 * sin t" using hn sf sinL by algebra thus ?thesis by linarith
    qed
    have s0: "0 \<le> A * p" using A0 p0 by simp
    have st: "A * p \<le> t"
    proof - have "A * p \<le> real L * p" using AL p0 by (intro mult_right_mono) auto then show ?thesis using tdef by simp
    qed
    have hAL: "(A + real L) * p * real r \<le> pi * real r"
    proof - have "(A + real L) * p * real r = (A * real r + real L * real r) * p" by algebra
      also have "\<dots> = (real N - real r + real L * real r) * p" using hAr by simp
      also have "\<dots> \<le> (2 * real N) * p" using L1R p0 by (intro mult_right_mono) auto
      also have "\<dots> = 2 * p * real N" by algebra
      also have "\<dots> \<le> pi * real r" using hp2 by simp
      finally show ?thesis .
    qed
    have hAL2: "(A + real L) * p \<le> pi" using dl_cancel[OF hAL r0] .
    have sp': "A * p \<le> pi - t"
    proof - have "(A + real L) * p = A * p + t" using tdef by algebra thus ?thesis using hAL2 by linarith
    qed
    have jd: "2 / pi * (A * p) \<le> sin t" by (rule jd_bound[OF s0 st sp' tpi])
    have hsinp_le: "sin p \<le> p" using p0 by (intro sin_x_le_x) auto
    have hnn: "0 \<le> 2 / pi * A" using A0 pipos by (intro mult_nonneg_nonneg) auto
    have h1: "2 / pi * A * sin p \<le> 2 / pi * A * p" using hsinp_le hnn by (intro mult_left_mono) auto
    have h2: "2 / pi * A * p = 2 / pi * (A * p)" by algebra
    have h3: "2 / pi * A * sin p \<le> cmod G * sin p" using h1 h2 jd hn2 by linarith
    have "2 / pi * A \<le> cmod G" using dl_cancel[OF h3 sinp] .
    thus ?thesis using hsum by simp
  qed
  show ?thesis using Ahalf main by linarith
qed
lemma pk_le_div: fixes m M r :: nat assumes r: "0 < r" shows "m \<le> M div r \<longleftrightarrow> m * r \<le> M"
proof - have hdm: "M div r * r + M mod r = M" using div_mult_mod_eq[of M r] by simp
  have hmod: "M mod r < r" by (rule mod_less_divisor[OF r])
  show ?thesis
  proof assume h: "m \<le> M div r" then have "m * r \<le> M div r * r" using mult_right_mono[of m "M div r" r] by simp
    then show "m * r \<le> M" using hdm by linarith
  next assume h: "m * r \<le> M" show "m \<le> M div r" proof (rule ccontr) assume "\<not> m \<le> M div r"
      then have "M div r + 1 \<le> m" by simp
      then have "(M div r + 1) * r \<le> m * r" using mult_right_mono[of "M div r + 1" m r] by simp
      then have "M div r * r + r \<le> m * r" by (simp add: distrib_right)
      then show False using hdm hmod h by linarith
    qed
  qed
qed
lemma pk_residue: assumes r: "0 < r" and x0: "x0 < r" and xN: "x0 < N"
  shows "\<exists>K. 0 < K \<and> {i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<K}
    \<and> card {i. i < N \<and> i mod r = x0} = K \<and> K * r \<le> N + r \<and> N \<le> K * r + r"
proof - have hM0: "N = x0 + (N - x0 - 1) + 1" using xN by arith obtain M where hM: "N = x0 + M + 1" using hM0 by blast
  define K where "K = M div r + 1"
  have r0: "r \<noteq> 0" using r by simp
  have hdm: "M div r * r + M mod r = M" using div_mult_mod_eq[of M r] by simp
  have hmod: "M mod r < r" by (rule mod_less_divisor[OF r])
  have hdivle: "M div r * r \<le> M" using hdm by linarith
  have hset: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<K}"
  proof (rule set_eqI) fix i show "i \<in> {i. i < N \<and> i mod r = x0} \<longleftrightarrow> i \<in> (\<lambda>m. x0 + m * r) ` {..<K}"
    proof assume hi: "i \<in> {i. i < N \<and> i mod r = x0}" then have iN: "i < N" and im: "i mod r = x0" by auto
      have h1: "i div r * r + x0 = i" using div_mult_mod_eq[of i r] im by simp
      have h2: "i div r * r \<le> M" using h1 iN hM by linarith
      have h3: "i div r \<le> M div r" using h2 pk_le_div[OF r, of "i div r" M] by blast
      show "i \<in> (\<lambda>m. x0 + m * r) ` {..<K}"
        using h1 h3 unfolding K_def by (intro image_eqI[of _ _ "i div r"]) (auto simp: mult.commute)
    next assume "i \<in> (\<lambda>m. x0 + m * r) ` {..<K}" then obtain m where hm: "m < K" and him: "i = x0 + m * r" by auto
      have h2: "m \<le> M div r" using hm unfolding K_def by simp
      have h3: "m * r \<le> M" using h2 pk_le_div[OF r, of m M] by blast
      show "i \<in> {i. i < N \<and> i mod r = x0}" using him h3 hM x0 by (auto simp: mod_mult_self1 mod_less[OF x0])
    qed
  qed
  have inj: "inj_on (\<lambda>m. x0 + m * r) {..<K}"
  proof (rule inj_onI) fix m m' assume "m \<in> {..<K}" "m' \<in> {..<K}" and eq: "x0 + m * r = x0 + m' * r"
    then have "m * r = m' * r" by simp
    then show "m = m'" using r0 by simp
  qed
  have card_eq: "card {i. i < N \<and> i mod r = x0} = K" unfolding hset by (simp add: card_image[OF inj])
  have Kr_eq: "K * r = M div r * r + r" unfolding K_def by (simp add: distrib_right)
  have KR: "K * r \<le> N + r" using Kr_eq hdivle hM by linarith
  have NK: "N \<le> K * r + r"
  proof - have "M < K * r" using Kr_eq hdm hmod by linarith then show ?thesis using hM x0 r by linarith
  qed
  show ?thesis using hset card_eq KR NK by (intro exI[of _ K]) (simp add: K_def)
qed
lemma pk_is_state: assumes r: "0 < r" and x0: "x0 < r" and xN: "x0 < N" shows "is_state N (periodic_state N r x0)"
proof - obtain K where hK: "0 < K \<and> {i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<K}
    \<and> card {i. i < N \<and> i mod r = x0} = K \<and> K * r \<le> N + r \<and> N \<le> K * r + r"
    using pk_residue[OF r x0 xN] by blast
  have hK0: "0 < K" and hcard: "card {i. i < N \<and> i mod r = x0} = K" using hK by auto
  have hKR: "(0::real) < K" using hK0 by simp
  have hs: "sqrt (real K) * sqrt (real K) = real K" by (simp add: real_sqrt_mult_self)
  have aa: "1 / sqrt (real K) * (1 / sqrt (real K)) = (1 / real K)" by (simp add: times_divide_times_eq hs)
  have hv: "\<forall>k. cnj (periodic_state N r x0 k) * periodic_state N r x0 k
      = (if k \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / real K) else 0)"
  proof fix k show "cnj (periodic_state N r x0 k) * periodic_state N r x0 k
      = (if k \<in> {i. i < N \<and> i mod r = x0} then complex_of_real (1 / real K) else 0)"
    proof (cases "k < N \<and> k mod r = x0") case True then have v: "periodic_state N r x0 k = complex_of_real (1 / sqrt (real K))"
        by (simp add: periodic_state_def hcard)
      have mem: "k \<in> {i. i < N \<and> i mod r = x0}" using True by simp
      show ?thesis using mem v by (simp only: mem v if_True complex_cnj_complex_of_real of_real_mult[symmetric] aa)
    next assume hk: "\<not> (k < N \<and> k mod r = x0)" then have v: "periodic_state N r x0 k = 0" by (simp add: periodic_state_def hk)
      have nmem: "k \<notin> {i. i < N \<and> i mod r = x0}" using hk by simp
      show ?thesis using nmem v by (simp only: v nmem if_False complex_cnj_zero mult_zero_left)
    qed
  qed
  define S where "S = {i. i < N \<and> i mod r = x0}"
  have fin: "finite S" unfolding S_def by (rule finite_subset[of _ "{..<N}"]) auto
  have inner_eq: "inner N (periodic_state N r x0) (periodic_state N r x0)
      = (\<Sum>i \<in> {..<N}. if i \<in> S then complex_of_real (1 / real K) else 0)"
    unfolding inner_def S_def by (simp add: hv)
  have restr: "(\<Sum>i \<in> {..<N}. if i \<in> S then complex_of_real (1 / real K) else 0)
      = (\<Sum>i \<in> S. complex_of_real (1 / real K))"
  proof -
    have "(\<Sum>i \<in> {..<N} \<inter> S. complex_of_real (1 / real K)) = (\<Sum>i \<in> {..<N}. if i \<in> S then complex_of_real (1 / real K) else 0)"
      by (rule sum.inter_restrict) simp
    moreover have "{..<N} \<inter> S = S" unfolding S_def by auto
    ultimately show ?thesis by simp
  qed
  have cS: "card S = K" using hcard unfolding S_def by simp
  have hKc: "(of_nat K :: complex) \<noteq> 0" using hK0 by simp
  have "inner N (periodic_state N r x0) (periodic_state N r x0) = (\<Sum>i \<in> S. complex_of_real (1 / real K))"
    using inner_eq restr by simp
  also have "\<dots> = of_nat (card S) * complex_of_real (1 / real K)" by simp
  also have "\<dots> = 1" using cS hKc by (simp add: cS)
  finally show ?thesis unfolding is_state_def .
qed
lemma pk_cis_shift: fixes x :: real and k :: int shows "cis (x + 2 * pi * real_of_int k) = cis x"
proof - have "cis (2 * pi * real_of_int k) = 1" by (rule cis_multiple_2pi) simp then show ?thesis by (subst cis_mult[symmetric]) simp
qed
lemma pk_qft_norm: fixes N r x0 K j :: nat and c :: int assumes r: "0 < r" and x0: "x0 < r" and xN: "x0 < N" and K0: "0 < K"
    and hset: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<K}"
    and hcard: "card {i. i < N \<and> i mod r = x0} = K"
  shows "cmod (qft N (periodic_state N r x0) j)
    = cmod (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N))
      / (sqrt (real K) * sqrt (real N))"
proof - define S where "S = {i. i < N \<and> i mod r = x0}" have hN0: "(real N) \<noteq> 0" using xN by simp
  define cc where "cc = complex_of_real (1 / sqrt (real K))"
  define th0 where "th0 = 2 * pi * real j * real x0 / real N"
  have hv: "\<forall>k. periodic_state N r x0 k = (if k \<in> S then cc else 0)" by (auto simp: periodic_state_def hcard S_def cc_def)
  have phase: "\<And>m. cis (2 * pi * real j * real (x0 + m * r) / real N)
      = cis th0 * cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N)"
  proof - fix m :: nat have e: "2 * pi * real j * real (x0 + m * r) / real N
        = (th0 + 2 * pi * real_of_int (int j * int r - c * int N) * real m / real N) + 2 * pi * real_of_int (c * int m)"
      proof - have c1: "real_of_int (int j * int r - c * int N) = real j * real r - real_of_int c * real N" by simp
        have c2: "real_of_int (c * int m) = real_of_int c * real m" by simp
        have c3: "real (x0 + m * r) = real x0 + real m * real r" by simp
        show ?thesis unfolding th0_def c1 c2 c3 using hN0 by (simp add: field_simps)
      qed
    show "cis (2 * pi * real j * real (x0 + m * r) / real N)
        = cis th0 * cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N)"
      by (subst e) (simp only: pk_cis_shift cis_mult)
  qed
  have s1: "(\<Sum>k \<in> {..<N}. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = (\<Sum>k \<in> {..<N}. if k \<in> S then cis (2 * pi * real j * real k / real N) * cc else 0)"
    by (intro sum.cong refl) (auto simp: hv)
  have hint: "{..<N} \<inter> S = S" unfolding S_def by auto
  have s2: "(\<Sum>k \<in> {..<N}. if k \<in> S then cis (2 * pi * real j * real k / real N) * cc else 0)
      = (\<Sum>k \<in> S. cis (2 * pi * real j * real k / real N) * cc)"
  proof - have "(\<Sum>k \<in> {..<N} \<inter> S. cis (2 * pi * real j * real k / real N) * cc)
        = (\<Sum>k \<in> {..<N}. if k \<in> S then cis (2 * pi * real j * real k / real N) * cc else 0)"
      by (rule sum.inter_restrict) simp
    then show ?thesis using hint by simp
  qed
  have s3: "S = (\<lambda>m. x0 + m * r) ` {..<K}" unfolding S_def by (rule hset)
  have inj: "inj_on (\<lambda>m. x0 + m * r) {..<K}"
  proof (rule inj_onI) fix m m' assume "m \<in> {..<K}" "m' \<in> {..<K}" and eq: "x0 + m * r = x0 + m' * r"
    then have "m * r = m' * r" by simp
    then show "m = m'" using r by simp
  qed
  have s4: "(\<Sum>k \<in> (\<lambda>m. x0 + m * r) ` {..<K}. cis (2 * pi * real j * real k / real N) * cc)
      = (\<Sum>m \<in> {..<K}. cis (2 * pi * real j * real (x0 + m * r) / real N) * cc)"
    by (subst sum.reindex[OF inj]) (simp add: comp_def)
  have sumS: "(\<Sum>k \<in> {..<N}. cis (2 * pi * real j * real k / real N) * periodic_state N r x0 k)
      = (\<Sum>m \<in> {..<K}. cc * cis (2 * pi * real j * real (x0 + m * r) / real N))"
    using s1 s2 s4 by (simp add: s3 mult.commute)
  have phase2: "\<And>m. cc * cis (2 * pi * real j * real (x0 + m * r) / real N)
      = cc * cis th0 * cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N)"
    by (subst phase) (simp add: mult.assoc)
  have sumG: "(\<Sum>m \<in> {..<K}. cc * cis (2 * pi * real j * real (x0 + m * r) / real N))
      = cc * cis th0 * (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N))"
  proof - have "(\<Sum>m \<in> {..<K}. cc * cis (2 * pi * real j * real (x0 + m * r) / real N))
        = (\<Sum>m \<in> {..<K}. (cc * cis th0) * cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N))"
      by (rule sum.cong[OF refl]) (rule phase2)
    also have "\<dots> = cc * cis th0 * (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N))"
      by (subst sum_distrib_left) simp
    finally show ?thesis .
  qed
  have qft_eq: "qft N (periodic_state N r x0) j
      = (cc * cis th0 * (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N)))
        / complex_of_real (sqrt (real N))"
    unfolding qft_def using sumS sumG by (simp add: th0_def)
  have hnc: "cmod cc = 1 / sqrt (real K)"
  proof - have h0: "0 \<le> 1 / sqrt (real K)" by simp show ?thesis unfolding cc_def by (simp only: norm_of_real abs_of_nonneg[OF h0])
  qed
  have hsN: "cmod (complex_of_real (sqrt (real N))) = sqrt (real N)" by (simp only: norm_of_real abs_of_nonneg[OF real_sqrt_ge_zero])
  show ?thesis unfolding qft_eq norm_divide norm_mult hsN hnc norm_cis by (simp add: field_simps)
qed
lemma pk_final: fixes N r L g :: real assumes hr: "0 < r" and rN: "r < N" and hL: "0 < L" and L1: "L * r \<le> N + r"
    and hg: "2 / pi * (N - r) / r \<le> g"
  shows "4 / (pi ^ 2 * r) * (1 - r / N) ^ 3 \<le> g ^ 2 / (L * N)"
proof - have hN: "0 < N" using hr rN by linarith have hpi: "0 < pi" by simp have hNr: "0 \<le> N - r" using rN by linarith
  have p2: "0 \<le> 2 / pi" using hpi by simp
  have a0: "0 \<le> 2 / pi * (N - r) / r" using p2 hNr hr by (intro divide_nonneg_nonneg mult_nonneg_nonneg) (simp_all add: less_imp_le)
  have gg: "(2 / pi * (N - r) / r) ^ 2 \<le> g ^ 2" using a0 hg by (intro power_mono) auto
  have r0: "r \<noteq> 0" using hr by simp
  have N0: "N \<noteq> 0" using hN by simp
  have pi0: "pi \<noteq> 0" using hpi by simp
  have e1: "4 / (pi ^ 2 * r) * (1 - r / N) ^ 3 = 4 * (N - r) ^ 3 / (pi ^ 2 * r * N ^ 3)" using r0 N0 by (simp add: field_simps)
  have e2: "(2 / pi * (N - r) / r) ^ 2 / (L * N) = 4 * (N - r) ^ 2 / (pi ^ 2 * r ^ 2 * (L * N))"
    using r0 N0 pi0 hL by (simp add: field_simps power_divide) algebra
  have key: "(N - r) * (L * r) \<le> N ^ 2"
  proof - have k1: "(N - r) * (L * r) \<le> (N - r) * (N + r)" using L1 hNr by (intro mult_left_mono) (simp_all add: mult.commute)
    have k2: "(N - r) * (N + r) = N * N - r * r" by (simp add: algebra_simps)
    have k3: "0 \<le> r * r" using hr by (intro mult_nonneg_nonneg) (simp_all add: less_imp_le)
    show ?thesis using k1 k2 k3 power2_eq_square[of N] by linarith
  qed
  have pos1: "0 < pi ^ 2 * r * N ^ 3" using hpi hr hN by (intro mult_pos_pos) auto
  have pos2: "0 < pi ^ 2 * r ^ 2 * (L * N)" using hpi hr hL hN by (intro mult_pos_pos) auto
  have step: "4 * (N - r) ^ 3 / (pi ^ 2 * r * N ^ 3) \<le> 4 * (N - r) ^ 2 / (pi ^ 2 * r ^ 2 * (L * N))"
  proof - have nn: "0 \<le> 4 * (N - r) ^ 2 * (pi ^ 2 * r * N) * (N ^ 2 - (N - r) * (L * r))"
      using key hr hN by (intro mult_nonneg_nonneg) (auto intro!: mult_nonneg_nonneg)
    have eq: "4 * (N - r) ^ 2 * (pi ^ 2 * r * N ^ 3) - 4 * (N - r) ^ 3 * (pi ^ 2 * r ^ 2 * (L * N))
        = 4 * (N - r) ^ 2 * (pi ^ 2 * r * N) * (N ^ 2 - (N - r) * (L * r))"
      by (simp add: algebra_simps power2_eq_square power3_eq_cube)
    have ineq: "4 * (N - r) ^ 3 * (pi ^ 2 * r ^ 2 * (L * N)) \<le> 4 * (N - r) ^ 2 * (pi ^ 2 * r * N ^ 3)" using eq nn by linarith
    have hB: "pi ^ 2 * r * N ^ 3 \<noteq> 0" using pos1 by (rule less_imp_neq[THEN not_sym])
    have hD: "pi ^ 2 * r ^ 2 * (L * N) \<noteq> 0" using pos2 by (rule less_imp_neq[THEN not_sym])
    have hz: "4 * (N - r) ^ 3 * (pi ^ 2 * r ^ 2 * (L * N)) - 4 * (N - r) ^ 2 * (pi ^ 2 * r * N ^ 3) \<le> 0" using ineq by linarith
    have hz2: "(4 * (N - r) ^ 3 * (pi ^ 2 * r ^ 2 * (L * N)) - 4 * (N - r) ^ 2 * (pi ^ 2 * r * N ^ 3))
        / ((pi ^ 2 * r * N ^ 3) * (pi ^ 2 * r ^ 2 * (L * N))) \<le> 0"
      by (rule divide_nonpos_pos[OF hz mult_pos_pos[OF pos1 pos2]])
    show ?thesis by (subst frac_le_eq[OF hB hD]) (rule hz2)
  qed
  have LN: "0 < L * N" using hL hN by simp
  have "4 / (pi ^ 2 * r) * (1 - r / N) ^ 3 \<le> (2 / pi * (N - r) / r) ^ 2 / (L * N)" using step e1 e2 by simp
  also have "\<dots> \<le> g ^ 2 / (L * N)" using gg LN by (intro divide_right_mono) auto
  finally show ?thesis .
qed
theorem shor_peak: assumes r: "0 < r" and rN: "r < N" and x0: "x0 < r" and j: "j < N"
    and near: "2 * \<bar>int j * int r - c * int N\<bar> \<le> int r"
  shows "is_state N (periodic_state N r x0) \<and>
    4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j"
proof - have x0N: "x0 < N" using x0 rN by simp have st: "is_state N (periodic_state N r x0)" using pk_is_state[OF r x0 x0N] .
  obtain K where hK: "0 < K \<and> {i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<K}
    \<and> card {i. i < N \<and> i mod r = x0} = K \<and> K * r \<le> N + r \<and> N \<le> K * r + r"
    using pk_residue[OF r x0 x0N] by blast
  have K0: "0 < K" and hset: "{i. i < N \<and> i mod r = x0} = (\<lambda>m. x0 + m * r) ` {..<K}"
    and hcard: "card {i. i < N \<and> i mod r = x0} = K" and L1: "K * r \<le> N + r" and L2: "N \<le> K * r + r"
    using hK by auto
  have amp: "cmod (qft N (periodic_state N r x0) j)
    = cmod (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N))
      / (sqrt (real K) * sqrt (real N))"
    using pk_qft_norm[OF r x0 x0N K0 hset hcard] .
  have lower: "2 / pi * (real N - real r) / real r
      \<le> cmod (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N))"
    using dir_lower[OF r rN L1 L2 near] .
  have Kr: "(0::real) < K" using K0 by simp
  have Nr: "(0::real) < N" using rN r by simp
  have L1r: "real K * real r \<le> real N + real r" using L1 by (simp flip: of_nat_mult of_nat_add)
  have prob_eq: "prob (qft N (periodic_state N r x0)) j
      = cmod (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N)) ^ 2 / (real K * real N)"
  proof - have h1: "prob (qft N (periodic_state N r x0)) j = cmod (qft N (periodic_state N r x0) j) ^ 2" by (simp add: prob_def)
    have h2: "cmod (qft N (periodic_state N r x0) j) ^ 2 = cmod (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N)) ^ 2
        / ((sqrt (real K)) ^ 2 * (sqrt (real N)) ^ 2)"
      using amp by (simp add: power_divide power_mult_distrib)
    have h3: "(sqrt (real K)) ^ 2 * (sqrt (real N)) ^ 2 = real K * real N" by (simp add: real_sqrt_pow2)
    show ?thesis using h1 h2 h3 by simp
  qed
  have fin: "4 / (pi ^ 2 * real r) * (1 - real r / real N) ^ 3
      \<le> cmod (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N)) ^ 2 / (real K * real N)"
    using pk_final[of "real r" "real N" "real K" "cmod (\<Sum>m \<in> {..<K}. cis (2 * pi * real_of_int (int j * int r - c * int N) * real m / real N))"]
      r rN Kr L1r lower by simp
  show ?thesis using st fin prob_eq by simp
qed
lemma sg_bounds1:  fixes y r :: int assumes h: "2 * \<bar>y\<bar> \<le> r" shows "- r \<le> 2 * y"
proof - have "- y \<le> \<bar>y\<bar>" by (rule abs_ge_minus_self) thus ?thesis using h by linarith
qed
lemma sg_bounds2: fixes y r :: int assumes h: "2 * \<bar>y\<bar> \<le> r" shows "2 * y \<le> r"
proof - have "y \<le> \<bar>y\<bar>" by (rule abs_ge_self) thus ?thesis using h by linarith
qed
lemma sg_recover_period: assumes r: "0 < r" and rr: "r * r < N" and cop: "coprime c r"
    and near: "2 * \<bar>int j * int r - int c * int N\<bar> \<le> int r"
  shows "recover N j = r"
proof - have hr0: "(0::int) \<le> int r" by simp have rr': "int r * int r < int N" using rr by (simp flip: of_nat_mult)
  have rN_nat: "r < N" using rr le_square[of r] by linarith
  have rN: "int r < int N" using rN_nat by simp
  have least: "(LEAST b::nat. 0 < b \<and> (\<exists>a::int. 2 * \<bar>int j * int b - a * int N\<bar> \<le> int b)) = r"
  proof (rule Least_equality) show "0 < r \<and> (\<exists>a::int. 2 * \<bar>int j * int r - a * int N\<bar> \<le> int r)"
      using r near by auto
  next fix b :: nat assume hb: "0 < b \<and> (\<exists>a::int. 2 * \<bar>int j * int b - a * int N\<bar> \<le> int b)"
    then obtain a where hb0: "0 < b" and ha: "2 * \<bar>int j * int b - a * int N\<bar> \<le> int b" by blast
    show "r \<le> b"
    proof (rule ccontr) assume "\<not> r \<le> b" then have hbr: "b < r" by simp have hb0R: "(0::int) \<le> int b" by simp
      obtain X where X_def: "X = int j * int b - a * int N" by blast
      obtain Y where Y_def: "Y = int j * int r - int c * int N" by blast
      have ha': "2 * \<bar>X\<bar> \<le> int b" using ha by (simp add: X_def)
      have near': "2 * \<bar>Y\<bar> \<le> int r" using near by (simp add: Y_def)
      have key: "int r * X - int b * Y = int N * (int b * int c - a * int r)" by (simp add: X_def Y_def algebra_simps)
      have hX1: "- int b \<le> 2 * X" using sg_bounds1[OF ha'] .
      have hX2: "2 * X \<le> int b" using sg_bounds2[OF ha'] .
      have hY1: "- int r \<le> 2 * Y" using sg_bounds1[OF near'] .
      have hY2: "2 * Y \<le> int r" using sg_bounds2[OF near'] .
      have m1: "int r * (2 * X) \<le> int r * int b" by (rule mult_left_mono[OF hX2 hr0])
      have m2: "int r * (- int b) \<le> int r * (2 * X)" by (rule mult_left_mono[OF hX1 hr0])
      have m3: "int b * (2 * Y) \<le> int b * int r" by (rule mult_left_mono[OF hY2 hb0R])
      have m4: "int b * (- int r) \<le> int b * (2 * Y)" by (rule mult_left_mono[OF hY1 hb0R])
      have hT: "\<bar>int N * (int b * int c - a * int r)\<bar> \<le> int r * int b"
      proof - have "int N * (int b * int c - a * int r) \<le> int r * int b" using key m1 m4 by (simp add: algebra_simps)
        moreover have "- (int r * int b) \<le> int N * (int b * int c - a * int r)" using key m2 m3 by (simp add: algebra_simps)
        ultimately show ?thesis by simp
      qed
      have hlt: "int r * int b < int N"
      proof - have hbr': "int b \<le> int r" using hbr by simp
        have "int r * int b \<le> int r * int r" by (rule mult_left_mono[OF hbr' hr0])
        thus ?thesis using rr' by linarith
      qed
      have hN0: "(0::int) < int N" using rN hr0 by linarith
      have hN0le: "(0::int) \<le> int N" using hN0 by simp
      have T1: "int b * int c - a * int r < 1"
      proof (rule ccontr) assume "\<not> (int b * int c - a * int r < 1)" then have "1 \<le> int b * int c - a * int r" by simp
        from mult_left_mono[OF this hN0le] have "int N * 1 \<le> int N * (int b * int c - a * int r)" .
        moreover have "int N * (int b * int c - a * int r) \<le> int r * int b" using abs_le_D1[OF hT] by linarith
        ultimately show False using hlt by linarith
      qed
      have T2: "-1 < int b * int c - a * int r"
      proof (rule ccontr) assume "\<not> (-1 < int b * int c - a * int r)" then have "int b * int c - a * int r \<le> -1" by simp
        from mult_left_mono[OF this hN0le] have "int N * (int b * int c - a * int r) \<le> int N * (-1)" .
        moreover have "- (int r * int b) \<le> int N * (int b * int c - a * int r)" using abs_le_D2[OF hT] by linarith
        ultimately show False using hlt by linarith
      qed
      have zero_of_small: "\<forall>t::int. -1 < t \<longrightarrow> t < 1 \<longrightarrow> t = 0" by (intro allI impI) simp
      have T0: "int b * int c - a * int r = 0" using zero_of_small T1 T2 by (meson)
      have heq: "int b * int c = a * int r" using T0 by linarith
      have dvd_int: "int r dvd int b * int c" using heq by (simp add: mult.commute)
      have dvd_nat: "r dvd b * c" using dvd_int by (simp flip: of_nat_mult)
      have cop': "coprime r c" using cop by (simp add: coprime_commute)
      have rdvd_b: "r dvd b" using cop' dvd_nat by (simp add: coprime_dvd_mult_left_iff)
      have "r \<le> b" using rdvd_b hb0 by (rule Nat.dvd_imp_le)
      thus False using hbr by simp
    qed
  qed
  show ?thesis by (simp add: recover_def least)
qed
definition sg_jc :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where "sg_jc N r c = (2 * c * N + r) div (2 * r)"
lemma sg_near_lin: fixes X P U s r :: int assumes h1: "2 * U + r = 2 * P + s" and hs: "0 \<le> s" and hs2: "s < 2 * r" and hX: "X = P - U"
  shows "2 * \<bar>X\<bar> \<le> r"
proof (cases "0 \<le> X") case True hence "\<bar>X\<bar> = X" by simp thus ?thesis using h1 hs hX by linarith
next case False hence "\<bar>X\<bar> = -X" by simp thus ?thesis using h1 hs2 hX by linarith
qed
lemma sg_jc_near_aux: assumes e: "2 * c * N + r = q * (2 * r) + s" and s_lt: "s < 2 * r"
  shows "2 * \<bar>int q * int r - int c * int N\<bar> \<le> int r"
proof - have e0: "int (2 * c * N + r) = int (q * (2 * r) + s)" using e by simp
  have e1: "2 * (int c * int N) + int r = 2 * (int q * int r) + int s" using e0 by (simp add: algebra_simps)
  have s_int: "int s < 2 * int r" using s_lt by linarith
  have s_nn: "(0::int) \<le> int s" by simp
  have fin: "2 * \<bar>int q * int r - int c * int N\<bar> \<le> int r" using sg_near_lin[OF e1 s_nn s_int refl] .
  show ?thesis using fin .
qed
lemma sg_jc_near: assumes r: "0 < r" shows "2 * \<bar>int (sg_jc N r c) * int r - int c * int N\<bar> \<le> int r"
proof - have e: "2 * c * N + r = sg_jc N r c * (2 * r) + (2 * c * N + r) mod (2 * r)" by (simp add: sg_jc_def div_mult_mod_eq)
  have pos: "0 < 2 * r" using r by simp
  have s_lt: "(2 * c * N + r) mod (2 * r) < 2 * r" by (rule mod_less_divisor[OF pos])
  show ?thesis using sg_jc_near_aux[OF e s_lt] .
qed
lemma sg_jc_lt: assumes hc: "c < r" and rN: "r < N" shows "sg_jc N r c < N"
proof - have hc1: "c + 1 \<le> r" using hc by simp have c1: "(c + 1) * N \<le> r * N" by (rule mult_right_mono[OF hc1]) simp
  have bound: "2 * c * N + r < N * (2 * r)" using c1 rN by (simp add: algebra_simps)
  have eq: "2 * c * N + r = sg_jc N r c * (2 * r) + (2 * c * N + r) mod (2 * r)" by (simp add: sg_jc_def div_mult_mod_eq)
  show ?thesis
  proof (rule ccontr) assume "\<not> sg_jc N r c < N" hence hq: "N \<le> sg_jc N r c" by simp
    have "N * (2 * r) \<le> sg_jc N r c * (2 * r)" by (rule mult_right_mono[OF hq]) simp
    thus False using bound eq by linarith
  qed
qed
lemma sg_lin: fixes P U V r :: int assumes B1: "- r \<le> 2 * (P - V)" and A2: "2 * (P - U) \<le> r" and A1: "- r \<le> 2 * (P - U)"
    and B2: "2 * (P - V) \<le> r" and hr0: "0 \<le> r"
  shows "- r \<le> U - V \<and> U - V \<le> r"
proof - have l: "- r \<le> U - V" using B1 A1 A2 B2 hr0 by presburger have u: "U - V \<le> r" using B1 A1 A2 B2 hr0 by presburger
  show ?thesis by (rule conjI[OF l u])
qed
lemma sg_int_aux: fixes Q r c c' N :: int assumes A1: "- r \<le> 2 * (Q * r - c * N)" and A2: "2 * (Q * r - c * N) \<le> r"
    and B1: "- r \<le> 2 * (Q * r - c' * N)" and B2: "2 * (Q * r - c' * N) \<le> r"
    and rN: "r < N" and hN0: "0 \<le> N" and hr0: "0 \<le> r"
  shows "c = c'"
proof - have lin: "- r \<le> c * N - c' * N \<and> c * N - c' * N \<le> r" using sg_lin[OF B1 A2 A1 B2 hr0] .
  have lo: "- r \<le> c * N - c' * N" using lin by simp
  have hi: "c * N - c' * N \<le> r" using lin by simp
  have e: "(c - c') * N = c * N - c' * N" by (simp add: algebra_simps)
  have D1: "c - c' < 1"
  proof (rule ccontr) assume "\<not> (c - c' < 1)" then have "1 \<le> c - c'" by simp
    hence hm: "1 * N \<le> (c - c') * N" using mult_right_mono[of 1 "c - c'" N] hN0 by simp
    thus False using hi e rN by linarith
  qed
  have D2: "-1 < c - c'"
  proof (rule ccontr) assume "\<not> (-1 < c - c')" then have "c - c' \<le> -1" by simp
    hence hm: "(c - c') * N \<le> -1 * N" using mult_right_mono[of "c - c'" "-1" N] hN0 by simp
    thus False using lo e rN by linarith
  qed
  show ?thesis using D1 D2 by linarith
qed
lemma sg_jc_inj: assumes r: "0 < r" and rr: "r * r < N" and eq: "sg_jc N r c = sg_jc N r c'" shows "c = c'"
proof - have rN_nat: "r < N" using rr le_square[of r] by linarith have rN: "int r < int N" using rN_nat by simp
  have hN0: "(0::int) \<le> int N" by simp
  have h1: "2 * \<bar>int (sg_jc N r c) * int r - int c * int N\<bar> \<le> int r" by (rule sg_jc_near[OF r])
  have h2: "2 * \<bar>int (sg_jc N r c') * int r - int c' * int N\<bar> \<le> int r" by (rule sg_jc_near[OF r])
  have h1': "2 * \<bar>int (sg_jc N r c') * int r - int c * int N\<bar> \<le> int r" using h1 eq by simp
  have A1: "- int r \<le> 2 * (int (sg_jc N r c') * int r - int c * int N)" using sg_bounds1[OF h1'] .
  have A2: "2 * (int (sg_jc N r c') * int r - int c * int N) \<le> int r" using sg_bounds2[OF h1'] .
  have B1: "- int r \<le> 2 * (int (sg_jc N r c') * int r - int c' * int N)" using sg_bounds1[OF h2] .
  have B2: "2 * (int (sg_jc N r c') * int r - int c' * int N) \<le> int r" using sg_bounds2[OF h2] .
  have hr0: "(0::int) \<le> int r" by simp
  have hz: "int c = int c'" using sg_int_aux A1 A2 B1 B2 rN hN0 hr0 .
  show ?thesis using hz by simp
qed
theorem shor_general_success: assumes r: "0 < r" and rr: "r * r < N" and x0: "x0 < r"
  shows "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
    \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
proof - have rN_nat: "r < N" using rr le_square[of r] by linarith have fin_S: "finite {j. j < N \<and> recover N j = r}"
    by (rule finite_subset[of _ "{..<N}"]) auto
  have img_sub: "sg_jc N r ` {c. c < r \<and> coprime c r} \<subseteq> {j. j < N \<and> recover N j = r}"
  proof (rule subsetI) fix j assume "j \<in> sg_jc N r ` {c. c < r \<and> coprime c r}"
    then obtain c where hc: "c < r" and cop: "coprime c r" and hj: "j = sg_jc N r c" by blast
    have "sg_jc N r c < N" using sg_jc_lt[OF hc rN_nat] .
    moreover have "recover N (sg_jc N r c) = r" using sg_recover_period[OF r rr cop sg_jc_near[OF r]] .
    ultimately show "j \<in> {j. j < N \<and> recover N j = r}" using hj by blast
  qed
  have inj: "inj_on (sg_jc N r) {c. c < r \<and> coprime c r}"
  proof (rule inj_onI) fix c c' assume "c \<in> {c. c < r \<and> coprime c r}" "c' \<in> {c. c < r \<and> coprime c r}"
      and "sg_jc N r c = sg_jc N r c'"
    thus "c = c'" using sg_jc_inj[OF r rr] by blast
  qed
  have peak: "\<And>c. c \<in> {c. c < r \<and> coprime c r} \<Longrightarrow> 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3
        \<le> prob (qft N (periodic_state N r x0)) (sg_jc N r c)"
  proof - fix c assume hc: "c \<in> {c. c < r \<and> coprime c r}" hence hcr: "c < r" by simp
    have jlt: "sg_jc N r c < N" using sg_jc_lt[OF hcr rN_nat] .
    have hp: "is_state N (periodic_state N r x0) \<and> 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3
          \<le> prob (qft N (periodic_state N r x0)) (sg_jc N r c)"
      using shor_peak[OF r rN_nat x0 jlt sg_jc_near[OF r]] .
    show "4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) (sg_jc N r c)"
      using conjunct2[OF hp] .
  qed
  have nonneg: "\<And>j. 0 \<le> prob (qft N (periodic_state N r x0)) j" by (simp add: prob_def)
  have step1: "4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
      = (\<Sum>c \<in> {c. c < r \<and> coprime c r}. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3)"
    by (simp add: field_simps)
  have step2: "(\<Sum>c \<in> {c. c < r \<and> coprime c r}. 4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3)
      \<le> (\<Sum>c \<in> {c. c < r \<and> coprime c r}. prob (qft N (periodic_state N r x0)) (sg_jc N r c))"
    by (rule sum_mono[OF peak])
  have step3: "(\<Sum>j \<in> sg_jc N r ` {c. c < r \<and> coprime c r}. prob (qft N (periodic_state N r x0)) j)
      = (\<Sum>c \<in> {c. c < r \<and> coprime c r}. prob (qft N (periodic_state N r x0)) (sg_jc N r c))"
    by (simp add: sum.reindex[OF inj])
  have step4: "(\<Sum>j \<in> sg_jc N r ` {c. c < r \<and> coprime c r}. prob (qft N (periodic_state N r x0)) j)
      \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j)"
    by (rule sum_mono2[OF fin_S img_sub]) (rule nonneg)
  show ?thesis using step1 step2 step3 step4 by linarith
qed
end
