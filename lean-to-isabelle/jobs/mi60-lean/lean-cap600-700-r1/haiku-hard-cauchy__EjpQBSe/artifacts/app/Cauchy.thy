theory Cauchy
  imports Group_Axioms
begin

section \<open>Arithmetic\<close>

lemma prime_gcd_one:
  assumes pp: "prime p" and d0: "0 < d" and dp: "d < p"
  shows "gcd p d = 1"
proof -
  have "gcd p d dvd p" by simp
  with pp have one_or_p: "gcd p d = 1 \<or> gcd p d = p" unfolding prime_def by blast
  have "gcd p d \<noteq> p"
  proof
    assume eq: "gcd p d = p"
    have "gcd p d dvd d" by simp
    with eq have "p dvd d" by simp
    hence "p \<le> d" using d0 by (rule dvd_imp_le)
    with dp show False by simp
  qed
  with one_or_p show ?thesis by blast
qed

section \<open>Iterates of one map\<close>

lemma funpow_Suc_left: "(f ^^ Suc n) x = f ((f ^^ n) x)"
  by (simp add: funpow_Suc_right funpow_swap1)

lemma funpow_mult_fix:
  assumes "(f ^^ m) x = x"
  shows "(f ^^ (m * q)) x = x"
proof (induction q)
  case 0
  then show ?case by simp
next
  case (Suc q)
  have "(f ^^ (m * Suc q)) x = (f ^^ m) ((f ^^ (m * q)) x)"
    by (simp add: mult_Suc funpow_add)
  also have "\<dots> = x" using Suc.IH assms by simp
  finally show ?case .
qed

lemma funpow_mod_fix:
  assumes "(f ^^ m) x = x"
  shows "(f ^^ n) x = (f ^^ (n mod m)) x"
proof -
  have n_eq: "n = n mod m + m * (n div m)" by (rule mod_mult_div_eq[symmetric])
  have "(f ^^ n) x = (f ^^ (n mod m + m * (n div m))) x"
    by (rule arg_cong[of n _ "\<lambda>k. (f ^^ k) x"]) (rule n_eq)
  also have "\<dots> = (f ^^ (n mod m)) ((f ^^ (m * (n div m))) x)"
    by (simp only: funpow_add comp_apply)
  also have "\<dots> = (f ^^ (n mod m)) x"
  proof -
    have "(f ^^ (m * (n div m))) x = x" by (rule funpow_mult_fix[OF assms])
    thus ?thesis by simp
  qed
  finally show ?thesis .
qed

lemma funpow_mem:
  assumes fS: "f ` S \<subseteq> S" and uS: "u \<in> S"
  shows "(f ^^ i) u \<in> S"
proof (induction i)
  case 0
  then show ?case using uS by simp
next
  case (Suc i)
  then show ?case using fS by (auto simp: funpow_Suc_left)
qed

lemma funpow_inj_on:
  assumes inj: "inj_on f S" and fS: "f ` S \<subseteq> S"
  shows "inj_on (f ^^ i) S"
proof (induction i)
  case 0
  then show ?case by simp
next
  case (Suc i)
  show ?case
  proof (rule inj_onI)
    fix u v
    assume hu: "u \<in> S" and hv: "v \<in> S" and eq: "(f ^^ Suc i) u = (f ^^ Suc i) v"
    have "f ((f ^^ i) u) = f ((f ^^ i) v)" using eq by (simp add: funpow_Suc_left)
    moreover have "(f ^^ i) u \<in> S" and "(f ^^ i) v \<in> S"
      by (rule funpow_mem[OF fS hu], rule funpow_mem[OF fS hv])
    ultimately have "(f ^^ i) u = (f ^^ i) v" by (rule inj_onD[OF inj])
    from inj_onD[OF Suc.IH this hu hv] show "u = v" .
  qed
qed

lemma fixpt_pow:
  assumes fz: "f z = z"
  shows "(f ^^ n) z = z"
proof (induction n)
  case 0
  then show ?case by simp
next
  case (Suc n)
  then show ?case by (simp add: funpow_Suc_left fz)
qed

lemma gcd_fix_pt:
  fixes f :: "'a \<Rightarrow> 'a" and x :: 'a
  shows "(f ^^ a) x = x \<Longrightarrow> (f ^^ b) x = x \<Longrightarrow> (f ^^ gcd a b) x = x"
