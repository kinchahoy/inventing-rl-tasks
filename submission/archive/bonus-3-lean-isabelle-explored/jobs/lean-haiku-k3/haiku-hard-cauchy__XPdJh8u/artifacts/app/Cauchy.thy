theory Cauchy
  imports Group_Axioms
begin


section \<open>Iterates of a map\<close>

lemma iter_Suc: "(f ^^ Suc n) x = f ((f ^^ n) x)"
  by simp

lemma iter_add: "(f ^^ (m + n)) x = (f ^^ m) ((f ^^ n) x)"
  by (simp add: funpow_add)

lemma iter_mult:
  assumes h: "(f ^^ m) a = a"
  shows "(f ^^ (m * q)) a = a"
  by (induction q) (simp_all add: iter_add h)

lemma iter_mod:
  assumes h: "(f ^^ p) x = x" and pos: "0 < p"
  shows "(f ^^ j) x = (f ^^ (j mod p)) x"
proof -
  have "(f ^^ j) x = (f ^^ (j mod p + p * (j div p))) x"
    by (simp add: mod_div_mult_eq)
  also have "\<dots> = (f ^^ (j mod p)) ((f ^^ (p * (j div p))) x)"
    by (rule iter_add)
  also have "\<dots> = (f ^^ (j mod p)) x"
    using iter_mult[OF h] by simp
  finally show ?thesis .
qed

lemma gcd_fixed:
  "(f ^^ m) a = a \<Longrightarrow> (f ^^ n) a = a \<Longrightarrow> (f ^^ gcd m n) a = a"
proof (induction m n rule: gcd_nat_induct)
  case (base m)
  then show ?case by simp
next
  case (step m n)
  note IH = step(2)
  assume hm: "(f ^^ m) a = a" and hn: "(f ^^ n) a = a"
  have hr: "(f ^^ (m mod n)) a = a"
  proof -
    have "(f ^^ m) a = (f ^^ (m mod n)) ((f ^^ (n * (m div n))) a)"
      by (simp add: iter_add[symmetric] mod_div_mult_eq)
    also have "\<dots> = (f ^^ (m mod n)) a"
      using iter_mult[OF hn] by simp
    finally show ?thesis using hm by simp
  qed
  have "(f ^^ gcd n (m mod n)) a = a"
    using IH hn hr by blast
  moreover have "gcd m n = gcd n (m mod n)"
    by (rule gcd_red_nat)
  ultimately show "(f ^^ gcd m n) a = a" by simp
qed

lemma prime_fix:
  fixes p k :: nat and f :: "'b \<Rightarrow> 'b" and a :: 'b
  assumes "prime p" "0 < k" "k < p" "(f ^^ k) a = a" "(f ^^ p) a = a"
  shows "f a = a"
proof -
  have dv: "gcd k p dvd p" by (rule gcd_dvd2)
  have g1: "gcd k p = 1 \<or> gcd k p = p"
    using \<open>prime p\<close> dv unfolding prime_def by blast
  have g2: "gcd k p \<noteq> p"
  proof
    assume "gcd k p = p"
    then have "p dvd k" using gcd_dvd1[of k p] by simp
    then have "p \<le> k" using \<open>0 < k\<close> dvd_imp_le by blast
    then show False using \<open>k < p\<close> by simp
  qed
  have g: "gcd k p = 1" using g1 g2 by blast
  have "(f ^^ gcd k p) a = a" by (rule gcd_fixed[OF assms(4) assms(5)])
  then show ?thesis using g by simp
qed

lemma fixed_orbit:
  assumes pos: "0 < p" and h: "(f ^^ p) x = x" and fi: "f ((f ^^ i) x) = (f ^^ i) x"
  shows "f x = x"
