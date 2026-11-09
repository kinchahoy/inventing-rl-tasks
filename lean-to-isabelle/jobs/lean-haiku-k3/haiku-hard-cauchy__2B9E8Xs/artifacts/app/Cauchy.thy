theory Cauchy
  imports Group_Axioms
begin

section \<open>Iterates of a map\<close>

lemma iter_Suc_app: "(f ^^ Suc n) z = f ((f ^^ n) z)" by (simp only: funpow.simps comp_apply)

lemma iter_fixed:
  assumes "f y = y"
  shows "(f ^^ k) y = y"
proof (induction k)
  case 0
  show ?case by simp
next
  case (Suc k)
  have "(f ^^ Suc k) y = f ((f ^^ k) y)" by (rule iter_Suc_app)
  also have "\<dots> = f y" using Suc.IH by simp
  also have "\<dots> = y" by (rule assms)
  finally show ?case .
qed

lemma iter_back:
  assumes "(f ^^ Suc q) y = y"
  shows "y = (f ^^ q) (f y)"
proof -
  have "y = (f ^^ Suc q) y" by (rule assms[symmetric])
  also have "\<dots> = (f ^^ q) (f y)" by (simp only: funpow_Suc_right comp_apply)
  finally show ?thesis .
qed

lemma gcd_closure:
  fixes Q :: "nat \<Rightarrow> nat \<Rightarrow> bool" and a b :: nat
  assumes base: "\<And>m. Q m 0" and step: "\<And>m n. 0 < n \<Longrightarrow> Q n (m mod n) \<Longrightarrow> Q m n"
  shows "Q a b"
  by (rule gcd_nat_induct[where P = Q and m = a and n = b, OF base step])

section \<open>A fixed point of a prime-length cycle is the identity\<close>

lemma prime_orbit_fixed:
  fixes f :: "'a \<Rightarrow> 'a" and x :: 'a and p m :: nat
  assumes pp: "prime p" and per: "(f ^^ p) x = x" and mm: "(f ^^ m) x = x" and m0: "0 < m" and mlt: "m < p"
  shows "f x = x"
proof -
  have add_in: "\<And>a b. (f ^^ a) x = x \<Longrightarrow> (f ^^ b) x = x \<Longrightarrow> (f ^^ (a + b)) x = x"
  proof -
    fix a b :: nat
    assume ha: "(f ^^ a) x = x" and hb: "(f ^^ b) x = x"
    have "(f ^^ (a + b)) x = (f ^^ a) ((f ^^ b) x)" by (simp only: funpow_add comp_apply)
    also have "\<dots> = x" by (simp only: hb ha)
    finally show "(f ^^ (a + b)) x = x" .
  qed
  have sub_in: "\<And>a b. (f ^^ a) x = x \<Longrightarrow> (f ^^ (a + b)) x = x \<Longrightarrow> (f ^^ b) x = x"
  proof -
    fix a b :: nat
    assume ha: "(f ^^ a) x = x" and hab: "(f ^^ (a + b)) x = x"
    have "(f ^^ b) x = (f ^^ b) ((f ^^ a) x)" by (simp only: ha)
    also have "\<dots> = (f ^^ (b + a)) x" by (simp only: funpow_add comp_apply)
    also have "\<dots> = (f ^^ (a + b)) x" by (simp only: add.commute)
    also have "\<dots> = x" by (rule hab)
    finally show "(f ^^ b) x = x" .
  qed
  have mul_in: "\<And>a k. (f ^^ a) x = x \<Longrightarrow> (f ^^ (k * a)) x = x"
  proof -
    fix a k :: nat
    assume ha: "(f ^^ a) x = x"
    show "(f ^^ (k * a)) x = x"
    proof (induction k)
      case 0
      show ?case by simp
    next
      case (Suc k)
      have "(f ^^ (Suc k * a)) x = (f ^^ (a + k * a)) x" by (simp only: mult_Suc)
      also have "\<dots> = x" by (rule add_in[OF ha Suc.IH])
      finally show ?case .
    qed
  qed
  have base_c: "\<And>m. (f ^^ m) x = x \<longrightarrow> (f ^^ 0) x = x \<longrightarrow> (f ^^ gcd m 0) x = x" by simp
  have step_c: "\<And>m n. 0 < n \<Longrightarrow> ((f ^^ n) x = x \<longrightarrow> (f ^^ (m mod n)) x = x \<longrightarrow> (f ^^ gcd n (m mod n)) x = x) \<Longrightarrow> ((f ^^ m) x = x \<longrightarrow> (f ^^ n) x = x \<longrightarrow> (f ^^ gcd m n) x = x)"
  proof -
    fix m n :: nat
    assume n0: "0 < n" and IH: "(f ^^ n) x = x \<longrightarrow> (f ^^ (m mod n)) x = x \<longrightarrow> (f ^^ gcd n (m mod n)) x = x"
    show "(f ^^ m) x = x \<longrightarrow> (f ^^ n) x = x \<longrightarrow> (f ^^ gcd m n) x = x"
    proof (intro impI)
      assume hm: "(f ^^ m) x = x" and hn: "(f ^^ n) x = x"
      have h1: "(f ^^ (m div n * n)) x = x" by (rule mul_in[OF hn])
      have h2: "(f ^^ (m div n * n + m mod n)) x = x" by (simp only: div_mult_mod_eq hm)
      have hmod: "(f ^^ (m mod n)) x = x" by (rule sub_in[OF h1 h2])
      have nz: "n \<noteq> 0" using n0 by simp
      have eqg: "gcd m n = gcd n (m mod n)" by (rule gcd_non_0_nat[OF nz])
      have "(f ^^ gcd n (m mod n)) x = x" using IH hn hmod by blast
      thus "(f ^^ gcd m n) x = x" by (simp only: eqg)
    qed
  qed
  have gS: "(f ^^ gcd m p) x = x"
  proof -
    have H: "(f ^^ m) x = x \<longrightarrow> (f ^^ p) x = x \<longrightarrow> (f ^^ gcd m p) x = x" by (rule gcd_closure[where Q = "\<lambda>a b. (f ^^ a) x = x \<longrightarrow> (f ^^ b) x = x \<longrightarrow> (f ^^ gcd a b) x = x" and a = m and b = p, OF base_c step_c])
    show ?thesis by (rule mp[OF mp[OF H mm] per])
  qed
  have gd: "gcd m p dvd p" by (rule gcd_dvd2)
  have pdiv: "\<forall>d. d dvd p \<longrightarrow> d = 1 \<or> d = p" using pp by (simp add: prime_def)
  have gcd_cases: "gcd m p = 1 \<or> gcd m p = p" using pdiv gd by blast
  show ?thesis
  proof (cases "gcd m p = 1")
    case True
    have h1: "(f ^^ 1) x = x" by (subst True[symmetric]) (rule gS)
    then show ?thesis by simp
  next
    case False
    then have gp: "gcd m p = p" using gcd_cases by blast
    have "p dvd m" using gcd_dvd1[of m p] gp by simp
    then have "p \<le> m" using m0 dvd_imp_le by blast
    then have False using mlt by linarith
    then show ?thesis by (rule FalseE)
  qed