proof (induction a b rule: gcd_nat_induct)
  case (base m)
  then show ?case by simp
next
  case (step m n)
  have hm: "(f ^^ m) x = x" using step.prems(1) .
  have hn: "(f ^^ n) x = x" using step.prems(2) .
  have hr: "(f ^^ (m mod n)) x = x"
  proof -
    have "(f ^^ m) x = (f ^^ (m mod n)) x" by (rule funpow_mod_fix[OF hn])
    thus ?thesis using hm by simp
  qed
  have ih: "(f ^^ gcd n (m mod n)) x = x" using step.IH[OF hn hr] .
  show ?case
  proof (cases "n = 0")
    case True
    with hm show ?thesis by simp
  next
    case False
    have "gcd m n = gcd n (m mod n)" by (rule gcd_non_0_nat[OF False])
    with ih show ?thesis by simp
  qed
qed

section \<open>Orbit counting modulo a prime\<close>

text \<open>If a map @{term f} sends a finite set @{term S} into itself, injectively, and every point
  returns after exactly dividing @{term p} steps, then @{term "card S"} and the number of fixed
  points agree modulo @{term p}.\<close>

lemma orbit_count:
  fixes f :: "'a \<Rightarrow> 'a" and p :: nat
  assumes pp: "prime p"
  shows "finite S \<Longrightarrow> f ` S \<subseteq> S \<Longrightarrow> inj_on f S \<Longrightarrow> (\<forall>x\<in>S. (f ^^ p) x = x)
    \<Longrightarrow> \<exists>k. card S = card {x \<in> S. f x = x} + p * k"