proof -
  obtain r where hr: "r = i mod p" by blast
  have r_lt: "r < p" using pos hr by simp
  have yr: "(f ^^ r) x = (f ^^ i) x"
    by (subst hr) (rule iter_mod[OF h pos, symmetric])
  have fy: "f ((f ^^ r) x) = (f ^^ r) x"
    by (metis yr fi)
  have fk: "\<And>m. (f ^^ m) ((f ^^ r) x) = (f ^^ r) x"
  proof -
    fix m
    show "(f ^^ m) ((f ^^ r) x) = (f ^^ r) x"
    proof (induction m)
      case 0
      then show ?case by simp
    next
      case (Suc m)
      then show ?case by (simp add: fy)
    qed
  qed
  have e1: "(f ^^ p) x = (f ^^ (p - r)) ((f ^^ r) x)"
  proof -
    have eq: "(p - r) + r = p" using r_lt by simp
    have "(f ^^ p) x = (f ^^ ((p - r) + r)) x" using eq by simp
    also have "\<dots> = (f ^^ (p - r)) ((f ^^ r) x)" by (rule iter_add)
    finally show ?thesis .
  qed
  have e2: "(f ^^ (p - r)) ((f ^^ r) x) = (f ^^ r) x" by (rule fk)
  have xy: "x = (f ^^ r) x" by (metis h e1 e2)
  have "f x = f ((f ^^ r) x)" by (rule arg_cong[OF xy])
  also have "\<dots> = (f ^^ r) x" by (rule fy)
  also have "\<dots> = x" by (rule xy[symmetric])
  finally show ?thesis .
qed

lemma orbit_no_coll:
  assumes pr: "prime p" and h: "(f ^^ p) x = x" and nf: "f x \<noteq> x"
    and lt: "i < j" and jp: "j < p"
  shows "(f ^^ i) x \<noteq> (f ^^ j) x"
proof
  assume eq: "(f ^^ i) x = (f ^^ j) x"
  have pos: "0 < p" using pr unfolding prime_def by auto
  have ji: "j - i + i = j" using lt by (simp add: less_imp_le)
  have e: "(f ^^ j) x = (f ^^ (j - i)) ((f ^^ i) x)"
  proof -
    have "(f ^^ j) x = (f ^^ (j - i + i)) x" using ji by simp
    also have "\<dots> = (f ^^ (j - i)) ((f ^^ i) x)" by (rule iter_add)
    finally show ?thesis .
  qed
  have k1: "(f ^^ (j - i)) ((f ^^ i) x) = (f ^^ i) x"
    using e eq by simp
  have k2: "(f ^^ p) ((f ^^ i) x) = (f ^^ i) x"
  proof -
    have a1: "(f ^^ (i + p)) x = (f ^^ i) ((f ^^ p) x)" by (rule iter_add)
    have a2: "(f ^^ p) ((f ^^ i) x) = (f ^^ (i + p)) x"
      using iter_add[where f=f and m=p and n=i and x=x] by (simp add: add.commute)
    show ?thesis using a1 a2 h by simp
  qed
  have pk1: "0 < j - i" using lt by simp
  have pk2: "j - i < p" using jp le_less_trans[OF diff_le_self[of j i] jp] by simp
  have fy: "f ((f ^^ i) x) = (f ^^ i) x"
    using prime_fix[of p "j - i" f "(f ^^ i) x"] pr pk1 pk2 k1 k2 by blast
  then have "f x = x" using fixed_orbit[OF pos h] by blast
  then show False using nf by simp
qed

lemma all_eq_replicate: "(\<forall>z\<in>set xs. z = y) \<Longrightarrow> xs = replicate (length xs) y"
  by (induction xs) auto

lemma rot_fix_elems: "zs @ [x] = x # zs \<Longrightarrow> \<forall>y\<in>set zs. y = x"
proof (induction zs)
  case Nil
  then show ?case by simp
next
  case (Cons z zs)
  have h: "z = x \<and> zs @ [x] = z # zs" using Cons.prems by simp
  then have "zs @ [x] = x # zs" by simp
  then have "\<forall>y\<in>set zs. y = x" using Cons.IH by blast
  with h show ?case by auto
qed

section \<open>Orbit counting\<close>


lemma orbit_main:
  fixes f :: "'b \<Rightarrow> 'b" and p n :: nat and X :: "'b set"
  assumes pr: "prime p"
    and IH: "\<And>X. finite X \<Longrightarrow> (\<forall>x\<in>X. f x \<in> X) \<Longrightarrow> (\<forall>x\<in>X. (f ^^ p) x = x) \<Longrightarrow>
      card {x\<in>X. f x \<noteq> x} \<le> n \<Longrightarrow> p dvd card {x\<in>X. f x \<noteq> x}"
    and fin: "finite X" and cl: "\<forall>x\<in>X. f x \<in> X" and per: "\<forall>x\<in>X. (f ^^ p) x = x"
    and hle: "card {x\<in>X. f x \<noteq> x} \<le> Suc n"
    and x0X: "x0 \<in> X" and x0N: "f x0 \<noteq> x0"
  shows "p dvd card {x\<in>X. f x \<noteq> x}"