qed

section \<open>Orbit counting modulo a prime\<close>

lemma orbit_mod:
  fixes f :: "'a \<Rightarrow> 'a" and p :: nat
  assumes pp: "prime p"
  shows "\<forall>n X. card X \<le> n \<longrightarrow> finite X \<longrightarrow> f ` X \<subseteq> X \<longrightarrow> (\<forall>x\<in>X. (f ^^ p) x = x) \<longrightarrow> card X mod p = card {x\<in>X. f x = x} mod p"
proof -
  have p2: "1 < p" using pp by (simp add: prime_def)
  obtain q where pq: "p = Suc q" using p2 by (cases p) auto
  show ?thesis
  proof (rule allI)
    fix n
    show "\<forall>X. card X \<le> n \<longrightarrow> finite X \<longrightarrow> f ` X \<subseteq> X \<longrightarrow> (\<forall>x\<in>X. (f ^^ p) x = x) \<longrightarrow> card X mod p = card {x\<in>X. f x = x} mod p"
    proof (induction n)
      case 0
      show ?case
      proof (intro allI impI)
        fix X :: "'a set"
        assume cX: "card X \<le> 0" and fin: "finite X"
        have c0: "card X = 0" using cX by simp
        have "X = {}" using c0 fin by simp
        then show "card X mod p = card {x\<in>X. f x = x} mod p" by simp
      qed
    next
      case (Suc n)
      have ih: "\<forall>X. card X \<le> n \<longrightarrow> finite X \<longrightarrow> f ` X \<subseteq> X \<longrightarrow> (\<forall>x\<in>X. (f ^^ p) x = x) \<longrightarrow> card X mod p = card {x\<in>X. f x = x} mod p" by (rule Suc.IH)
      show ?case
      proof (intro allI impI)
        fix X :: "'a set"
        assume cX: "card X \<le> Suc n" and fin: "finite X" and sub: "f ` X \<subseteq> X" and per: "\<forall>x\<in>X. (f ^^ p) x = x"
        show "card X mod p = card {x\<in>X. f x = x} mod p"
        proof (cases "\<forall>x\<in>X. f x = x")
          case True
          have eqX: "{x\<in>X. f x = x} = X"
          proof (intro equalityI subsetI)
            fix y assume hy: "y \<in> {x\<in>X. f x = x}"
            then show "y \<in> X" by simp
          next
            fix y assume hy: "y \<in> X"
            have fy: "f y = y" by (rule bspec[OF True hy])
            with hy show "y \<in> {x\<in>X. f x = x}" by simp
          qed
          then show ?thesis by simp
        next
          case False
          have ex: "\<exists>x\<in>X. f x \<noteq> x" using False by (simp add: Ball_def Bex_def)
          obtain x where xX: "x \<in> X" and nfix: "f x \<noteq> x" by (rule bexE[OF ex])
          define Orb where "Orb = (\<lambda>i. (f ^^ i) x) ` {..<p}"
          have finO: "finite Orb" unfolding Orb_def by simp
          have px: "(f ^^ p) x = x" by (rule bspec[OF per xX])
          have orb_in: "\<And>i. (f ^^ i) x \<in> X"
          proof -
            fix i
            show "(f ^^ i) x \<in> X"
            proof (induction i)
              case 0
              show ?case using xX by simp
            next
              case (Suc i)
              have step: "f ((f ^^ i) x) \<in> X" by (rule subsetD[OF sub imageI[OF Suc.IH]])
              show ?case by (simp only: iter_Suc_app step)
            qed
          qed
          have no_fix: "\<And>i. i < p \<Longrightarrow> f ((f ^^ i) x) \<noteq> (f ^^ i) x"
          proof -
            fix i assume ip: "i < p"
            show "f ((f ^^ i) x) \<noteq> (f ^^ i) x"
            proof
              assume eq: "f ((f ^^ i) x) = (f ^^ i) x"
              have pe: "p - i + i = p" using ip by arith
              have hy: "(f ^^ (p - i)) ((f ^^ i) x) = (f ^^ i) x" by (rule iter_fixed[where f = f and y = "(f ^^ i) x" and k = "p - i", OF eq])
              have s1: "(f ^^ p) x = (f ^^ ((p - i) + i)) x" by (simp only: pe)
              have s2: "(f ^^ ((p - i) + i)) x = (f ^^ (p - i)) ((f ^^ i) x)" by (simp only: funpow_add comp_apply)
              have xi: "x = (f ^^ i) x"
              proof -
                have "x = (f ^^ p) x" by (rule px[symmetric])
                also have "\<dots> = (f ^^ ((p - i) + i)) x" by (rule s1)
                also have "\<dots> = (f ^^ (p - i)) ((f ^^ i) x)" by (rule s2)
                also have "\<dots> = (f ^^ i) x" by (rule hy)
                finally show ?thesis .
              qed
              have "f x = f ((f ^^ i) x)" using xi by (rule arg_cong)
              also have "\<dots> = (f ^^ i) x" by (rule eq)
              also have "\<dots> = x" using xi by (rule sym)
              finally have "f x = x" .
              with nfix show False by contradiction
            qed
          qed
          have lt_ne: "\<And>i j. i < j \<Longrightarrow> j < p \<Longrightarrow> (f ^^ i) x \<noteq> (f ^^ j) x"
          proof -
            fix i j :: nat
            assume ij: "i < j" and jp: "j < p"
            show "(f ^^ i) x \<noteq> (f ^^ j) x"
            proof
              assume eq: "(f ^^ i) x = (f ^^ j) x"
              have pj: "p - j + j = p" using jp by arith
              have B: "(f ^^ (p - j)) ((f ^^ j) x) = x"
              proof -
                have "(f ^^ (p - j)) ((f ^^ j) x) = (f ^^ ((p - j) + j)) x" by (simp only: funpow_add comp_apply)
                also have "\<dots> = x" by (simp only: pj px)
                finally show ?thesis .
              qed
              have C: "(f ^^ (p - j)) ((f ^^ i) x) = (f ^^ (p - j + i)) x" by (simp only: funpow_add comp_apply)
              have D1: "(f ^^ (p - j)) ((f ^^ i) x) = (f ^^ (p - j)) ((f ^^ j) x)" by (simp only: eq)
              have D: "(f ^^ (p - j + i)) x = x" by (simp only: C[symmetric] D1 B)
              have m0: "0 < p - j + i" using jp by arith
              have mlt: "p - j + i < p" using ij jp by arith
              have "f x = x" by (rule prime_orbit_fixed[OF pp px D m0 mlt])
              with nfix show False by contradiction
            qed
          qed
          have inj_O: "inj_on (\<lambda>i. (f ^^ i) x) {..<p}"
          proof (rule inj_onI)
            fix i j assume hi: "i \<in> {..<p}" and hj: "j \<in> {..<p}" and eq: "(f ^^ i) x = (f ^^ j) x"
            have ip: "i < p" using hi by simp
            have jp: "j < p" using hj by simp
            show "i = j"
            proof (rule linorder_cases[of i j])
              assume hij: "i < j"
              have hne: "(f ^^ i) x \<noteq> (f ^^ j) x" by (rule lt_ne[OF hij jp])
              from hne eq show ?thesis by contradiction
            next
              assume "i = j"
              then show ?thesis .
            next
              assume hji: "j < i"
              have hne: "(f ^^ j) x \<noteq> (f ^^ i) x" by (rule lt_ne[OF hji ip])
              have eq': "(f ^^ j) x = (f ^^ i) x" by (rule sym[OF eq])
              from hne eq' show ?thesis by contradiction
            qed
          qed
          have cardO: "card Orb = p" unfolding Orb_def by (simp add: card_image inj_O)
          have O_sub: "Orb \<subseteq> X" unfolding Orb_def by (simp add: image_subset_iff orb_in)
          have fin_diff: "finite (X - Orb)" by (rule finite_Diff[OF fin])
          have le: "card Orb \<le> card X" by (rule card_mono[OF fin O_sub])
          have d: "card (X - Orb) = card X - card Orb" by (rule card_Diff_subset[OF finO O_sub])
          have pl: "p \<le> card X" using le cardO by simp
          have split: "card X = card (X - Orb) + p" using d cardO pl by arith
          have not_fix_O: "\<And>y. y \<in> Orb \<Longrightarrow> f y \<noteq> y"
          proof -
            fix y assume yO: "y \<in> Orb"
            have yO': "y \<in> (\<lambda>i. (f ^^ i) x) ` {..<p}" using yO by (simp only: Orb_def)
            obtain i where yi: "y = (\<lambda>i. (f ^^ i) x) i" and ip: "i \<in> {..<p}" by (rule imageE[OF yO'])
            have ilt: "i < p" using ip by simp
            show "f y \<noteq> y" unfolding yi by (rule no_fix[OF ilt])
          qed
          have fix_eq: "{y \<in> X - Orb. f y = y} = {y \<in> X. f y = y}"
          proof (intro equalityI subsetI)
            fix y assume hy: "y \<in> {y \<in> X - Orb. f y = y}"
            then show "y \<in> {y \<in> X. f y = y}" by simp
          next
            fix y assume hy: "y \<in> {y \<in> X. f y = y}"
            have yX: "y \<in> X" using hy by simp
            have yf: "f y = y" using hy by simp
            have yO: "y \<notin> Orb"
            proof
              assume "y \<in> Orb"
              then have "f y \<noteq> y" by (rule not_fix_O)
              with yf show False by contradiction
            qed
            from yX yO yf show "y \<in> {y \<in> X - Orb. f y = y}" by simp
          qed
          have sub': "f ` (X - Orb) \<subseteq> X - Orb"
          proof (rule subsetI)
            fix z assume zin: "z \<in> f ` (X - Orb)"
            obtain y where zfy: "z = f y" and yD: "y \<in> X - Orb" by (rule imageE[OF zin])
            have yX: "y \<in> X" by (rule DiffD1[OF yD])
            have yO: "y \<notin> Orb" using yD by (simp add: Diff_iff)
            have fyX: "z \<in> X" unfolding zfy by (rule subsetD[OF sub imageI[OF yX]])
            have zO: "z \<notin> Orb"
            proof
              assume zO: "z \<in> Orb"
              have zO': "z \<in> (\<lambda>i. (f ^^ i) x) ` {..<p}" using zO by (simp only: Orb_def)
              obtain i where zi: "z = (\<lambda>i. (f ^^ i) x) i" and ip: "i \<in> {..<p}" by (rule imageE[OF zO'])
              have ilt: "i < p" using ip by simp
              have yper: "(f ^^ p) y = y" by (rule bspec[OF per yX])
              have yper': "(f ^^ Suc q) y = y" using yper by (simp only: pq[symmetric])
              have yback: "y = (f ^^ q) (f y)" by (rule iter_back[OF yper'])
              have fy: "f y = (f ^^ i) x" using zfy zi by simp
              have yO': "y \<in> Orb"
              proof (cases i)
                case 0
                have "y = (f ^^ q) (f y)" by (rule yback)
                also have "\<dots> = (f ^^ q) x" using fy 0 by simp
                finally have yq: "y = (f ^^ q) x" .
                have qp: "q < p" using pq by arith
                have qmem: "q \<in> {..<p}" using qp by simp
                have memq: "y \<in> (\<lambda>i. (f ^^ i) x) ` {..<p}"
                proof (rule image_eqI[where x = q])
                  show "y = (\<lambda>i. (f ^^ i) x) q" using yq by simp
                next
                  show "q \<in> {..<p}" using qp by simp
                qed
                then show ?thesis unfolding Orb_def .
              next
                case (Suc i')
                have fy2: "f y = f ((f ^^ i') x)" using fy Suc by (simp only: Suc iter_Suc_app)
                have w: "(f ^^ Suc q) ((f ^^ i') x) = (f ^^ q) (f ((f ^^ i') x))" by (simp only: funpow_Suc_right comp_apply)
                have i'p: "i' < p" using Suc ilt by arith
                have mem': "(f ^^ i') x \<in> X" by (rule orb_in)
                have per_i': "(f ^^ p) ((f ^^ i') x) = (f ^^ i') x" by (rule bspec[OF per mem'])
                have "y = (f ^^ q) (f y)" by (rule yback)
                also have "\<dots> = (f ^^ q) (f ((f ^^ i') x))" using fy2 by simp
                also have "\<dots> = (f ^^ Suc q) ((f ^^ i') x)" by (simp only: w)
                also have "\<dots> = (f ^^ p) ((f ^^ i') x)" by (simp only: pq[symmetric])
                also have "\<dots> = (f ^^ i') x" by (rule per_i')
                finally have yi': "y = (f ^^ i') x" .
                have qm: "i' \<in> {..<p}" using i'p by simp
                have memi: "y \<in> (\<lambda>i. (f ^^ i) x) ` {..<p}"
                proof (rule image_eqI[where x = i'])
                  show "y = (\<lambda>i. (f ^^ i) x) i'" using yi' by simp
                next
                  show "i' \<in> {..<p}" using i'p by simp
                qed
                then show ?thesis unfolding Orb_def .
              qed
              show False by (rule notE[OF yO yO'])
            qed
            show "z \<in> X - Orb" by (rule DiffI[OF fyX zO])
          qed
          have per': "\<forall>x\<in>X - Orb. (f ^^ p) x = x"
          proof (rule ballI)
            fix x' assume "x' \<in> X - Orb"
            then have "x' \<in> X" by (rule DiffD1)
            then show "(f ^^ p) x' = x'" by (rule bspec[OF per])
          qed
          have le_n: "card (X - Orb) \<le> n" using split cX p2 by arith
          have ih1: "card (X - Orb) \<le> n \<longrightarrow> finite (X - Orb) \<longrightarrow> f ` (X - Orb) \<subseteq> X - Orb \<longrightarrow> (\<forall>x\<in>X - Orb. (f ^^ p) x = x) \<longrightarrow>
              card (X - Orb) mod p = card {y \<in> X - Orb. f y = y} mod p"
            by (rule spec[OF ih])
          have ih_app: "card (X - Orb) mod p = card {y \<in> X - Orb. f y = y} mod p" by (rule mp[OF mp[OF mp[OF mp[OF ih1 le_n] fin_diff] sub'] per'])
          have "card X mod p = card (X - Orb) mod p" using split by simp
          also have "\<dots> = card {y \<in> X - Orb. f y = y} mod p" by (rule ih_app)
          also have "\<dots> = card {y \<in> X. f y = y} mod p" by (simp only: fix_eq)
          finally show ?thesis .
        qed
      qed
    qed
  qed
qed

section \<open>Group facts from the defining laws\<close>

context grp
begin

lemma idem_unit:
  assumes uG: "u \<in> G" and uu: "u \<cdot> u = u"
  shows "u = e"
proof -
  have h1: "ginv u \<cdot> u = e" by (rule left_inv[OF uG])
  have h2: "(ginv u \<cdot> u) \<cdot> u = ginv u \<cdot> (u \<cdot> u)" by (rule assoc[OF inv_closed[OF uG] uG uG])
  have "u = e \<cdot> u" by (rule left_unit[OF uG, symmetric])
  also have "\<dots> = (ginv u \<cdot> u) \<cdot> u" by (simp only: h1)
  also have "\<dots> = ginv u \<cdot> (u \<cdot> u)" by (rule h2)
  also have "\<dots> = ginv u \<cdot> u" by (simp only: uu)
  also have "\<dots> = e" by (rule h1)
  finally show ?thesis .
qed

lemma rinv:
  assumes xG: "x \<in> G"
  shows "x \<cdot> ginv x = e"
proof -
  have yG: "ginv x \<in> G" by (rule inv_closed[OF xG])
  have yx: "ginv x \<cdot> x = e" by (rule left_inv[OF xG])
  have xyG: "x \<cdot> ginv x \<in> G" by (rule closed[OF xG yG])
  have step1: "ginv x \<cdot> (x \<cdot> ginv x) = ginv x"
  proof -
    have "ginv x \<cdot> (x \<cdot> ginv x) = (ginv x \<cdot> x) \<cdot> ginv x" by (rule assoc[OF yG xG yG, symmetric])
    also have "\<dots> = e \<cdot> ginv x" by (simp only: yx)
    also have "\<dots> = ginv x" by (rule left_unit[OF yG])
    finally show ?thesis .
  qed
  have idem: "(x \<cdot> ginv x) \<cdot> (x \<cdot> ginv x) = x \<cdot> ginv x"
  proof -
    have "(x \<cdot> ginv x) \<cdot> (x \<cdot> ginv x) = x \<cdot> (ginv x \<cdot> (x \<cdot> ginv x))" by (rule assoc[OF xG yG xyG])
    also have "\<dots> = x \<cdot> ginv x" by (simp only: step1)
    finally show ?thesis .
  qed
  show ?thesis by (rule idem_unit[OF xyG idem])
qed

lemma runit:
  assumes xG: "x \<in> G"
  shows "x \<cdot> e = x"
proof -
  have yG: "ginv x \<in> G" by (rule inv_closed[OF xG])
  have "x \<cdot> e = x \<cdot> (ginv x \<cdot> x)" by (simp only: left_inv[OF xG])
  also have "\<dots> = (x \<cdot> ginv x) \<cdot> x" by (rule assoc[OF xG yG xG, symmetric])
  also have "\<dots> = e \<cdot> x" by (simp only: rinv[OF xG])
  also have "\<dots> = x" by (rule left_unit[OF xG])
  finally show ?thesis .
qed

lemma unique_inv:
  assumes PG: "P \<in> G" and zG: "z \<in> G" and hPz: "P \<cdot> z = e"
  shows "z = ginv P"
proof -
  have "z = e \<cdot> z" by (rule left_unit[OF zG, symmetric])
  also have "\<dots> = (ginv P \<cdot> P) \<cdot> z" by (simp only: left_inv[OF PG])
  also have "\<dots> = ginv P \<cdot> (P \<cdot> z)" by (rule assoc[OF inv_closed[OF PG] PG zG])
  also have "\<dots> = ginv P \<cdot> e" by (simp only: hPz)
  also have "\<dots> = ginv P" by (rule runit[OF inv_closed[OF PG]])
  finally show ?thesis .
qed

lemma pow_e: "pow e n = e" by (induction n) (simp_all add: left_unit unit_closed)

lemma pow_iter: "(mult a ^^ n) e = pow a n" by (induction n) simp_all

definition lprod :: "'a list \<Rightarrow> 'a" where
  "lprod xs = foldr mult xs e"

lemma lprod_Nil [simp]: "lprod [] = e" by (simp add: lprod_def)

lemma lprod_Cons [simp]: "lprod (y # ys) = y \<cdot> lprod ys" by (simp add: lprod_def)

lemma lprod_mem:
  assumes "set xs \<subseteq> G"
  shows "lprod xs \<in> G"
  using assms
proof (induction xs)
  case Nil
  show ?case by (simp add: unit_closed)
next
  case (Cons y ys)
  have yG: "y \<in> G" using Cons.prems by simp
  have ysG: "set ys \<subseteq> G" using Cons.prems by simp
  have ihG: "lprod ys \<in> G" by (rule Cons.IH[OF ysG])
  have "y \<cdot> lprod ys \<in> G" by (rule closed[OF yG ihG])
  then show ?case by simp
qed

lemma lprod_snoc:
  assumes zG: "z \<in> G"
  shows "\<forall>ys. set ys \<subseteq> G \<longrightarrow> lprod (ys @ [z]) = lprod ys \<cdot> z"
proof (rule allI)
  fix ys
  show "set ys \<subseteq> G \<longrightarrow> lprod (ys @ [z]) = lprod ys \<cdot> z"
  proof (induction ys)
    case Nil
    show ?case by (simp add: zG runit left_unit)
  next
    case (Cons y ys)
    show ?case
    proof (rule impI)
      assume sub: "set (y # ys) \<subseteq> G"
      have yG: "y \<in> G" using sub by simp
      have ysG: "set ys \<subseteq> G" using sub by simp
      have Pg: "lprod ys \<in> G" by (rule lprod_mem[OF ysG])
      have ih: "lprod (ys @ [z]) = lprod ys \<cdot> z" by (rule mp[OF Cons.IH ysG])
      have "lprod ((y # ys) @ [z]) = y \<cdot> lprod (ys @ [z])" by simp
      also have "\<dots> = y \<cdot> (lprod ys \<cdot> z)" by (simp only: ih)
      also have "\<dots> = (y \<cdot> lprod ys) \<cdot> z" by (rule assoc[OF yG Pg zG, symmetric])
      also have "\<dots> = lprod (y # ys) \<cdot> z" by simp
      finally show "lprod ((y # ys) @ [z]) = lprod (y # ys) \<cdot> z" .
    qed
  qed
qed

lemma lprod_snoc2:
  assumes zG: "z \<in> G" and ysG: "set ys \<subseteq> G"
  shows "lprod (ys @ [z]) = lprod ys \<cdot> z"
  by (rule mp[OF spec[OF lprod_snoc[OF zG]] ysG])

lemma lprod_cancel:
  assumes xG: "x \<in> G" and PG: "lprod ys \<in> G" and hx: "x \<cdot> lprod ys = e"
  shows "lprod ys \<cdot> x = e"
proof -
  have hP: "lprod ys = ginv x"
  proof -
    have "lprod ys = e \<cdot> lprod ys" by (rule left_unit[OF PG, symmetric])
    also have "\<dots> = (ginv x \<cdot> x) \<cdot> lprod ys" by (simp only: left_inv[OF xG])
    also have "\<dots> = ginv x \<cdot> (x \<cdot> lprod ys)" by (rule assoc[OF inv_closed[OF xG] xG PG])
    also have "\<dots> = ginv x \<cdot> e" by (simp only: hx)
    also have "\<dots> = ginv x" by (rule runit[OF inv_closed[OF xG]])
    finally show ?thesis .
  qed
  show ?thesis by (simp only: hP left_inv[OF xG])
qed

lemma lprod_replicate: "lprod (replicate n a) = pow a n" by (induction n) simp_all

lemma rotate_lprod:
  assumes "set xs \<subseteq> G" and "xs \<noteq> []" and "lprod xs = e"
  shows "lprod (rotate1 xs) = e"
proof -
  obtain x ys where xs: "xs = x # ys" using assms(2) by (cases xs) auto
  have xG: "x \<in> G" using assms(1) xs by simp
  have ysG: "set ys \<subseteq> G" using assms(1) xs by simp
  have Pg: "lprod ys \<in> G" by (rule lprod_mem[OF ysG])
  have hx: "x \<cdot> lprod ys = e" using assms(3) xs by simp
  have snoc: "lprod (ys @ [x]) = lprod ys \<cdot> x" by (rule lprod_snoc2[OF xG ysG])
  have "lprod (rotate1 xs) = lprod (ys @ [x])" by (simp add: xs)
  also have "\<dots> = lprod ys \<cdot> x" by (rule snoc)
  also have "\<dots> = e" by (rule lprod_cancel[OF xG Pg hx])
  finally show ?thesis .
qed

definition T_set :: "nat \<Rightarrow> 'a list set" where
  "T_set n = {xs. set xs \<subseteq> G \<and> length xs = n}"

definition X_set :: "nat \<Rightarrow> 'a list set" where
  "X_set p = {xs \<in> T_set p. lprod xs = e}"

lemma T_mem: "xs \<in> T_set n \<longleftrightarrow> set xs \<subseteq> G \<and> length xs = n" by (simp add: T_set_def)

lemma X_mem: "xs \<in> X_set p \<longleftrightarrow> set xs \<subseteq> G \<and> length xs = p \<and> lprod xs = e" by (simp add: X_set_def T_set_def)

lemma finite_T:
  assumes "finite G"
  shows "finite (T_set n)"
  unfolding T_set_def by (rule finite_lists_length_eq[OF assms])

lemma card_T:
  assumes "finite G"
  shows "card (T_set n) = card G ^ n"
  unfolding T_set_def by (rule card_lists_length_eq[OF assms])

lemma X_eq:
  assumes fG: "finite G" and p1: "1 < p"
  shows "X_set p = (\<lambda>ys. ys @ [ginv (lprod ys)]) ` T_set (p - 1)"
proof (intro equalityI subsetI)
  fix xs assume xsX: "xs \<in> X_set p"
  have xsP: "set xs \<subseteq> G \<and> length xs = p \<and> lprod xs = e" by (rule iffD1[OF X_mem xsX])
  have xsT: "set xs \<subseteq> G" by (rule conjunct1[OF xsP])
  have len: "length xs = p" by (rule conjunct1[OF conjunct2[OF xsP]])
  have ev: "lprod xs = e" by (rule conjunct2[OF conjunct2[OF xsP]])
  have ne: "xs \<noteq> []"
  proof
    assume "xs = []"
    then have "length xs = 0" by simp
    with len p1 show False by arith
  qed
  have dec: "butlast xs @ [last xs] = xs" by (rule append_butlast_last_id[OF ne])
  have ysG: "set (butlast xs) \<subseteq> G"
  proof (rule subsetI)
    fix y assume hy: "y \<in> set (butlast xs)"
    have "y \<in> set xs" by (rule in_set_butlastD[OF hy])
    then show "y \<in> G" by (rule subsetD[OF xsT])
  qed
  have zG: "last xs \<in> G" by (rule subsetD[OF xsT last_in_set[OF ne]])
  have lenb: "length (butlast xs) = p - 1" using len by simp
  have Pg: "lprod (butlast xs) \<in> G" by (rule lprod_mem[OF ysG])
  have snoc: "lprod (butlast xs @ [last xs]) = lprod (butlast xs) \<cdot> last xs" by (rule lprod_snoc2[OF zG ysG])
  have hPz: "lprod (butlast xs) \<cdot> last xs = e"
  proof -
    have "lprod (butlast xs) \<cdot> last xs = lprod (butlast xs @ [last xs])" by (rule snoc[symmetric])
    also have "\<dots> = lprod xs" by (simp only: dec)
    also have "\<dots> = e" by (rule ev)
    finally show ?thesis .
  qed
  have hz: "last xs = ginv (lprod (butlast xs))" by (rule unique_inv[OF Pg zG hPz])
  have eqx: "xs = (\<lambda>ys. ys @ [ginv (lprod ys)]) (butlast xs)" by (simp only: hz[symmetric] dec)
  have memT: "butlast xs \<in> T_set (p - 1)" by (rule iffD2[OF T_mem, OF conjI[OF ysG lenb]])
  show "xs \<in> (\<lambda>ys. ys @ [ginv (lprod ys)]) ` T_set (p - 1)" by (rule image_eqI[where b = xs and f = "\<lambda>ys. ys @ [ginv (lprod ys)]" and x = "butlast xs" and A = "T_set (p - 1)", OF eqx memT])
next
  fix xs assume hmem: "xs \<in> (\<lambda>ys. ys @ [ginv (lprod ys)]) ` T_set (p - 1)"
  obtain ys where xs_eq: "xs = ys @ [ginv (lprod ys)]" and ysT: "ys \<in> T_set (p - 1)" by (rule imageE[OF hmem])
  have ysP: "set ys \<subseteq> G \<and> length ys = p - 1" by (rule iffD1[OF T_mem ysT])
  have ysG: "set ys \<subseteq> G" by (rule conjunct1[OF ysP])
  have lenys: "length ys = p - 1" by (rule conjunct2[OF ysP])
  have Pg: "lprod ys \<in> G" by (rule lprod_mem[OF ysG])
  have zG: "ginv (lprod ys) \<in> G" by (rule inv_closed[OF Pg])
  have setx: "set xs \<subseteq> G" unfolding xs_eq by (simp add: ysG zG)
  have p1': "p - 1 + 1 = p" using p1 by arith
  have lenx0: "length xs = length ys + 1" unfolding xs_eq by simp
  have lenx: "length xs = p" using lenx0 lenys p1' by arith
  have snoc: "lprod (ys @ [ginv (lprod ys)]) = lprod ys \<cdot> ginv (lprod ys)" by (rule lprod_snoc2[OF zG ysG])
  have ev: "lprod xs = e" by (simp only: xs_eq snoc rinv[OF Pg])
  show "xs \<in> X_set p" by (rule iffD2[OF X_mem, OF conjI[OF setx conjI[OF lenx ev]]])
qed

lemma card_X:
  assumes fG: "finite G" and p1: "1 < p"
  shows "card (X_set p) = card G ^ (p - 1)"
proof -
  have inj: "inj_on (\<lambda>ys. ys @ [ginv (lprod ys)]) (T_set (p - 1))"
  proof (rule inj_onI)
    fix ys zs
    assume eq: "ys @ [ginv (lprod ys)] = zs @ [ginv (lprod zs)]"
    have "butlast (ys @ [ginv (lprod ys)]) = butlast (zs @ [ginv (lprod zs)])" by (simp only: eq)
    then show "ys = zs" by simp
  qed
  have "card (X_set p) = card ((\<lambda>ys. ys @ [ginv (lprod ys)]) ` T_set (p - 1))" by (simp only: X_eq[OF fG p1])
  also have "\<dots> = card (T_set (p - 1))" by (rule card_image[OF inj])
  also have "\<dots> = card G ^ (p - 1)" by (rule card_T[OF fG])
  finally show ?thesis .
qed

end

section \<open>Cauchy's theorem\<close>

theorem (in grp) cauchy: assumes fG: "finite G" and pp: "prime p" and hdvd: "p dvd card G" shows "\<exists>x\<in>G. pow x p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow x k \<noteq> e)"
proof -
  have p1: "1 < p" using pp by (simp add: prime_def)
  have pos: "0 < p - 1" using p1 by arith
  obtain r where hr: "p - 1 = Suc r" using pos by (cases "p - 1") auto
  have h2: "card G dvd card G ^ (p - 1)" by (subst hr) simp
  have d1: "p dvd card G ^ (p - 1)" by (rule dvd_trans[OF hdvd h2])
  have cardX: "p dvd card (X_set p)"
  proof -
    have "card (X_set p) = card G ^ (p - 1)" by (rule card_X[OF fG p1])
    then show ?thesis using d1 by simp
  qed
  have sub: "X_set p \<subseteq> T_set p"
  proof (rule subsetI)
    fix xs assume hx: "xs \<in> X_set p"
    have hP: "set xs \<subseteq> G \<and> length xs = p \<and> lprod xs = e" by (rule iffD1[OF X_mem hx])
    show "xs \<in> T_set p" by (rule iffD2[OF T_mem, OF conjI[OF conjunct1[OF hP] conjunct1[OF conjunct2[OF hP]]]])
  qed
  have finX: "finite (X_set p)" by (rule finite_subset[OF sub finite_T[OF fG]])
  have rot_sub: "rotate1 ` X_set p \<subseteq> X_set p"
  proof (rule subsetI)
    fix z assume hz: "z \<in> rotate1 ` X_set p"
    obtain xs where zr: "z = rotate1 xs" and xsX: "xs \<in> X_set p" by (rule imageE[OF hz])
    have hP: "set xs \<subseteq> G \<and> length xs = p \<and> lprod xs = e" by (rule iffD1[OF X_mem xsX])
    have xsT: "set xs \<subseteq> G" by (rule conjunct1[OF hP])
    have len: "length xs = p" by (rule conjunct1[OF conjunct2[OF hP]])
    have ev: "lprod xs = e" by (rule conjunct2[OF conjunct2[OF hP]])
    have ne: "xs \<noteq> []"
    proof
      assume "xs = []"
      then have "length xs = 0" by simp
      with len p1 show False by arith
    qed
    have rl: "lprod (rotate1 xs) = e" by (rule rotate_lprod[OF xsT ne ev])
    have zset: "set z \<subseteq> G" unfolding zr by (simp add: xsT)
    have zlen: "length z = p" unfolding zr by (simp add: len)
    have zl: "lprod z = e" unfolding zr by (rule rl)
    show "z \<in> X_set p" by (rule iffD2[OF X_mem, OF conjI[OF zset conjI[OF zlen zl]]])
  qed
  have rot_pow: "\<And>xs. xs \<in> X_set p \<Longrightarrow> (rotate1 ^^ p) xs = xs"
  proof -
    fix xs assume hx: "xs \<in> X_set p"
    have len: "length xs = p" by (rule conjunct1[OF conjunct2[OF iffD1[OF X_mem hx]]])
    have "(rotate1 ^^ p) xs = rotate p xs" by (simp add: rotate_def)
    also have "\<dots> = xs" by (simp add: len)
    finally show "(rotate1 ^^ p) xs = xs" .
  qed
  note orb0 = orbit_mod[where f = rotate1, OF pp, rule_format]
  have orb: "card (X_set p) mod p = card {xs \<in> X_set p. rotate1 xs = xs} mod p" by (rule orb0[OF le_refl finX rot_sub rot_pow])
  have cX0: "card (X_set p) mod p = 0"
  proof -
    obtain k where hk: "card (X_set p) = p * k" by (rule dvdE[OF cardX])
    show ?thesis using hk by simp
  qed
  have rset: "set (replicate p e) \<subseteq> G" using unit_closed by (simp add: subset_iff)
  have rlen: "length (replicate p e) = p" by simp
  have rl: "lprod (replicate p e) = e" by (simp add: lprod_replicate pow_e)
  have rF: "replicate p e \<in> {xs \<in> X_set p. rotate1 xs = xs}"
  proof -
    have mem: "replicate p e \<in> X_set p" by (rule iffD2[OF X_mem, OF conjI[OF rset conjI[OF rlen rl]]])
    have rot: "rotate1 (replicate p e) = replicate p e" by simp
    show ?thesis using mem rot by simp
  qed
  have ex: "\<exists>xs \<in> {xs \<in> X_set p. rotate1 xs = xs}. xs \<noteq> replicate p e"
  proof (rule ccontr)
    assume hn: "\<not> (\<exists>xs \<in> {xs \<in> X_set p. rotate1 xs = xs}. xs \<noteq> replicate p e)"
    have allr: "\<forall>xs \<in> {xs \<in> X_set p. rotate1 xs = xs}. xs = replicate p e" using hn by simp
    have Feq: "{xs \<in> X_set p. rotate1 xs = xs} = {replicate p e}"
    proof (rule equalityI)
      show "{xs \<in> X_set p. rotate1 xs = xs} \<subseteq> {replicate p e}"
      proof (rule subsetI)
        fix xs assume hxs: "xs \<in> {xs \<in> X_set p. rotate1 xs = xs}"
        have "xs = replicate p e" by (rule bspec[OF allr hxs])
        then show "xs \<in> {replicate p e}" by simp
      qed
    next
      show "{replicate p e} \<subseteq> {xs \<in> X_set p. rotate1 xs = xs}" using rF by simp
    qed
    have c1: "card {xs \<in> X_set p. rotate1 xs = xs} = 1" by (simp add: Feq)
    have c2: "card {xs \<in> X_set p. rotate1 xs = xs} mod p = 1" by (simp only: c1 mod_less[OF p1])
    have "(0::nat) = 1" by (rule trans[OF cX0[symmetric] trans[OF orb c2]])
    then show False by simp
  qed
  obtain xs where xsF: "xs \<in> {xs \<in> X_set p. rotate1 xs = xs}" and xsr: "xs \<noteq> replicate p e" by (rule bexE[OF ex])
  have xsX: "xs \<in> X_set p" using xsF by simp
  have rxs: "rotate1 xs = xs" using xsF by simp
  have hP: "set xs \<subseteq> G \<and> length xs = p \<and> lprod xs = e" by (rule iffD1[OF X_mem xsX])
  have xsT: "set xs \<subseteq> G" by (rule conjunct1[OF hP])
  have len: "length xs = p" by (rule conjunct1[OF conjunct2[OF hP]])
  have ev: "lprod xs = e" by (rule conjunct2[OF conjunct2[OF hP]])
  have ne: "xs \<noteq> []"
  proof
    assume "xs = []"
    then have "length xs = 0" by simp
    with len p1 show False by arith
  qed
  have card1: "card (set xs) = 1"
  proof (rule disjE[OF rotate1_fixpoint_card[OF rxs]])
    assume "xs = []"
    with ne show ?thesis by contradiction
  next
    assume "card (set xs) = 1"
    then show ?thesis .
  qed
  obtain a where sa: "set xs = {a}" by (rule card_1_singletonE[OF card1])
  have ya: "\<forall>y\<in>set xs. y = a"
  proof (rule ballI)
    fix y assume hy: "y \<in> set xs"
    then show "y = a" using sa by simp
  qed
  have all_a: "replicate (length xs) a = xs" by (rule replicate_length_same[OF ya])
  have rep: "replicate p a = xs" using all_a len by simp
  have aset: "a \<in> set xs" using sa by simp
  have aG: "a \<in> G" by (rule subsetD[OF xsT aset])
  have pa: "pow a p = e"
  proof -
    have "pow a p = lprod (replicate p a)" by (rule sym[OF lprod_replicate])
    also have "\<dots> = lprod xs" by (simp only: rep)
    also have "\<dots> = e" by (rule ev)
    finally show ?thesis .
  qed
  have ane: "a \<noteq> e"
  proof
    assume ae: "a = e"
    have "replicate p e = xs" using rep ae by simp
    then have "xs = replicate p e" by (rule sym)
    with xsr show False by contradiction
  qed
  have order: "\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow a k \<noteq> e"
  proof (rule allI)
    fix k show "0 < k \<longrightarrow> k < p \<longrightarrow> pow a k \<noteq> e"
    proof (rule impI)
      assume k0: "0 < k"
      show "k < p \<longrightarrow> pow a k \<noteq> e"
      proof (rule impI)
        assume kp: "k < p"
        show "pow a k \<noteq> e"
        proof
          assume ek: "pow a k = e"
          have per: "(mult a ^^ p) e = e" by (simp only: pow_iter pa)
          have mm: "(mult a ^^ k) e = e" by (simp only: pow_iter ek)
          have ae: "a \<cdot> e = e" by (rule prime_orbit_fixed[OF pp per mm k0 kp])
          have "a = a \<cdot> e" by (rule runit[OF aG, symmetric])
          also have "\<dots> = e" by (rule ae)
          finally have "a = e" .
          with ane show False by contradiction
        qed
      qed
    qed
  qed
  have main: "pow a p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow a k \<noteq> e)" by (rule conjI[OF pa order])
  show ?thesis by (rule bexI[where x = a and A = G and P = "\<lambda>x. pow x p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow x k \<noteq> e)", OF main aG])
qed

end