proof (induction S rule: finite_psubset_induct)
  case (psubset S)
  show ?case
  proof -
    assume fin: "finite S" and fS: "f ` S \<subseteq> S" and inj: "inj_on f S"
      and root: "\<forall>x\<in>S. (f ^^ p) x = x"
    show "\<exists>k. card S = card {x \<in> S. f x = x} + p * k"
    proof (cases "\<forall>x\<in>S. f x = x")
      case True
      have "{x \<in> S. f x = x} = S" using True by auto
      then show ?thesis by (intro exI[of _ 0]) simp
    next
      case False
      then obtain x where xS: "x \<in> S" and fx: "f x \<noteq> x" by blast
      have p_gt1: "1 < p" using pp unfolding prime_def by simp
      have p_pos: "0 < p" using p_gt1 by simp
      obtain q where pq: "p = Suc q" using p_pos by (cases p) auto
      have x_root: "(f ^^ p) x = x" using root xS by blast
      obtain Orb where Orb_def: "Orb = (\<lambda>i. (f ^^ i) x) ` {..<p}" by blast
      have orb_mem: "\<And>i. (f ^^ i) x \<in> S" by (rule funpow_mem[OF fS xS])
      have O_sub: "Orb \<subseteq> S" unfolding Orb_def using orb_mem by auto
      have fin_O: "finite Orb" unfolding Orb_def by simp
      have x_in_O: "x \<in> Orb"
        unfolding Orb_def by (rule image_eqI[of _ _ 0]) (simp_all add: p_pos)
      (* a point of period strictly less than p, other than x itself, cannot exist *)
      have no_short: "\<And>d. 0 < d \<Longrightarrow> d < p \<Longrightarrow> (f ^^ d) x \<noteq> x"
      proof
        fix d assume d0: "0 < d" and dp: "d < p" and dx: "(f ^^ d) x = x"
        have "(f ^^ gcd p d) x = x" using gcd_fix_pt[OF x_root dx] .
        hence "(f ^^ 1) x = x" using prime_gcd_one[OF pp d0 dp] by simp
        thus False using fx by simp
      qed
      (* the orbit of x has exactly p distinct points *)
      have inj_idx: "\<And>i j. i < j \<Longrightarrow> j < p \<Longrightarrow> (f ^^ i) x \<noteq> (f ^^ j) x"
      proof
        fix i j assume ij: "i < j" and jp: "j < p" and eq: "(f ^^ i) x = (f ^^ j) x"
        have split: "(f ^^ j) x = (f ^^ i) ((f ^^ (j - i)) x)"
        proof -
          have "(f ^^ j) x = (f ^^ (i + (j - i))) x" using ij by (simp add: less_imp_le)
          also have "\<dots> = (f ^^ i) ((f ^^ (j - i)) x)" by (simp add: funpow_add)
          finally show ?thesis .
        qed
        have dmem: "(f ^^ (j - i)) x \<in> S" using orb_mem by blast
        have dx: "(f ^^ i) ((f ^^ (j - i)) x) = (f ^^ i) x" using eq split by simp
        have "(f ^^ (j - i)) x = x"
          by (rule inj_onD[OF funpow_inj_on[OF inj fS] dx dmem xS])
        moreover have "0 < j - i" and "j - i < p" using ij jp by simp_all
        ultimately show False using no_short by blast
      qed
      have inj_O: "inj_on (\<lambda>i. (f ^^ i) x) {..<p}"
      proof (rule inj_onI)
        fix i j
        assume hi: "i \<in> {..<p}" and hj: "j \<in> {..<p}" and eq: "(f ^^ i) x = (f ^^ j) x"
        show "i = j"
        proof (rule ccontr)
          assume neq: "i \<noteq> j"
          hence "i < j \<or> j < i" by auto
          thus False
          proof
            assume "i < j"
            moreover have "j < p" using hj by simp
            ultimately show False using inj_idx eq by blast
          next
            assume "j < i"
            moreover have "i < p" using hi by simp
            ultimately show False using inj_idx eq by blast
          qed
        qed
      qed
      have card_O: "card Orb = p" unfolding Orb_def using inj_O by (simp add: card_image)
      have cardS: "card Orb \<le> card S" using card_mono[OF fin O_sub] .
      (* the complement of the orbit *)
      obtain S' where S'_def: "S' = S - Orb" by blast
      have S'_sub: "S' \<subseteq> S" unfolding S'_def by auto
      have fin': "finite S'" using fin S'_sub by (rule finite_subset)
      have x_not_S': "x \<notin> S'" unfolding S'_def using x_in_O by auto
      have S'_psub: "S' \<subset> S" using S'_sub x_not_S' xS by blast
      have fS': "f ` S' \<subseteq> S'"
      proof (rule image_subsetI)
        fix y assume yS': "y \<in> S'"
        hence yS: "y \<in> S" and yO: "y \<notin> Orb" unfolding S'_def by auto
        have fyS: "f y \<in> S" using fS yS by blast
        have fyO: "f y \<notin> Orb"
        proof
          assume fyO: "f y \<in> Orb"
          then obtain i where hi: "i < p" and fy: "f y = (f ^^ i) x"
            unfolding Orb_def by auto
          have cases_i: "i = 0 \<or> (\<exists>k. i = Suc k)" by (cases i) auto
          then show False
          proof
            assume i0: "i = 0"
            have fy0: "f y = x" using fy i0 by simp
            have "(f ^^ p) y = y" using root yS by blast
            moreover have "(f ^^ p) y = (f ^^ q) (f y)" using pq by (simp add: funpow_Suc_right)
            ultimately have "y = (f ^^ q) x" using fy0 by simp
            hence "y \<in> Orb" unfolding Orb_def using pq by auto
            with yO show False by blast
          next
            assume "\<exists>k. i = Suc k"
            then obtain k where ik: "i = Suc k" by blast
            have fk: "f ((f ^^ k) x) = f y" using fy ik by simp
            have "(f ^^ k) x \<in> S" using orb_mem by blast
            have "(f ^^ k) x = y" using inj_onD[OF inj fk _ yS] by blast
            hence "y \<in> Orb" unfolding Orb_def using ik hi by auto
            with yO show False by blast
          qed
        qed
        show "f y \<in> S'" unfolding S'_def using fyS fyO by simp
      qed
      have inj': "inj_on f S'" using inj S'_sub by (rule inj_on_subset)
      have root': "\<forall>y\<in>S'. (f ^^ p) y = y" using root S'_sub by blast
      (* fixed points are not in the orbit *)
      have fixO: "\<And>z. z \<in> Orb \<Longrightarrow> f z = z \<Longrightarrow> False"
      proof -
        fix z assume zO: "z \<in> Orb" and fz: "f z = z"
        then obtain i where hi: "i < p" and zi: "z = (f ^^ i) x" unfolding Orb_def by auto
        have key: "(f ^^ (p - i + i)) x = (f ^^ (p - i)) ((f ^^ i) x)" by (simp add: funpow_add)
        have "p - i + i = p" using hi by simp
        hence "(f ^^ p) x = (f ^^ (p - i)) z" using key zi by simp
        have zfix: "(f ^^ (p - i)) z = z" by (rule fixpt_pow[OF fz])
        hence "x = z" using x_root \<open>(f ^^ p) x = (f ^^ (p - i)) z\<close> by simp
        hence "f x = x" using fz by simp
        thus False using fx by contradiction
      qed
      have fix_eq: "{z \<in> S. f z = z} = {z \<in> S'. f z = z}"
      proof
        show "{z \<in> S. f z = z} \<subseteq> {z \<in> S'. f z = z}"
        proof
          fix z assume "z \<in> {z \<in> S. f z = z}"
          hence zS: "z \<in> S" and fz: "f z = z" by auto
          have "z \<notin> Orb" using fixO fz by blast
          thus "z \<in> {z \<in> S'. f z = z}" unfolding S'_def using zS fz by simp
        qed
      next
        show "{z \<in> S'. f z = z} \<subseteq> {z \<in> S. f z = z}" using S'_sub by auto
      qed
      have fixcard: "card {z \<in> S. f z = z} = card {z \<in> S'. f z = z}" using fix_eq by simp
      have IH: "\<exists>k. card S' = card {z \<in> S'. f z = z} + p * k"
        using psubset.IH[OF S'_psub fin' fS' inj' root'] .
      obtain k where kS: "card S' = card {z \<in> S'. f z = z} + p * k" using IH by blast
      have diff: "card (S - Orb) = card S - card Orb" by (rule card_Diff_subset[OF fin_O O_sub])
      have cardS_eq: "card S = card S' + p"
        using diff cardS card_O by (simp add: S'_def) omega
      have e2: "p * Suc k = p * k + p" by (rule trans[OF mult_Suc add.commute])
      have shift: "card S' + p = (card {z \<in> S'. f z = z} + p * k) + p"
        using kS by (rule arg_cong[where f="\<lambda>t. t + p"])
      have e3: "card S = (card {z \<in> S'. f z = z} + p * k) + p"
        by (rule trans[OF cardS_eq shift])
      have "card S = card {z \<in> S. f z = z} + p * Suc k"
        by (simp only: fixcard e2 add.assoc e3)
      then show ?thesis by (rule exI[of _ "Suc k"])
    qed
  qed
qed

section \<open>Group facts from the basic axioms\<close>

context grp
begin

lemma idem_is_e:
  assumes tG: "t \<in> G" and tt: "t \<cdot> t = t"
  shows "t = e"
proof -
  have vG: "ginv t \<in> G" by (rule inv_closed[OF tG])
  have "t = e \<cdot> t" using left_unit[OF tG] by simp
  also have "\<dots> = (ginv t \<cdot> t) \<cdot> t" using left_inv[OF tG] by simp
  also have "\<dots> = ginv t \<cdot> (t \<cdot> t)" by (rule assoc[OF vG tG tG])
  also have "\<dots> = ginv t \<cdot> t" using tt by simp
  also have "\<dots> = e" by (rule left_inv[OF tG])
  finally show ?thesis .
qed

lemma right_inv:
  assumes xG: "x \<in> G"
  shows "x \<cdot> ginv x = e"
proof -
  have uG: "ginv x \<in> G" by (rule inv_closed[OF xG])
  have tG: "x \<cdot> ginv x \<in> G" by (rule closed[OF xG uG])
  have tt: "(x \<cdot> ginv x) \<cdot> (x \<cdot> ginv x) = x \<cdot> ginv x"
  proof -
    have "(x \<cdot> ginv x) \<cdot> (x \<cdot> ginv x) = x \<cdot> (ginv x \<cdot> (x \<cdot> ginv x))"
      by (rule assoc[OF xG uG tG])
    also have "\<dots> = x \<cdot> ((ginv x \<cdot> x) \<cdot> ginv x)"
      using assoc[OF uG xG uG] by simp
    also have "\<dots> = x \<cdot> (e \<cdot> ginv x)" using left_inv[OF xG] by simp
    also have "\<dots> = x \<cdot> ginv x" using left_unit[OF uG] by simp
    finally show ?thesis .
  qed
  show ?thesis by (rule idem_is_e[OF tG tt])
qed

lemma right_unit:
  assumes xG: "x \<in> G"
  shows "x \<cdot> e = x"
proof -
  have uG: "ginv x \<in> G" by (rule inv_closed[OF xG])
  have "x \<cdot> e = x \<cdot> (ginv x \<cdot> x)" using left_inv[OF xG] by simp
  also have "\<dots> = (x \<cdot> ginv x) \<cdot> x" by (rule assoc[symmetric, OF xG uG xG])
  also have "\<dots> = x" using right_inv[OF xG] left_unit[OF xG] by simp
  finally show ?thesis .
qed

lemma left_cancel:
  assumes xG: "x \<in> G" and yG: "y \<in> G" and zG: "z \<in> G" and eq: "x \<cdot> y = x \<cdot> z"
  shows "y = z"
proof -
  have uG: "ginv x \<in> G" by (rule inv_closed[OF xG])
  have "y = e \<cdot> y" using left_unit[OF yG] by simp
  also have "\<dots> = (ginv x \<cdot> x) \<cdot> y" using left_inv[OF xG] by simp
  also have "\<dots> = ginv x \<cdot> (x \<cdot> y)" by (rule assoc[OF uG xG yG])
  also have "\<dots> = ginv x \<cdot> (x \<cdot> z)" using eq by simp
  also have "\<dots> = (ginv x \<cdot> x) \<cdot> z" by (rule assoc[symmetric, OF uG xG zG])
  also have "\<dots> = z" using left_inv[OF xG] left_unit[OF zG] by simp
  finally show ?thesis .
qed

lemma comm_inv:
  assumes xG: "x \<in> G" and yG: "y \<in> G" and eq: "x \<cdot> y = e"
  shows "y \<cdot> x = e"
proof -
  have "y = ginv x"
    by (rule left_cancel[OF xG yG inv_closed[OF xG]]) (simp add: eq right_inv[OF xG])
  thus ?thesis using left_inv[OF xG] by simp
qed

subsection \<open>Powers\<close>

lemma pow_closed:
  assumes xG: "x \<in> G"
  shows "pow x n \<in> G"
proof (induction n)
  case 0
  then show ?case using unit_closed by simp
next
  case (Suc n)
  then show ?case using closed[OF xG Suc.IH] by simp
qed

lemma pow_add:
  assumes xG: "x \<in> G"
  shows "pow x (m + n) = pow x m \<cdot> pow x n"
proof (induction m)
  case 0
  have nG: "pow x n \<in> G" by (rule pow_closed[OF xG])
  then show ?case using left_unit[OF nG] by simp
next
  case (Suc m)
  have "pow x (Suc m + n) = x \<cdot> pow x (m + n)" by simp
  also have "\<dots> = x \<cdot> (pow x m \<cdot> pow x n)" using Suc.IH by simp
  also have "\<dots> = (x \<cdot> pow x m) \<cdot> pow x n"
    by (rule assoc[symmetric, OF xG pow_closed[OF xG] pow_closed[OF xG]])
  also have "\<dots> = pow x (Suc m) \<cdot> pow x n" by simp
  finally show ?case .
qed

lemma pow_one:
  assumes xG: "x \<in> G"
  shows "pow x 1 = x"
  using right_unit[OF xG] by simp

lemma pow_e: "pow e n = e"
proof (induction n)
  case 0
  then show ?case by simp
next
  case (Suc n)
  then show ?case using left_unit[OF unit_closed] by simp
qed

lemma pow_mult_e:
  assumes xG: "x \<in> G" and me: "pow x m = e"
  shows "pow x (m * q) = e"
proof (induction q)
  case 0
  then show ?case by simp
next
  case (Suc q)
  have "pow x (m * Suc q) = pow x m \<cdot> pow x (m * q)"
    by (simp add: mult_Suc pow_add[OF xG])
  also have "\<dots> = e" using me Suc.IH by (simp add: left_unit[OF unit_closed])
  finally show ?case .
qed

lemma pow_mod:
  assumes xG: "x \<in> G" and me: "pow x m = e"
  shows "pow x n = pow x (n mod m)"
proof -
  have "pow x n = pow x (n mod m + m * (n div m))" by (simp add: mod_mult_div_eq)
  also have "\<dots> = pow x (n mod m) \<cdot> pow x (m * (n div m))" by (rule pow_add[OF xG])
  also have "\<dots> = pow x (n mod m)"
  proof -
    have "pow x (m * (n div m)) = e" by (rule pow_mult_e[OF xG me])
    moreover have "pow x (n mod m) \<in> G" by (rule pow_closed[OF xG])
    ultimately show ?thesis using right_unit by simp
  qed
  finally show ?thesis .
qed

lemma pow_gcd:
  assumes xG: "x \<in> G"
  shows "pow x a = e \<Longrightarrow> pow x b = e \<Longrightarrow> pow x (gcd a b) = e"
proof (induction a b rule: gcd_nat_induct)
  case (base m)
  then show ?case by simp
next
  case (step m n)
  have hm: "pow x m = e" using step.prems(1) .
  have hn: "pow x n = e" using step.prems(2) .
  have hmod: "pow x m = pow x (m mod n)" by (rule pow_mod[OF xG hn])
  have hr: "pow x (m mod n) = e" by (rule trans[OF sym[OF hmod] hm])
  have ih: "pow x (gcd n (m mod n)) = e" using step.IH[OF hn hr] .
  show ?case
  proof (cases "n = 0")
    case True
    with hm show ?thesis by simp
  next
    case False
    have "gcd m n = gcd n (m mod n)" by (rule gcd_non_0_nat[OF False])
    with ih show ?thesis by simp
  qed
qed

subsection \<open>Finite lists of group elements\<close>

primrec lprod :: "'a list \<Rightarrow> 'a" where
  "lprod [] = e"
| "lprod (y # ys) = y \<cdot> lprod ys"

abbreviation SS :: "nat \<Rightarrow> 'a list set" where
  "SS p \<equiv> {xs. set xs \<subseteq> G \<and> length xs = p \<and> lprod xs = e}"

lemma lprod_closed: "set xs \<subseteq> G \<Longrightarrow> lprod xs \<in> G"
proof (induction xs)
  case Nil
  then show ?case using unit_closed by simp
next
  case (Cons a xs)
  show ?case
  proof -
    assume h: "set (a # xs) \<subseteq> G"
    hence aG: "a \<in> G" and xsG: "set xs \<subseteq> G" by auto
    have "lprod xs \<in> G" using Cons.IH[OF xsG] .
    thus ?thesis using closed[OF aG this] by simp
  qed
qed

lemma lprod_snoc: "set xs \<subseteq> G \<Longrightarrow> y \<in> G \<Longrightarrow> lprod (xs @ [y]) = lprod xs \<cdot> y"
proof (induction xs)
  case Nil
  show ?case
  proof -
    assume _: "set [] \<subseteq> G" and yG: "y \<in> G"
    show ?thesis by (simp add: right_unit[OF yG] left_unit[OF yG])
  qed
next
  case (Cons a xs)
  show ?case
  proof -
    assume h: "set (a # xs) \<subseteq> G" and yG: "y \<in> G"
    hence aG: "a \<in> G" and xsG: "set xs \<subseteq> G" by auto
    have "lprod ((a # xs) @ [y]) = a \<cdot> (lprod xs \<cdot> y)" using Cons.IH[OF xsG yG] by simp
    also have "\<dots> = (a \<cdot> lprod xs) \<cdot> y"
      by (rule assoc[symmetric, OF aG lprod_closed[OF xsG] yG])
    finally show ?thesis by simp
  qed
qed

lemma lprod_replicate:
  assumes xG: "x \<in> G"
  shows "lprod (replicate n x) = pow x n"
proof (induction n)
  case 0
  then show ?case by simp
next
  case (Suc n)
  then show ?case by simp
qed

end

section \<open>Rotation of tuples\<close>

primrec rot :: "'a list \<Rightarrow> 'a list" where
  "rot [] = []"
| "rot (y # ys) = ys @ [y]"

lemma rot_inj: "length xs = length ys \<Longrightarrow> rot xs = rot ys \<Longrightarrow> xs = ys"
proof (induction xs arbitrary: ys)
  case Nil
  then show ?case by simp
next
  case (Cons a as)
  then obtain b bs where ys: "ys = b # bs" by (cases ys) auto
  from Cons.prems ys have "as @ [a] = bs @ [b]" by simp
  moreover have "length as = length bs" using Cons.prems(1) ys by simp
  ultimately have "as = bs" and "[a] = [b]" by (rule append_inj)+
  thus ?case using ys by simp
qed

lemma rot_iter: "(rot ^^ length a) (a @ b) = b @ a"
proof (induction a arbitrary: b)
  case Nil
  then show ?case by simp
next
  case (Cons y a)
  have "(rot ^^ length (y # a)) ((y # a) @ b) = (rot ^^ length a) (rot (y # (a @ b)))"
    by (simp add: funpow_Suc_right)
  also have "\<dots> = (rot ^^ length a) (a @ (b @ [y]))" by simp
  also have "\<dots> = (b @ [y]) @ a" using Cons.IH by simp
  also have "\<dots> = b @ (y # a)" by simp
  finally show ?case by simp
qed

lemma rot_pow: "(rot ^^ length xs) xs = xs"
proof -
  have "(rot ^^ length xs) (xs @ []) = [] @ xs" by (rule rot_iter)
  thus ?thesis by simp
qed

lemma rot_replicate: "rot (replicate n y) = replicate n y"
proof (cases n)
  case 0
  then show ?thesis by simp
next
  case (Suc m)
  have "rot (replicate (Suc m) y) = replicate m y @ [y]" by simp
  also have "\<dots> = replicate (Suc m) y" by (rule replicate_append_same)
  finally show ?thesis using Suc by simp
qed

lemma cyc_fixed: "as @ [y] = y # as \<Longrightarrow> \<exists>n. as = replicate n y"
proof (induction as)
  case Nil
  then show ?case by (intro exI[of _ 0]) simp
next
  case (Cons a bs)
  have h: "a = y \<and> bs @ [y] = a # bs" using Cons.prems by simp
  hence ay: "a = y" and bsy: "bs @ [y] = y # bs" by auto
  obtain n where bn: "bs = replicate n y" using Cons.IH[OF bsy] by blast
  show ?case using ay bn by (intro exI[of _ "Suc n"]) simp
qed

lemma rot_fixed:
  assumes "rot xs = xs" and "xs \<noteq> []"
  shows "\<exists>y. xs = replicate (length xs) y"
proof (cases xs)
  case Nil
  with assms(2) show ?thesis by simp
next
  case (Cons y ys)
  have "ys @ [y] = y # ys" using assms(1) Cons by simp
  then obtain n where "ys = replicate n y" using cyc_fixed by blast
  thus ?thesis using Cons by (intro exI[of _ y]) simp
qed

context grp
begin

lemma rot_mem:
  assumes xs: "xs \<in> SS p" and p0: "0 < p"
  shows "rot xs \<in> SS p"
proof -
  from xs have sub: "set xs \<subseteq> G" and len: "length xs = p" and ev: "lprod xs = e" by auto
  from len p0 obtain y ys where xs': "xs = y # ys" by (cases xs) auto
  from sub xs' have yG: "y \<in> G" and ysG: "set ys \<subseteq> G" by auto
  have P: "lprod ys \<in> G" by (rule lprod_closed[OF ysG])
  have yP: "y \<cdot> lprod ys = e" using ev xs' by simp
  have Py: "lprod ys \<cdot> y = e" by (rule comm_inv[OF yG P yP])
  have rot_eq: "rot xs = ys @ [y]" using xs' by simp
  have "lprod (ys @ [y]) = e" using lprod_snoc[OF ysG yG] Py by simp
  moreover have "set (ys @ [y]) \<subseteq> G" using ysG yG by auto
  moreover have "length (ys @ [y]) = p" using len xs' by simp
  ultimately show ?thesis unfolding rot_eq by simp
qed

end

section \<open>Counting the tuples\<close>

lemma card_SS_eq:
  assumes fin: "finite G" and p0: "0 < p"
  shows "card (SS p) = card G ^ (p - 1)"
  sorry

end