proof -
  have p1: "1 \<le> p" using pr unfolding prime_def by auto
  have pos: "0 < p" using p1 by simp
have per0: "(f ^^ p) x0 = x0" using per x0X by simp
have inX: "\<And>j. (f ^^ j) x0 \<in> X"
proof -
  fix j
  show "(f ^^ j) x0 \<in> X"
  proof (induction j)
    case 0
    then show ?case using x0X by simp
  next
    case (Suc j)
    then show ?case using cl by (auto simp: iter_Suc)
  qed
qed
define Orb where "Orb = (\<lambda>j. (f ^^ j) x0) ` {0..<p}"
have Oeq: "\<And>k. (f ^^ k) x0 \<in> Orb"
proof -
  fix k
  have "(f ^^ k) x0 = (f ^^ (k mod p)) x0" by (rule iter_mod[OF per0 pos])
  moreover have "k mod p \<in> {0..<p}" using pos by simp
  ultimately show "(f ^^ k) x0 \<in> Orb" unfolding Orb_def by auto
qed
have fixed_nowhere: "\<forall>i. f ((f ^^ i) x0) \<noteq> (f ^^ i) x0"
    by (metis fixed_orbit[OF pos per0] x0N)
have inj: "inj_on (\<lambda>j. (f ^^ j) x0) {0..<p}"
proof (rule inj_onI)
  fix i j
  assume hi: "i \<in> {0..<p}" and hj: "j \<in> {0..<p}" and eq: "(f ^^ i) x0 = (f ^^ j) x0"
  show "i = j"
  proof (rule ccontr)
    assume ne: "i \<noteq> j"
    then consider "i < j" | "j < i" by (meson nat_neq_iff)
    then show False
    proof cases
      case 1
      have jp: "j < p" using hj by simp
      show ?thesis using orbit_no_coll[OF pr per0 x0N 1 jp] eq by auto
    next
      case 2
      have ip: "i < p" using hi by simp
      show ?thesis using orbit_no_coll[OF pr per0 x0N 2 ip] eq by auto
    qed
  qed
qed
have O_sub: "Orb \<subseteq> {x\<in>X. f x \<noteq> x}"
proof
  fix y assume "y \<in> Orb"
  then obtain i where hy: "y = (f ^^ i) x0" unfolding Orb_def by auto
  show "y \<in> {x\<in>X. f x \<noteq> x}" using hy inX fixed_nowhere by auto
qed
have card_O: "card Orb = p"
proof -
  have "card Orb = card {0..<p}" unfolding Orb_def by (rule card_image[OF inj])
  then show ?thesis by simp
qed
have fin_O: "finite Orb" unfolding Orb_def by simp
have fin_N: "finite {x\<in>X. f x \<noteq> x}" by (rule finite_subset[OF _ fin]) auto
have card_le: "p \<le> card {x\<in>X. f x \<noteq> x}"
  using card_mono[OF fin_N O_sub] card_O by simp
have step_cl: "\<forall>y\<in>X - Orb. f y \<in> X - Orb"
proof
  fix y
  assume yX: "y \<in> X - Orb"
  then have yX': "y \<in> X" and yO: "y \<notin> Orb" by auto
  show "f y \<in> X - Orb"
  proof
    show "f y \<in> X" using cl yX' by auto
    show "f y \<notin> Orb"
    proof
      assume fyO: "f y \<in> Orb"
      then obtain i where hy: "f y = (f ^^ i) x0" unfolding Orb_def by auto
      have hp: "Suc (p - 1) = p" using p1 by simp
      have s1: "(f ^^ p) y = f ((f ^^ (p - 1)) y)"
      proof -
        have "(f ^^ Suc (p - 1)) y = f ((f ^^ (p - 1)) y)" by (rule iter_Suc)
        then show ?thesis using hp by simp
      qed
      have s2: "f ((f ^^ (p - 1)) y) = (f ^^ (p - 1)) (f y)" by (rule funpow_swap1)
      have pyy: "(f ^^ p) y = y" using per yX' by simp
      have "y = (f ^^ (p - 1)) (f y)" by (metis pyy s1 s2)
      also have "\<dots> = (f ^^ (p - 1)) ((f ^^ i) x0)" using hy by simp
      also have "\<dots> = (f ^^ ((p - 1) + i)) x0" by (rule iter_add[symmetric])
      finally have "y \<in> Orb" using Oeq by simp
      with yO show False by simp
    qed
  qed
