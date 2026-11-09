theory Cauchy
  imports Group_Axioms
begin

text \<open>
  Proof plan (the classical counting proof of Cauchy's theorem).

  Let \<open>S\<close> be the set of \<open>p\<close>-tuples \<open>(x\<^sub>1, \<dots>, x\<^sub>p)\<close> of elements of \<open>G\<close> with
  product \<open>e\<close>.  Its size is \<open>|G|^(p-1)\<close>, which is divisible by \<open>p\<close>.  The cyclic
  rotation acts on \<open>S\<close> with order dividing \<open>p\<close>, so the number of fixed points is
  divisible by \<open>p\<close> as well.  The constant tuple \<open>(e, \<dots>, e)\<close> is a fixed point, hence there
  is a second fixed point \<open>(x, \<dots>, x)\<close> with \<open>x \<noteq> e\<close> and \<open>x\<^sup>p = e\<close>.  Since \<open>p\<close> is prime,
  \<open>x\<close> has order exactly \<open>p\<close>.
\<close>

section \<open>Iterates of a function\<close>

lemma it_split: "(f ^^ (a + b)) x = (f ^^ a) ((f ^^ b) x)"
  by (simp add: funpow_add)

lemma it_fix: "f y = y \<Longrightarrow> (f ^^ m) y = y"
  by (induct m) auto

lemma it_add:
  assumes ha: "(f ^^ a) z = z" and hb: "(f ^^ b) z = z"
  shows "(f ^^ (a + b)) z = z"
  by (simp add: it_split hb ha)

lemma it_mult:
  assumes ha: "(f ^^ a) z = z"
  shows "(f ^^ (a * k)) z = z"
proof (induct k)
  case 0
  then show ?case by simp
next
  case (Suc k)
  have "(f ^^ (a * Suc k)) z = (f ^^ (a * k + a)) z"
    by (simp add: algebra_simps)
  also have "\<dots> = z"
    by (rule it_add[OF Suc.hyps ha])
  finally show ?case .
qed

lemma it_sub:
  assumes ha: "(f ^^ a) z = z" and hb: "(f ^^ b) z = z" and hle: "b \<le> a"
  shows "(f ^^ (a - b)) z = z"
proof -
  have e1: "(f ^^ ((a - b) + b)) z = (f ^^ a) z"
    by (simp add: hle)
  have e2: "(f ^^ ((a - b) + b)) z = (f ^^ (a - b)) z"
    by (simp add: it_split hb)
  show ?thesis
  proof -
    have "(f ^^ (a - b)) z = (f ^^ ((a - b) + b)) z" by (rule e2[symmetric])
    also have "\<dots> = (f ^^ a) z" by (rule e1)
    also have "\<dots> = z" by (rule ha)
    finally show ?thesis .
  qed
qed

text \<open>The stabiliser of a point is closed under gcd (Euclid's algorithm).\<close>

lemma it_gcd_step:
  assumes hpos: "0 < n"
    and ih: "(f ^^ n) z = z \<Longrightarrow> (f ^^ (m mod n)) z = z \<Longrightarrow> (f ^^ gcd n (m mod n)) z = z"
  shows "(f ^^ m) z = z \<Longrightarrow> (f ^^ n) z = z \<Longrightarrow> (f ^^ gcd m n) z = z"
proof -
    assume hm: "(f ^^ m) z = z" and hn: "(f ^^ n) z = z"
    have h1: "(f ^^ (n * (m div n))) z = z"
      by (rule it_mult[OF hn])
    have h2: "(f ^^ (m mod n + n * (m div n))) z = (f ^^ (m mod n)) z"
      by (subst it_split[where f=f and a="m mod n" and b="n * (m div n)" and x=z]) (simp add: h1)
    have h3: "m mod n + n * (m div n) = m"
      using div_mult_mod_eq[of m n] by (simp add: add.commute)
    have hmod: "(f ^^ (m mod n)) z = z"
    proof -
      have "(f ^^ (m mod n)) z = (f ^^ (m mod n + n * (m div n))) z" by (rule h2[symmetric])
      also have "\<dots> = (f ^^ m) z" by (subst h3) (rule refl)
      also have "\<dots> = z" by (rule hm)
      finally show ?thesis .
    qed
    have "(f ^^ gcd n (m mod n)) z = z"
      using ih hn hmod by blast
    moreover have "gcd m n = gcd n (m mod n)"
      by (rule gcd_non_0_nat) (use hpos in simp)
    ultimately show "(f ^^ gcd m n) z = z" by simp
qed

lemma it_gcd: "(f ^^ a) z = z \<Longrightarrow> (f ^^ b) z = z \<Longrightarrow> (f ^^ gcd a b) z = z"
proof (induct a b rule: gcd_nat_induct)
  fix m
  show "(f ^^ m) z = z \<Longrightarrow> (f ^^ 0) z = z \<Longrightarrow> (f ^^ gcd m 0) z = z" by simp
next
  fix m n
  assume hpos: "0 < n"
    and ih: "(f ^^ n) z = z \<Longrightarrow> (f ^^ (m mod n)) z = z \<Longrightarrow> (f ^^ gcd n (m mod n)) z = z"
  show "(f ^^ m) z = z \<Longrightarrow> (f ^^ n) z = z \<Longrightarrow> (f ^^ gcd m n) z = z"
    by (rule it_gcd_step[OF hpos ih])
qed

lemma prime_gcd1: "prime p \<Longrightarrow> 0 < k \<Longrightarrow> k < p \<Longrightarrow> gcd k p = 1"
proof -
  assume pp: "prime p" and k0: "0 < k" and kp: "k < p"
  have hp: "\<forall>d. d dvd p \<longrightarrow> d = 1 \<or> d = p"
    using pp unfolding prime_def by blast
  have d: "gcd k p dvd p" by simp
  from hp d have "gcd k p = 1 \<or> gcd k p = p" by blast
  moreover have "gcd k p \<noteq> p"
  proof
    assume "gcd k p = p"
    then have "p dvd k" using gcd_dvd1[of k p] by simp
    then have "p \<le> k" using k0 dvd_imp_le by blast
    with kp show False by simp
  qed
  ultimately show ?thesis by blast
qed

lemma prime_fix:
  assumes pp: "prime p" and k0: "0 < k" and kp: "k < p"
    and hk: "(f ^^ k) z = z" and hp: "(f ^^ p) z = z"
  shows "f z = z"
proof -
  have g: "(f ^^ gcd k p) z = z"
    by (rule it_gcd[OF hk hp])
  have g1: "gcd k p = 1"
    by (rule prime_gcd1[OF pp k0 kp])
  have "(f ^^ 1) z = z"
    using g by (simp add: g1)
  then show ?thesis by simp
qed

lemma orbit_inj:
  assumes pp: "prime p" and hij: "i < j" and hjp: "j < p"
    and hx: "(f ^^ p) x = x" and eq: "(f ^^ i) x = (f ^^ j) x"
  shows "f x = x"
proof -
  have e1: "p - i + i = p" using hij hjp by arith
  have e2: "p - i + j = (j - i) + p" using hij hjp by arith
  have s1: "(f ^^ p) x = (f ^^ (p - i)) ((f ^^ i) x)"
    proof -
      have "(f ^^ p) x = (f ^^ (p - i + i)) x" by (simp only: e1)
      also have "\<dots> = (f ^^ (p - i)) ((f ^^ i) x)" by (rule it_split)
      finally show ?thesis .
    qed
  have s2: "(f ^^ (p - i)) ((f ^^ j) x) = (f ^^ (j - i)) x"
  proof -
    have "(f ^^ (p - i)) ((f ^^ j) x) = (f ^^ (p - i + j)) x"
      by (simp add: it_split)
    also have "\<dots> = (f ^^ ((j - i) + p)) x"
      by (simp add: e2)
    also have "\<dots> = (f ^^ (j - i)) ((f ^^ p) x)"
      by (simp add: it_split)
    also have "\<dots> = (f ^^ (j - i)) x"
      by (simp add: hx)
    finally show ?thesis .
  qed
  have hd: "(f ^^ (j - i)) x = x"
  proof -
    have "x = (f ^^ p) x" by (simp add: hx)
    also have "\<dots> = (f ^^ (p - i)) ((f ^^ i) x)" by (rule s1)
    also have "\<dots> = (f ^^ (p - i)) ((f ^^ j) x)" by (simp add: eq)
    also have "\<dots> = (f ^^ (j - i)) x" by (rule s2)
    finally show ?thesis by simp
  qed
  have d1: "0 < j - i" using hij by arith
  have d2: "j - i < p" using hij hjp by arith
  show ?thesis by (rule prime_fix[OF pp d1 d2 hd hx])
qed

lemma it_inv:
  assumes hS: "\<forall>x\<in>S. f x \<in> S" and hy: "y \<in> S"
  shows "(f ^^ k) y \<in> S"
proof (induct k)
  case 0
  then show ?case by (simp add: hy)
next
  case (Suc k)
  have "(f ^^ Suc k) y = f ((f ^^ k) y)" by simp
  then show ?case using hS Suc.hyps by auto
qed

section \<open>Counting fixed points of a permutation of order dividing a prime\<close>

text \<open>If \<open>f\<close> has \<open>f^p = id\<close> on a finite invariant set \<open>S\<close>, then \<open>|S|\<close> and the
  number of fixed points of \<open>f\<close> in \<open>S\<close> agree modulo \<open>p\<close>.  The proof splits \<open>S\<close>
  into orbits of size \<open>p\<close> (no orbit of size 1 besides the fixed points).\<close>

lemma orbit_decomp:
  fixes f :: "'a \<Rightarrow> 'a" and p :: nat
  assumes pp: "prime p"
  shows "\<forall>n. \<forall>S. card S = n \<longrightarrow> finite S \<longrightarrow> (\<forall>x\<in>S. f x \<in> S) \<longrightarrow> (\<forall>x\<in>S. (f ^^ p) x = x)
           \<longrightarrow> (\<exists>k. card S = card {x\<in>S. f x = x} + p * k)"
proof (rule allI)
  fix n :: nat
  show "\<forall>S. card S = n \<longrightarrow> finite S \<longrightarrow> (\<forall>x\<in>S. f x \<in> S) \<longrightarrow> (\<forall>x\<in>S. (f ^^ p) x = x)
           \<longrightarrow> (\<exists>k. card S = card {x\<in>S. f x = x} + p * k)"
  proof (induct n rule: nat_less_induct)
    fix n :: nat
    assume IH: "\<forall>m<n. \<forall>S. card S = m \<longrightarrow> finite S \<longrightarrow> (\<forall>x\<in>S. f x \<in> S) \<longrightarrow> (\<forall>x\<in>S. (f ^^ p) x = x)
           \<longrightarrow> (\<exists>k. card S = card {x\<in>S. f x = x} + p * k)"
    show "\<forall>S. card S = n \<longrightarrow> finite S \<longrightarrow> (\<forall>x\<in>S. f x \<in> S) \<longrightarrow> (\<forall>x\<in>S. (f ^^ p) x = x)
           \<longrightarrow> (\<exists>k. card S = card {x\<in>S. f x = x} + p * k)"
    proof (intro allI impI)
      fix S :: "'a set"
      assume hcard: "card S = n" and hfin: "finite S" and invS: "\<forall>x\<in>S. f x \<in> S"
        and invP: "\<forall>x\<in>S. (f ^^ p) x = x"
      have hp0: "0 < p" using pp unfolding prime_def by auto
      show "\<exists>k. card S = card {x\<in>S. f x = x} + p * k"
      proof (cases "\<forall>x\<in>S. f x = x")
        case True
        have "{x\<in>S. f x = x} = S" using True by auto
        then have "card S = card {x\<in>S. f x = x} + p * 0" by simp
        then show ?thesis by (rule exI[of _ 0])
      next
        case False
        then obtain x0 where x0S: "x0 \<in> S" and fx0: "f x0 \<noteq> x0" by blast
        have hpx: "(f ^^ p) x0 = x0" using invP x0S by blast
        define Orb where "Orb = image (\<lambda>k. (f ^^ k) x0) {..<p}"
        have Ofin: "finite Orb" unfolding Orb_def by simp
        have Oin: "Orb \<subseteq> S"
        proof
          fix y assume "y \<in> Orb"
          then obtain k where yk: "y = (f ^^ k) x0" unfolding Orb_def by auto
          have "(f ^^ k) x0 \<in> S" using it_inv[OF invS x0S, of k] .
          then show "y \<in> S" using yk by simp
        qed
        have x0O: "x0 \<in> Orb"
          unfolding Orb_def by (rule image_eqI[where x=0]) (simp_all add: hp0)
        have inj: "inj_on (\<lambda>k. (f ^^ k) x0) {..<p}"
        proof (rule inj_onI)
          fix a b
          assume ha: "a \<in> {..<p}" and hb: "b \<in> {..<p}"
            and eq: "(f ^^ a) x0 = (f ^^ b) x0"
          have ap: "a < p" using ha by simp
          have bp: "b < p" using hb by simp
          show "a = b"
          proof (rule ccontr)
            assume neq: "a \<noteq> b"
            have "f x0 = x0"
            proof (cases "a < b")
              case True
              show ?thesis using orbit_inj[OF pp True bp hpx eq] by blast
            next
              case False
              then have blt: "b < a" using neq by arith
              show ?thesis using orbit_inj[OF pp blt ap hpx eq[symmetric]] by blast
            qed
            with fx0 show False by contradiction
          qed
        qed
        have cardOrb: "card Orb = p"
          unfolding Orb_def by (subst card_image[OF inj]) simp
        have Oinv: "\<forall>y\<in>Orb. f y \<in> Orb"
        proof (intro ballI)
          fix y assume "y \<in> Orb"
          then obtain k where kp: "k < p" and yk: "y = (f ^^ k) x0"
            unfolding Orb_def by auto
          show "f y \<in> Orb"
          proof (cases "Suc k < p")
            case True
            have "f y = (f ^^ Suc k) x0" using yk by simp
            then show ?thesis unfolding Orb_def
              by (rule image_eqI[where x="Suc k"]) (simp_all add: True)
          next
            case False
            have kp1: "k + 1 = p" using kp False by arith
            have "f y = (f ^^ (k + 1)) x0" by (simp add: yk)
            also have "\<dots> = (f ^^ p) x0" by (simp only: kp1)
            finally have "f y = x0" using hpx by simp
            then show ?thesis using x0O by simp
          qed
        qed
        have fixO: "\<forall>y\<in>Orb. f y \<noteq> y"
        proof (intro ballI notI)
          fix y assume yO: "y \<in> Orb" and fy: "f y = y"
          then obtain k where kp: "k < p" and yk: "y = (f ^^ k) x0"
            unfolding Orb_def by auto
          have c1: "(f ^^ (p - k)) y = y" by (rule it_fix) (rule fy)
          have c2: "(f ^^ (p - k)) y = x0"
          proof -
            have hpk: "p - k + k = p" using kp by arith
            have "(f ^^ p) x0 = (f ^^ (p - k + k)) x0" by (simp only: hpk)
            also have "\<dots> = (f ^^ (p - k)) ((f ^^ k) x0)" by (rule it_split)
            finally show ?thesis using yk hpx by simp
          qed
          have "y = x0" using c1 c2 by simp
          then have "f x0 = x0" using fy by simp
          with fx0 show False by contradiction
        qed
        have Sdiff: "S - Orb \<subset> S" using x0S x0O by auto
        have invSO: "\<forall>y\<in>S - Orb. f y \<in> S - Orb"
        proof (intro ballI)
          fix y assume yS: "y \<in> S - Orb"
          then have ys: "y \<in> S" and yO: "y \<notin> Orb" by auto
          have fyS: "f y \<in> S" using invS ys by blast
          have fyO: "f y \<notin> Orb"
          proof
            assume fyO: "f y \<in> Orb"
            have hbk: "(f ^^ (p - 1)) (f y) \<in> Orb"
              by (rule it_inv[OF Oinv fyO])
            have hsp: "Suc (p - 1) = p" using hp0 by arith
            have hsh: "(f ^^ p) y = (f ^^ (p - 1)) (f y)"
            proof -
              have "(f ^^ p) y = (f ^^ Suc (p - 1)) y" by (simp only: hsp)
              also have "\<dots> = (f ^^ (p - 1)) (f y)"
                by (simp only: funpow.simps comp_apply funpow_swap1)
              finally show ?thesis .
            qed
            have hpy: "(f ^^ p) y = y" using invP ys by blast
            have "(f ^^ (p - 1)) (f y) = y" using hpy hsh by simp
            then show False using hbk yO by simp
          qed
          then show "f y \<in> S - Orb" using fyS by simp
        qed
        have invP': "\<forall>y\<in>S - Orb. (f ^^ p) y = y" using invP by auto
        have hfinD: "finite (S - Orb)" using hfin by simp
        have cardlt: "card (S - Orb) < n"
        proof -
          have "card (S - Orb) = card S - card Orb"
            by (rule card_Diff_subset[OF Ofin Oin])
          moreover have "card Orb \<le> card S" by (rule card_mono[OF hfin Oin])
          ultimately show ?thesis using cardOrb hcard hp0 by arith
        qed
        note h1 = spec[OF IH, where x="card (S - Orb)"]
        note h2 = mp[OF h1 cardlt]
        note h3 = spec[OF h2, where x="S - Orb"]
        have kex: "\<exists>k. card (S - Orb) = card {x\<in>S - Orb. f x = x} + p * k"
          by (rule mp[OF mp[OF mp[OF mp[OF h3 refl] hfinD] invSO] invP'])
        have fixeq: "{x\<in>S - Orb. f x = x} = {x\<in>S. f x = x}"
          using fixO by auto
        have fixcard: "card {x\<in>S - Orb. f x = x} = card {x\<in>S. f x = x}"
          by (simp only: fixeq)
        have cardSO: "card S = card (S - Orb) + p"
        proof -
          have "card (S - Orb) = card S - card Orb"
            by (rule card_Diff_subset[OF Ofin Oin])
          moreover have "card Orb \<le> card S" by (rule card_mono[OF hfin Oin])
          ultimately show ?thesis using cardOrb by arith
        qed
        show ?thesis
        proof (rule exE[OF kex])
          fix k
          assume kS: "card (S - Orb) = card {x\<in>S - Orb. f x = x} + p * k"
          have hmul: "p * (k + 1) = p * k + p" by (simp add: algebra_simps)
          have e1: "card S = card {x\<in>S - Orb. f x = x} + p * k + p" by (simp only: cardSO kS)
          have e2: "card S = card {x\<in>S. f x = x} + p * k + p" by (simp only: fixcard[symmetric] e1)
          show "\<exists>k. card S = card {x\<in>S. f x = x} + p * k" by (rule exI[of _ "k + 1"]) (simp only: hmul e2)
        qed
      qed
    qed
  qed
qed

section \<open>Basic group facts from the left axioms\<close>

context grp
begin

lemma r_inv: "x \<in> G \<Longrightarrow> x \<cdot> ginv x = e"
proof -
  assume hx: "x \<in> G"
  have hy: "ginv x \<in> G" by (rule inv_closed[OF hx])
  have hz: "ginv (ginv x) \<in> G" by (rule inv_closed[OF hy])
  have h1: "ginv (ginv x) \<cdot> ginv x = e" by (rule left_inv[OF hy])
  have h2: "ginv x \<cdot> x = e" by (rule left_inv[OF hx])
  have hxy: "x \<cdot> ginv x \<in> G" by (rule closed[OF hx hy])
  have "x \<cdot> ginv x = e \<cdot> (x \<cdot> ginv x)" by (simp add: left_unit[OF hxy])
  also have "\<dots> = (ginv (ginv x) \<cdot> ginv x) \<cdot> (x \<cdot> ginv x)" by (simp add: h1)
  also have "\<dots> = ginv (ginv x) \<cdot> (ginv x \<cdot> (x \<cdot> ginv x))"
    by (rule assoc[OF hz hy hxy])
  also have "\<dots> = ginv (ginv x) \<cdot> ((ginv x \<cdot> x) \<cdot> ginv x)"
    by (simp add: assoc[OF hy hx hy])
  also have "\<dots> = ginv (ginv x) \<cdot> (e \<cdot> ginv x)" by (simp add: h2)
  also have "\<dots> = ginv (ginv x) \<cdot> ginv x" by (simp add: left_unit[OF hy])
  also have "\<dots> = e" by (rule h1)
  finally show ?thesis .
qed

lemma r_unit: "x \<in> G \<Longrightarrow> x \<cdot> e = x"
proof -
  assume hx: "x \<in> G"
  have hi: "ginv x \<in> G" by (rule inv_closed[OF hx])
  have "x \<cdot> e = x \<cdot> (ginv x \<cdot> x)" by (simp add: left_inv[OF hx])
  also have "\<dots> = (x \<cdot> ginv x) \<cdot> x" by (simp add: assoc[OF hx hi hx])
  also have "\<dots> = x" by (simp add: r_inv[OF hx] left_unit[OF hx])
  finally show ?thesis .
qed

lemma uniq_left: "a \<in> G \<Longrightarrow> y \<in> G \<Longrightarrow> a \<cdot> y = e \<Longrightarrow> y = ginv a"
proof -
  assume ha: "a \<in> G" and hy: "y \<in> G" and h: "a \<cdot> y = e"
  have hi: "ginv a \<in> G" by (rule inv_closed[OF ha])
  have "y = e \<cdot> y" by (simp add: left_unit[OF hy])
  also have "\<dots> = (ginv a \<cdot> a) \<cdot> y" by (simp add: left_inv[OF ha])
  also have "\<dots> = ginv a \<cdot> (a \<cdot> y)" by (simp add: assoc[OF hi ha hy])
  also have "\<dots> = ginv a" by (simp add: h r_unit[OF hi])
  finally show ?thesis .
qed

lemma fold_mem: "set xs \<subseteq> G \<Longrightarrow> foldr mult xs e \<in> G"
  by (induct xs) (auto intro: closed unit_closed)

lemma fold_snoc:
  assumes hy: "y \<in> G"
  shows "set xs \<subseteq> G \<Longrightarrow> foldr mult (xs @ [y]) e = foldr mult xs e \<cdot> y"
proof (induct xs)
  case Nil
  then show ?case by (simp add: r_unit[OF hy] left_unit[OF hy])
next
  case (Cons x xs)
  have hx: "x \<in> G" using Cons.prems by simp
  have hxs: "set xs \<subseteq> G" using Cons.prems by simp
  have hp: "foldr mult xs e \<in> G" by (rule fold_mem[OF hxs])
  have "foldr mult ((x # xs) @ [y]) e = x \<cdot> foldr mult (xs @ [y]) e"
    by (simp only: append_Cons foldr.simps comp_apply)
  also have "\<dots> = x \<cdot> (foldr mult xs e \<cdot> y)"
    by (simp only: Cons.hyps[OF hxs])
  also have "\<dots> = (x \<cdot> foldr mult xs e) \<cdot> y"
    by (simp add: assoc[OF hx hp hy])
  also have "\<dots> = foldr mult (x # xs) e \<cdot> y"
    by (simp only: foldr.simps comp_apply)
  finally show ?case .
qed

lemma pow_rep: "foldr mult (replicate n x) e = pow x n"
  by (induct n) simp_all

lemma pow_e: "pow e n = e"
proof (induct n)
  case 0
  then show ?case by simp
next
  case (Suc n)
  then show ?case by (simp add: left_unit[OF unit_closed])
qed

lemma iter_pow: "((\<lambda>y. x \<cdot> y) ^^ k) e = pow x k"
  by (induct k) simp_all

definition lsts :: "nat \<Rightarrow> 'a list set"
  where "lsts n = {xs. length xs = n \<and> set xs \<subseteq> G}"

definition SS :: "nat \<Rightarrow> 'a list set"
  where "SS n = {xs \<in> lsts n. foldr mult xs e = e}"

definition gfun :: "'a list \<Rightarrow> 'a list"
  where "gfun xs = xs @ [ginv (foldr mult xs e)]"

lemma lsts_card:
  assumes fG: "finite G"
  shows "finite (lsts n) \<and> card (lsts n) = card G ^ n"
proof (induct n)
  case 0
  have "lsts 0 = {[]}" unfolding lsts_def by auto
  then show ?case by simp
next
  case (Suc n)
  have eq: "lsts (Suc n) = (\<lambda>(x, ys). x # ys) ` (G \<times> lsts n)"
  proof (intro equalityI subsetI)
    fix zs assume hz: "zs \<in> lsts (Suc n)"
    then obtain x ys where zs: "zs = x # ys"
      unfolding lsts_def by (cases zs) auto
    show "zs \<in> (\<lambda>(x, ys). x # ys) ` (G \<times> lsts n)"
    proof (rule image_eqI[of _ _ "(x, ys)"])
      show "zs = (\<lambda>(x, ys). x # ys) (x, ys)" using zs by simp
    next
      show "(x, ys) \<in> G \<times> lsts n" using hz zs unfolding lsts_def by auto
    qed
  next
    fix zs assume "zs \<in> (\<lambda>(x, ys). x # ys) ` (G \<times> lsts n)"
    then obtain x ys where hx: "x \<in> G" and hys: "ys \<in> lsts n" and zs: "zs = x # ys"
      by auto
    then show "zs \<in> lsts (Suc n)" unfolding lsts_def by auto
  qed
  have inj: "inj_on (\<lambda>(x, ys). x # ys) (G \<times> lsts n)"
    by (auto simp: inj_on_def)
  have fin: "finite (lsts (Suc n))"
    unfolding eq by (rule finite_imageI) (rule finite_cartesian_product[OF fG conjunct1[OF Suc]])
  have card_eq: "card (lsts (Suc n)) = card G * card (lsts n)"
    unfolding eq by (subst card_image[OF inj]) (simp add: card_cartesian_product)
  show ?case using fin card_eq Suc by (simp add: power_Suc)
qed

lemma SS_card:
  assumes fG: "finite G" and hp: "0 < p"
  shows "finite (SS p) \<and> card (SS p) = card G ^ (p - 1)"
proof -
  have eq: "SS p = gfun ` lsts (p - 1)"
  proof (intro equalityI subsetI)
    fix zs assume hz: "zs \<in> SS p"
    then have mem: "length zs = p \<and> set zs \<subseteq> G \<and> foldr mult zs e = e"
      unfolding SS_def lsts_def by auto
    have hne: "zs \<noteq> []" using mem hp by auto
    define xs where "xs = butlast zs"
    define y where "y = last zs"
    have zs_eq: "zs = xs @ [y]"
      unfolding xs_def y_def using hne by simp
    have hlen: "length xs = p - 1" unfolding xs_def using mem by simp
    have hxs: "set xs \<subseteq> G" unfolding xs_def using mem by (auto dest: in_set_butlastD)
    have hy: "y \<in> G" unfolding y_def using mem hne by (auto intro: last_in_set)
    have hsnoc: "foldr mult zs e = foldr mult xs e \<cdot> y"
      by (subst zs_eq) (rule fold_snoc[OF hy hxs])
    have hfold: "foldr mult xs e \<cdot> y = e"
      by (rule trans[OF sym[OF hsnoc] conjunct2[OF conjunct2[OF mem]]])
    have hPG: "foldr mult xs e \<in> G" by (rule fold_mem[OF hxs])
    have hyy: "y = ginv (foldr mult xs e)" by (rule uniq_left[OF hPG hy hfold])
    show "zs \<in> gfun ` lsts (p - 1)"
    proof (rule image_eqI[of _ _ xs])
      show "zs = gfun xs" using zs_eq hyy by (simp add: gfun_def)
    next
      show "xs \<in> lsts (p - 1)" using hlen hxs unfolding lsts_def by simp
    qed
  next
    fix zs assume "zs \<in> gfun ` lsts (p - 1)"
    then obtain xs where hx: "xs \<in> lsts (p - 1)" and hz: "zs = gfun xs"
      by blast
    then have hl: "length xs = p - 1" and hs: "set xs \<subseteq> G"
      unfolding lsts_def by auto
    have hPG: "foldr mult xs e \<in> G" by (rule fold_mem[OF hs])
    have hgi: "ginv (foldr mult xs e) \<in> G" by (rule inv_closed[OF hPG])
    have hz': "zs = xs @ [ginv (foldr mult xs e)]"
      using hz by (simp add: gfun_def)
    have "foldr mult zs e = e"
    proof -
      have "foldr mult zs e = foldr mult xs e \<cdot> ginv (foldr mult xs e)"
        by (subst hz') (rule fold_snoc[OF hgi hs])
      then show ?thesis using r_inv[OF hPG] by simp
    qed
    moreover have "length zs = p" using hz hl hp by (simp add: gfun_def)
    moreover have "set zs \<subseteq> G" using hz hs hgi by (auto simp: gfun_def)
    ultimately show "zs \<in> SS p" unfolding SS_def lsts_def by simp
  qed
  have inj: "inj_on gfun (lsts (p - 1))"
  proof (rule inj_onI)
    fix a b
    assume ha: "a \<in> lsts (p - 1)" and hb: "b \<in> lsts (p - 1)" and hab: "gfun a = gfun b"
    then have "butlast (gfun a) = butlast (gfun b)" by simp
    then show "a = b" by (simp add: gfun_def)
  qed
  have cnt: "finite (lsts (p - 1)) \<and> card (lsts (p - 1)) = card G ^ (p - 1)"
    by (rule lsts_card[OF fG])
  have "finite (SS p)" unfolding eq by (rule finite_imageI) (rule conjunct1[OF cnt])
  moreover have "card (SS p) = card G ^ (p - 1)"
    unfolding eq by (subst card_image[OF inj]) (rule conjunct2[OF cnt])
  ultimately show ?thesis by blast
qed

lemma rot_mem:
  assumes hp: "0 < p" and hx: "xs \<in> SS p"
  shows "rotate1 xs \<in> SS p"
proof -
  have mem: "length xs = p \<and> set xs \<subseteq> G \<and> foldr mult xs e = e"
    using hx unfolding SS_def lsts_def by auto
  obtain x ys where xs: "xs = x # ys"
    using mem hp by (cases xs) auto
  have hxG: "x \<in> G" and hysG: "set ys \<subseteq> G" using mem xs by auto
  have hPy: "foldr mult ys e \<in> G" by (rule fold_mem[OF hysG])
  have hfx: "x \<cdot> foldr mult ys e = e" using mem xs by simp
  have hgy: "foldr mult ys e = ginv x" by (rule uniq_left[OF hxG hPy hfx])
  have hrot: "rotate1 xs = ys @ [x]" using xs by simp
  have hl': "length (ys @ [x]) = p" using mem xs by simp
  have hs': "set (ys @ [x]) \<subseteq> G" using mem xs by auto
  have hf': "foldr mult (ys @ [x]) e = e"
  proof -
    have "foldr mult (ys @ [x]) e = foldr mult ys e \<cdot> x"
      by (rule fold_snoc[OF hxG hysG])
    then show ?thesis using hgy left_inv[OF hxG] by simp
  qed
  show ?thesis
    unfolding SS_def lsts_def using hrot hl' hs' hf' by simp
qed

end

section \<open>Fixed points of rotation\<close>

lemma fixed_all: "ys @ [x] = x # ys \<Longrightarrow> \<forall>y\<in>set ys. y = x"
  by (induct ys) auto

lemma all_eq_replicate: "\<forall>y\<in>set ys. y = x \<Longrightarrow> ys = replicate (length ys) x"
  by (induct ys) auto

lemma fixed_rot:
  assumes ne: "xs \<noteq> []" and fx: "rotate1 xs = xs"
  shows "xs = replicate (length xs) (hd xs)"
proof -
  obtain x ys where hx: "xs = x # ys" using ne by (cases xs) auto
  have h1: "ys @ [x] = x # ys" using fx hx by simp
  have h2: "\<forall>y\<in>set ys. y = x" using fixed_all[OF h1] .
  have h3: "ys = replicate (length ys) x" using all_eq_replicate[OF h2] .
  have h4: "xs = x # replicate (length ys) x"
    by (subst hx) (rule arg_cong[OF h3, of "Cons x"])
  show ?thesis by (simp add: h4)
qed

lemma rot_iter: "length xs = n \<Longrightarrow> (rotate1 ^^ n) xs = xs"
proof -
  assume hl: "length xs = n"
  have "rotate n xs = xs" by (rule rotate_id) (simp add: hl)
  then show ?thesis by (simp add: rotate_def)
qed

section \<open>Cauchy's theorem\<close>

context grp
begin

text \<open>Step 1: the tuple set has size divisible by \<open>p\<close>, the rotation action has
  \<open>p\<close>-divisible fixed-point set, and this forces a non-trivial constant tuple.\<close>

lemma fixed_second:
  assumes fG: "finite G" and pp: "prime p" and hdvd: "p dvd card G"
  shows "\<exists>x\<in>G. x \<noteq> e \<and> pow x p = e"
proof -
  have hp: "0 < p" using pp unfolding prime_def by auto
  have hp2: "2 \<le> p" using pp unfolding prime_def by auto
  have SSc: "finite (SS p) \<and> card (SS p) = card G ^ (p - 1)"
    by (rule SS_card[OF fG hp])
  have hpos: "0 < p - 1" using hp2 by simp
  have cardG_dvd: "card G dvd card G ^ (p - 1)"
    by (rule dvd_power) (rule disjI1[OF hpos])
  have hdvdS: "p dvd card (SS p)"
    by (subst conjunct2[OF SSc]) (rule dvd_trans[OF hdvd cardG_dvd])
  have rot_inv: "\<forall>xs\<in>SS p. rotate1 xs \<in> SS p"
  proof (intro ballI)
    fix xs assume hx: "xs \<in> SS p"
    show "rotate1 xs \<in> SS p" by (rule rot_mem[OF hp hx])
  qed
  have rot_it: "\<forall>xs\<in>SS p. (rotate1 ^^ p) xs = xs"
  proof (intro ballI)
    fix xs assume hx: "xs \<in> SS p"
    have "length xs = p" using hx unfolding SS_def lsts_def by auto
    then show "(rotate1 ^^ p) xs = xs" by (rule rot_iter)
  qed
  define F where "F = {xs \<in> SS p. rotate1 xs = xs}"
  note orb0 = orbit_decomp[where f = rotate1, OF pp]
  note orb1 = spec[OF orb0, where x = "card (SS p)"]
  note orb2 = spec[OF orb1, where x = "SS p"]
  note finS = conjunct1[OF SSc]
  have kex: "\<exists>k. card (SS p) = card {x \<in> SS p. rotate1 x = x} + p * k"
    by (rule mp[OF mp[OF mp[OF mp[OF orb2 refl] finS] rot_inv] rot_it])
  have kex': "\<exists>k. card (SS p) = card F + p * k"
    unfolding F_def by (rule kex)
  obtain k where kk: "card (SS p) = card F + p * k"
    using kex' by blast
  have Fsub: "F \<subseteq> SS p" unfolding F_def by auto
  have Ffin: "finite F" using finite_subset[OF Fsub conjunct1[OF SSc]] .
  have rep_mem: "replicate p e \<in> SS p"
  proof -
    have hs: "set (replicate p e) \<subseteq> G" by (induct p) (simp_all add: unit_closed)
    have hf: "foldr mult (replicate p e) e = e"
      by (rule trans[OF pow_rep[where x=e and n=p] pow_e[where n=p]])
    have hl: "length (replicate p e) = p" by simp
    show ?thesis unfolding SS_def lsts_def by (simp only: mem_Collect_eq hl hs hf)
  qed
  have rep_F: "replicate p e \<in> F"
    unfolding F_def using rep_mem by simp
  have Fne: "F \<noteq> {}" using rep_F by auto
  have Fpos: "0 < card F"
    by (simp add: card_gt_0_iff Ffin Fne)
  have pk: "p dvd p * k" by simp
  have Fdvd: "p dvd card F"
  proof -
    have "p dvd card F + p * k" by (subst kk[symmetric]) (rule hdvdS)
    then show ?thesis using dvd_add_left_iff[OF pk] by blast
  qed
  have pF: "p \<le> card F" using Fdvd Fpos by (rule dvd_imp_le)
  have ex: "\<exists>zs. zs \<in> F \<and> zs \<noteq> replicate p e"
  proof (rule ccontr)
    assume hcon: "\<not> (\<exists>zs. zs \<in> F \<and> zs \<noteq> replicate p e)"
    have Fsub1: "F \<subseteq> {replicate p e}" using hcon by auto
    have "card F \<le> card {replicate p e}" by (rule card_mono) (simp_all add: Fsub1)
    have "card F \<le> 1" using \<open>card F \<le> card {replicate p e}\<close> by simp
    then show False using pF hp2 by linarith
  qed
  obtain zs where zsF: "zs \<in> F" and zsne: "zs \<noteq> replicate p e" using ex by blast
  have zsSS: "zs \<in> SS p" and zsrot: "rotate1 zs = zs"
    using zsF unfolding F_def by auto
  have zmem: "length zs = p \<and> set zs \<subseteq> G \<and> foldr mult zs e = e"
    using zsSS unfolding SS_def lsts_def by auto
  have zne: "zs \<noteq> []" using zmem hp by auto
  have zrep: "zs = replicate p (hd zs)"
    by (rule trans[OF fixed_rot[OF zne zsrot]]) (simp only: conjunct1[OF zmem])
  have xG: "hd zs \<in> G" using hd_in_set[OF zne] zmem by auto
  have xne: "hd zs \<noteq> e" using zrep zsne by auto
  have px: "pow (hd zs) p = e"
  proof -
    have hf: "foldr mult (replicate p (hd zs)) e = e"
      by (subst zrep[symmetric]) (rule conjunct2[OF conjunct2[OF zmem]])
    show ?thesis by (rule trans[OF pow_rep[symmetric] hf])
  qed
  show ?thesis using xG xne px by blast
qed

end

theorem (in grp) cauchy:
  assumes "finite G" and "prime p" and "p dvd card G"
  shows "\<exists>x\<in>G. pow x p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow x k \<noteq> e)"
proof -
  obtain x where xG: "x \<in> G" and xne: "x \<noteq> e" and px: "pow x p = e"
    using fixed_second[OF assms(1) assms(2) assms(3)] by blast
  have iter_p: "((\<lambda>y. x \<cdot> y) ^^ p) e = e"
    by (simp add: iter_pow px)
  have order: "\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow x k \<noteq> e"
  proof (intro allI impI notI)
    fix k :: nat
    assume k0: "0 < k" and kp: "k < p" and hk: "pow x k = e"
    have iter_k: "((\<lambda>y. x \<cdot> y) ^^ k) e = e"
      by (simp add: iter_pow hk)
    have "(\<lambda>y. x \<cdot> y) e = e"
      by (rule prime_fix[OF assms(2) k0 kp iter_k iter_p])
    then have "x \<cdot> e = e" by simp
    then have "x = e" using r_unit[OF xG] by simp
    with xne show False by contradiction
  qed
  show ?thesis using xG px order by blast
qed

end