qed
have eqN: "{y\<in>X - Orb. f y \<noteq> y} = {x\<in>X. f x \<noteq> x} - Orb" by auto
have cdiff: "card ({x\<in>X. f x \<noteq> x} - Orb) = card {x\<in>X. f x \<noteq> x} - p"
  using card_Diff_subset[OF fin_O O_sub] card_O by simp
have fin_X': "finite (X - Orb)" using fin by simp
have per': "\<forall>y\<in>X - Orb. (f ^^ p) y = y" using per by auto
have le': "card {y\<in>X - Orb. f y \<noteq> y} \<le> n"
  using eqN cdiff hle p1 by simp
have IHd: "p dvd card {y\<in>X - Orb. f y \<noteq> y}"
  by (rule IH[OF fin_X' step_cl per' le'])
have dvdA: "p dvd card {x\<in>X. f x \<noteq> x} - p" using IHd eqN cdiff by simp
have split: "card {x\<in>X. f x \<noteq> x} = (card {x\<in>X. f x \<noteq> x} - p) + p"
  using card_le by simp
show ?thesis
  by (subst split) (rule dvd_add[OF dvdA dvd_refl])
qed

lemma orbit_step:
  fixes f :: "'b \<Rightarrow> 'b" and p n :: nat and X :: "'b set"
  assumes pr: "prime p"
    and IH: "\<And>X. finite X \<Longrightarrow> (\<forall>x\<in>X. f x \<in> X) \<Longrightarrow> (\<forall>x\<in>X. (f ^^ p) x = x) \<Longrightarrow>
      card {x\<in>X. f x \<noteq> x} \<le> n \<Longrightarrow> p dvd card {x\<in>X. f x \<noteq> x}"
    and fin: "finite X" and cl: "\<forall>x\<in>X. f x \<in> X" and per: "\<forall>x\<in>X. (f ^^ p) x = x"
    and hle: "card {x\<in>X. f x \<noteq> x} \<le> Suc n"
  shows "p dvd card {x\<in>X. f x \<noteq> x}"
proof (cases "\<exists>x0\<in>X. f x0 \<noteq> x0")
  case True
  then obtain x0 where x0X: "x0 \<in> X" and x0N: "f x0 \<noteq> x0" by auto
  show ?thesis using orbit_main[OF pr IH fin cl per hle x0X x0N] .
next
  case False
  then have "{x\<in>X. f x \<noteq> x} = {}" by auto
  then show ?thesis by (simp only: Finite_Set.card.empty dvd_0_right)
qed

lemma orbit_base:
  fixes f :: "'b \<Rightarrow> 'b" and p :: nat and X :: "'b set"
  shows "finite X \<Longrightarrow> (\<forall>x\<in>X. f x \<in> X) \<Longrightarrow> (\<forall>x\<in>X. (f ^^ p) x = x) \<Longrightarrow>
    card {x\<in>X. f x \<noteq> x} \<le> 0 \<Longrightarrow> p dvd card {x\<in>X. f x \<noteq> x}"
proof -
  assume fin: "finite X" and cl: "\<forall>x\<in>X. f x \<in> X" and per: "\<forall>x\<in>X. (f ^^ p) x = x"
    and hle: "card {x\<in>X. f x \<noteq> x} \<le> 0"
  have "card {x\<in>X. f x \<noteq> x} = 0" using hle by simp
  then show "p dvd card {x\<in>X. f x \<noteq> x}" by simp
qed

lemma orbit_dvd:
  fixes f :: "'b \<Rightarrow> 'b" and p n :: nat
  assumes pr: "prime p"
  shows "\<And>X. finite X \<Longrightarrow> (\<forall>x\<in>X. f x \<in> X) \<Longrightarrow> (\<forall>x\<in>X. (f ^^ p) x = x) \<Longrightarrow>
    card {x\<in>X. f x \<noteq> x} \<le> n \<Longrightarrow> p dvd card {x\<in>X. f x \<noteq> x}"
proof (induction n)
  case 0
  show ?case by (metis orbit_base)
next
  case (Suc n)
  show ?case by (metis orbit_step[OF pr Suc.IH])
qed


section \<open>Consequences of the basic axioms\<close>

context grp
begin

lemma rt_inv: "x \<in> G \<Longrightarrow> x \<cdot> ginv x = e"
proof -
  assume hx: "x \<in> G"
  obtain a where ha_def: "a = ginv x" by blast
  have ha: "a \<in> G" by (simp add: ha_def inv_closed[OF hx])
  obtain b where hb_def: "b = ginv a" by blast
  have hb: "b \<in> G" by (simp add: hb_def inv_closed[OF ha])
  have h1: "b \<cdot> a = e" by (simp add: hb_def left_inv[OF ha])
  have h2: "a \<cdot> x = e" by (simp add: ha_def left_inv[OF hx])
  have hxa: "x \<cdot> a \<in> G" using closed[OF hx ha] .
  have "x \<cdot> a = (b \<cdot> a) \<cdot> (x \<cdot> a)" using h1 left_unit[OF hxa] by simp
  also have "\<dots> = b \<cdot> (a \<cdot> (x \<cdot> a))" using assoc[OF hb ha hxa] .
  also have "\<dots> = b \<cdot> ((a \<cdot> x) \<cdot> a)" using assoc[OF ha hx ha] by simp
  also have "\<dots> = b \<cdot> (e \<cdot> a)" using h2 by simp
  also have "\<dots> = b \<cdot> a" using left_unit[OF ha] by simp
  also have "\<dots> = e" using h1 .
  finally show "x \<cdot> ginv x = e" using ha_def by simp
qed

lemma rt_unit: "x \<in> G \<Longrightarrow> x \<cdot> e = x"
proof -
  assume hx: "x \<in> G"
  have ha: "ginv x \<in> G" by (rule inv_closed[OF hx])
  have h2: "ginv x \<cdot> x = e" by (rule left_inv[OF hx])
  have "x \<cdot> e = x \<cdot> (ginv x \<cdot> x)" using h2 by simp
  also have "\<dots> = (x \<cdot> ginv x) \<cdot> x" using assoc[OF hx ha hx] by simp
  also have "\<dots> = e \<cdot> x" using rt_inv[OF hx] by simp
  also have "\<dots> = x" using left_unit[OF hx] .
  finally show ?thesis .
qed

lemma lcancel: "a \<in> G \<Longrightarrow> x \<in> G \<Longrightarrow> y \<in> G \<Longrightarrow> a \<cdot> x = a \<cdot> y \<Longrightarrow> x = y"
proof -
  assume ha: "a \<in> G" and hx: "x \<in> G" and hy: "y \<in> G" and hxy: "a \<cdot> x = a \<cdot> y"
  have hb: "ginv a \<in> G" by (rule inv_closed[OF ha])
  have h1: "ginv a \<cdot> a = e" by (rule left_inv[OF ha])
  have "x = e \<cdot> x" using left_unit[OF hx] by simp
  also have "\<dots> = (ginv a \<cdot> a) \<cdot> x" using h1 by simp
  also have "\<dots> = ginv a \<cdot> (a \<cdot> x)" using assoc[OF hb ha hx] .
  also have "\<dots> = ginv a \<cdot> (a \<cdot> y)" using hxy by simp
  also have "\<dots> = (ginv a \<cdot> a) \<cdot> y" using assoc[OF hb ha hy, symmetric] .
  also have "\<dots> = y" using h1 left_unit[OF hy] by simp
  finally show ?thesis .
qed

lemma rot_prod: "y \<in> G \<Longrightarrow> P \<in> G \<Longrightarrow> y \<cdot> P = e \<Longrightarrow> P \<cdot> y = e"
proof -
  assume hy: "y \<in> G" and hP: "P \<in> G" and h: "y \<cdot> P = e"
  have "P = ginv y"
    by (rule lcancel[OF hy hP inv_closed[OF hy]]) (simp add: h rt_inv[OF hy])
  then show ?thesis by (simp add: left_inv[OF hy])
qed

lemma fold_closed: "set xs \<subseteq> G \<Longrightarrow> foldr mult xs e \<in> G"
proof (induction xs)
  case Nil
  then show ?case by (simp add: unit_closed)
next
  case (Cons x xs)
  have hx: "x \<in> G" using Cons.prems by auto
  have hs: "set xs \<subseteq> G" using Cons.prems by auto
  have hP: "foldr mult xs e \<in> G" using Cons.IH[OF hs] .
  show ?case using closed[OF hx hP] by simp
qed

lemma fold_Q: "set xs \<subseteq> G \<Longrightarrow> y \<in> G \<Longrightarrow> foldr mult xs y = foldr mult xs e \<cdot> y"
proof (induction xs)
  case Nil
  then show ?case by (simp add: left_unit)
next
  case (Cons x xs)
  have hx: "x \<in> G" using Cons.prems(1) by auto
  have hs: "set xs \<subseteq> G" using Cons.prems(1) by auto
  have hy: "y \<in> G" using Cons.prems(2) .
  have hP: "foldr mult xs e \<in> G" using fold_closed[OF hs] .
  have "foldr mult (x # xs) y = x \<cdot> (foldr mult xs e \<cdot> y)" using Cons.IH[OF hs hy] by simp
  also have "\<dots> = (x \<cdot> foldr mult xs e) \<cdot> y" using assoc[OF hx hP hy, symmetric] .
  also have "\<dots> = foldr mult (x # xs) e \<cdot> y" by simp
  finally show ?case .
qed

lemma fold_snoc: "set xs \<subseteq> G \<Longrightarrow> z \<in> G \<Longrightarrow> foldr mult (xs @ [z]) e = foldr mult xs e \<cdot> z"
proof -
  assume hs: "set xs \<subseteq> G" and hz: "z \<in> G"
  have "foldr mult (xs @ [z]) e = foldr mult xs (foldr mult [z] e)" by (rule foldr_append)
  also have "\<dots> = foldr mult xs (z \<cdot> e)" by simp
  also have "\<dots> = foldr mult xs z" using rt_unit[OF hz] by simp
  also have "\<dots> = foldr mult xs e \<cdot> z" using fold_Q[OF hs hz] .
  finally show ?thesis .
qed

lemma fold_rep: "foldr mult (replicate n x) e = pow x n"
  by (induction n) simp_all

lemma pow_e: "pow e n = e"
  by (induction n) (simp_all add: left_unit[OF unit_closed])

lemma fold_rep_e: "foldr mult (replicate n e) e = e"
  by (simp add: fold_rep pow_e)

lemma iter_pow: "((\<lambda>z. y \<cdot> z) ^^ n) e = pow y n"
  by (induction n) (simp_all add: iter_Suc)

abbreviation Lq :: "nat \<Rightarrow> 'a list set" where
  "Lq q \<equiv> {ys. set ys \<subseteq> G \<and> length ys = q}"

abbreviation Sp :: "nat \<Rightarrow> 'a list set" where
  "Sp n \<equiv> {xs. set xs \<subseteq> G \<and> length xs = n \<and> foldr mult xs e = e}"

abbreviation ext :: "'a list \<Rightarrow> 'a list" where
  "ext ys \<equiv> ys @ [ginv (foldr mult ys e)]"

lemma card_S:
  assumes fin: "finite G"
  shows "card (Sp (Suc q)) = card G ^ q"
proof -
  have finL: "finite (Lq q)" using finite_lists_length_eq[OF fin] .
  have cardL: "card (Lq q) = card G ^ q" using card_lists_length_eq[OF fin] .
  have inj: "inj_on ext (Lq q)"
  proof (rule inj_onI)
    fix ys zs
    assume hy: "ys \<in> Lq q" and hz: "zs \<in> Lq q" and eq: "ext ys = ext zs"
    have "butlast (ext ys) = butlast (ext zs)" using eq by simp
    then show "ys = zs" by simp
  qed
  have eq: "Sp (Suc q) = ext ` Lq q"
  proof
    show "Sp (Suc q) \<subseteq> ext ` Lq q"
    proof
      fix xs
      assume hxs: "xs \<in> Sp (Suc q)"
      then have hG: "set xs \<subseteq> G" and hl: "length xs = Suc q" and hf: "foldr mult xs e = e" by auto
      have ne: "xs \<noteq> []" using hl by auto
      obtain ys z where xs_eq: "xs = ys @ [z]"
        using ne by (cases xs rule: rev_cases) auto
      have hys: "set ys \<subseteq> G" and hz: "z \<in> G" using hG xs_eq by auto
      have hlen: "length ys = q" using hl xs_eq by simp
      have hP: "foldr mult ys e \<in> G" using fold_closed[OF hys] .
      have hfz: "foldr mult ys e \<cdot> z = e" using hf xs_eq fold_snoc[OF hys hz] by simp
      have zeq: "z = ginv (foldr mult ys e)"
        by (rule lcancel[OF hP hz inv_closed[OF hP]]) (simp add: hfz rt_inv[OF hP])
      have hy: "ys \<in> Lq q" using hys hlen by simp
      have "ext ys = xs" using xs_eq zeq by simp
      then show "xs \<in> ext ` Lq q" using hy by blast
    qed
    show "ext ` Lq q \<subseteq> Sp (Suc q)"
    proof
      fix xs
      assume "xs \<in> ext ` Lq q"
      then obtain ys where hy: "ys \<in> Lq q" and xs_eq: "xs = ext ys" by blast
      then have hys: "set ys \<subseteq> G" and hl: "length ys = q" by auto
      have hP: "foldr mult ys e \<in> G" using fold_closed[OF hys] .
      have hz: "ginv (foldr mult ys e) \<in> G" by (rule inv_closed[OF hP])
      have f1: "foldr mult (ext ys) e = e"
        using fold_snoc[OF hys hz] rt_inv[OF hP] by simp
      show "xs \<in> Sp (Suc q)" using hys hz hl f1 xs_eq by auto
    qed
  qed
  have "card (Sp (Suc q)) = card (ext ` Lq q)" using eq by simp
  also have "\<dots> = card (Lq q)" using card_image[OF inj] .
  also have "\<dots> = card G ^ q" using cardL .
  finally show ?thesis .
qed

end

lemma rot_iter: "(rotate1 ^^ k) xs = rotate k xs"
  by (induction k) (simp_all add: iter_Suc)

section \<open>The main theorem\<close>

theorem (in grp) cauchy:
  assumes "finite G" and "prime p" and "p dvd card G"
  shows "\<exists>x\<in>G. pow x p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow x k \<noteq> e)"
proof -
  have finG: "finite G" using assms(1) by simp
  have pr: "prime p" using assms(2) by simp
  have dvdG: "p dvd card G" using assms(3) by simp
  have p2: "2 \<le> p" using pr unfolding prime_def by auto
  obtain q where hq: "p = Suc q" using p2 by (cases p) auto
  obtain r where hr: "q = Suc r" using hq p2 by (cases q) auto
  have finS: "finite (Sp p)"
    by (rule finite_subset[OF _ finite_lists_length_eq[OF finG]]) auto
  have cardS: "p dvd card (Sp p)"
  proof -
    have c1: "card (Sp p) = card G ^ q" using card_S[OF finG, of q] hq by simp
    have c2: "card G ^ q = card G * card G ^ r" using hr by (simp add: power_Suc)
    show ?thesis using c1 c2 dvd_mult[OF dvdG] by simp
  qed
  have rot_mem: "\<forall>xs\<in>Sp p. rotate1 xs \<in> Sp p"
  proof
    fix xs
    assume hxs: "xs \<in> Sp p"
    then have hG: "set xs \<subseteq> G" and hl: "length xs = p" and hf: "foldr mult xs e = e" by auto
    obtain y ys where xs_eq: "xs = y # ys" using hl p2 by (cases xs) auto
    have hy: "y \<in> G" and hys: "set ys \<subseteq> G" using hG xs_eq by auto
    have hlen: "length ys = q" using hl xs_eq hq by simp
    have hP: "foldr mult ys e \<in> G" using fold_closed[OF hys] .
    have hyP: "y \<cdot> foldr mult ys e = e" using hf xs_eq by simp
    have hfy: "foldr mult (ys @ [y]) e = e"
      using fold_snoc[OF hys hy] rot_prod[OF hy hP hyP] by simp
    show "rotate1 xs \<in> Sp p" using hys hy hlen hq hfy xs_eq by auto
  qed
  have rot_per: "\<forall>xs\<in>Sp p. (rotate1 ^^ p) xs = xs"
  proof
    fix xs
    assume hxs: "xs \<in> Sp p"
    then have hl: "length xs = p" by simp
    have "rotate p xs = rotate (p mod length xs) xs" by (rule rotate_conv_mod)
    then have "rotate p xs = xs" using hl by simp
    then show "(rotate1 ^^ p) xs = xs" using rot_iter[of p xs] by simp
  qed
  have orbN: "p dvd card {xs \<in> Sp p. rotate1 xs \<noteq> xs}"
    using orbit_dvd[where f=rotate1 and p=p and n="card {xs \<in> Sp p. rotate1 xs \<noteq> xs}",
        OF pr finS rot_mem rot_per le_refl] .
  have fA: "finite {xs \<in> Sp p. rotate1 xs \<noteq> xs}" by (rule finite_subset[OF _ finS]) auto
  have fB: "finite {xs \<in> Sp p. rotate1 xs = xs}" by (rule finite_subset[OF _ finS]) auto
  have disj: "{xs \<in> Sp p. rotate1 xs \<noteq> xs} \<inter> {xs \<in> Sp p. rotate1 xs = xs} = {}" by auto
  have unionS: "Sp p = {xs \<in> Sp p. rotate1 xs \<noteq> xs} \<union> {xs \<in> Sp p. rotate1 xs = xs}" by auto
  have splitS: "card (Sp p) = card {xs \<in> Sp p. rotate1 xs \<noteq> xs} + card {xs \<in> Sp p. rotate1 xs = xs}"
    using card_Un_disjoint[OF fA fB disj] unionS by simp
  have pB: "p dvd card {xs \<in> Sp p. rotate1 xs = xs}"
  proof -
    have "p dvd card {xs \<in> Sp p. rotate1 xs \<noteq> xs} + card {xs \<in> Sp p. rotate1 xs = xs}"
      using cardS splitS by simp
    then show ?thesis using orbN dvd_add_right_iff by blast
  qed
  have repl_mem: "replicate p e \<in> {xs \<in> Sp p. rotate1 xs = xs}"
    using unit_closed by (simp add: fold_rep_e hq)
  have ex: "\<exists>xs\<in>{xs \<in> Sp p. rotate1 xs = xs}. xs \<noteq> replicate p e"
  proof (rule ccontr)
    assume H: "\<not> (\<exists>xs\<in>{xs \<in> Sp p. rotate1 xs = xs}. xs \<noteq> replicate p e)"
    have sub: "{xs \<in> Sp p. rotate1 xs = xs} \<subseteq> {replicate p e}" using H by auto
    have c1: "card {xs \<in> Sp p. rotate1 xs = xs} \<le> card {replicate p e}"
      by (rule card_mono) (use sub in auto)
    have c2: "card {xs \<in> Sp p. rotate1 xs = xs} \<noteq> 0" using fB repl_mem by auto
    have c3: "p \<le> card {xs \<in> Sp p. rotate1 xs = xs}" using pB c2 dvd_imp_le by (meson neq0_conv)
    show False using c1 c3 p2 by simp
  qed
  obtain xs where xsB: "xs \<in> Sp p" and xsF: "rotate1 xs = xs" and xsne: "xs \<noteq> replicate p e"
    using ex by auto
  have hG: "set xs \<subseteq> G" and hl: "length xs = p" and hf: "foldr mult xs e = e" using xsB by auto
  obtain y ys where xs_eq: "xs = y # ys" using hl p2 by (cases xs) auto
  have yG: "y \<in> G" using hG xs_eq by auto
  have ys_el: "\<forall>z\<in>set ys. z = y"
  proof -
    have "ys @ [y] = y # ys" using xsF xs_eq by simp
    then show ?thesis using rot_fix_elems by blast
  qed
  have xs_repl: "xs = replicate p y"
  proof -
    have "\<forall>z\<in>set xs. z = y" using xs_eq ys_el by auto
    then have "xs = replicate (length xs) y" by (rule all_eq_replicate)
    then show ?thesis using hl by simp
  qed
  have yne: "y \<noteq> e" using xsne xs_repl by auto
  have powy: "pow y p = e" using hf xs_repl fold_rep[of y p] by simp
  have key: "\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow y k \<noteq> e"
  proof (intro allI impI)
    fix k
    assume k0: "0 < k" and kp: "k < p" and hk: "pow y k = e"
    have fk: "((\<lambda>z. y \<cdot> z) ^^ k) e = e" using iter_pow[of y k] hk by simp
    have fp: "((\<lambda>z. y \<cdot> z) ^^ p) e = e" using iter_pow[of y p] powy by simp
    have "(\<lambda>z. y \<cdot> z) e = e" using prime_fix[OF pr k0 kp fk fp] .
    then have "y = e" using rt_unit[OF yG] by simp
    with yne show False by simp
  qed
  show ?thesis using yG powy key by blast
qed

end
