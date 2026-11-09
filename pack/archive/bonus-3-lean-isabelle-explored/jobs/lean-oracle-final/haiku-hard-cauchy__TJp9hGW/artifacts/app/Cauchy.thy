theory Cauchy
  imports Group_Axioms
begin

text \<open>McKay's proof. Let \<open>X\<close> be the \<open>p\<close>-tuples over \<open>G\<close> whose product is \<open>e\<close>. Rotation acts
  on \<open>X\<close> with period \<open>p\<close>; every orbit has size \<open>1\<close> or \<open>p\<close>, so \<open>|X| \<equiv> #fixed points (mod p)\<close>.
  \<open>|X| = |G|\<^sup>p\<^sup>-\<^sup>1\<close> is divisible by \<open>p\<close>, and the fixed points are the constant tuples \<open>(x,\<dots>,x)\<close>
  with \<open>x\<^sup>p = e\<close>. Since \<open>e\<close> is one of them, there are at least \<open>p \<ge> 2\<close>, hence some \<open>x \<noteq> e\<close>.\<close>

section \<open>Arithmetic: a prime is coprime to every smaller positive number\<close>

lemma prime_bezout:
  assumes p: "prime p" and k: "0 < k" "k < p"
  shows "\<exists>s t. k * s = Suc (p * t)"
proof -
  have "gcd k p = 1 \<or> gcd k p = p"
    using p by (simp add: prime_def)
  moreover have "gcd k p \<noteq> p"
  proof
    assume "gcd k p = p"
    hence "p dvd k" using gcd_dvd1 [of k p] by simp
    with k show False by (auto dest: dvd_imp_le)
  qed
  ultimately have g: "gcd k p = 1" by blast
  from bezout_nat [of k p] k obtain s t where "k * s = p * t + gcd k p"
    by auto
  with g have "k * s = Suc (p * t)" by simp
  thus ?thesis by blast
qed

section \<open>Counting fixed points of a map of prime period\<close>

text \<open>If \<open>f\<^sup>k a = a\<close> for some \<open>0 < k < p\<close> and \<open>f\<^sup>p a = a\<close>, then \<open>f a = a\<close> (Bezout).\<close>
lemma funpow_fix_prime:
  assumes p: "prime p" and per: "(f ^^ p) a = a" and k: "0 < k" "k < p"
    and fix_k: "(f ^^ k) a = a"
  shows "f a = a"
proof -
  obtain s t where st: "k * s = Suc (p * t)"
    using prime_bezout [OF p k] by blast
  have iter: "(f ^^ (n * m)) a = a" if "(f ^^ n) a = a" for n m
    using that by (induct m) (simp_all add: funpow_add)
  have "f a = (f ^^ Suc (p * t)) a"
    using iter [OF per] by simp
  also have "\<dots> = (f ^^ (k * s)) a"
    by (simp only: st)
  also have "\<dots> = a"
    by (rule iter [OF fix_k])
  finally show ?thesis .
qed

text \<open>Remove one orbit of size \<open>p\<close> at a time: \<open>|A| \<equiv> |{a \<in> A. f a = a}| (mod p)\<close>.\<close>
lemma card_mod_fixpoints:
  assumes p: "prime p" and fin: "finite A"
    and maps: "\<forall>a\<in>A. f a \<in> A" and per: "\<forall>a\<in>A. (f ^^ p) a = a"
  shows "card A mod p = card {a \<in> A. f a = a} mod p"
  using fin maps per
proof (induct A rule: finite_psubset_induct)
  case (psubset A)
  have p1: "1 < p"
    using p by (simp add: prime_def)
  show ?case
  proof (cases "\<forall>a\<in>A. f a = a")
    case True
    hence "{a \<in> A. f a = a} = A" by blast
    thus ?thesis by simp
  next
    case False
    then obtain a where a: "a \<in> A" "f a \<noteq> a" by blast
    define orb where "orb = (\<lambda>k. (f ^^ k) a) ` {..<p}"
    have per_a: "(f ^^ p) a = a"
      using psubset.prems(2) a(1) by blast
    have iterA: "(f ^^ k) a \<in> A" for k
      using a(1) psubset.prems(1) by (induct k) auto
    have no_short: "(f ^^ k) a \<noteq> a" if "0 < k" "k < p" for k
      using funpow_fix_prime [OF p per_a that] a(2) by blast
    have in_orb: "(f ^^ n) a \<in> orb" for n
    proof -
      have "(f ^^ n) a = (f ^^ (n mod p)) a"
        by (simp add: funpow_mod_eq [OF per_a])
      moreover have "n mod p < p"
        using p1 by simp
      ultimately show ?thesis
        unfolding orb_def by (intro image_eqI [where x = "n mod p"]) auto
    qed
    text \<open>The orbit of \<open>a\<close> has exactly \<open>p\<close> elements.\<close>
    have collide: False if "i < j" "j < p" "(f ^^ i) a = (f ^^ j) a" for i j
    proof -
      define d where "d = p - j"
      have dj: "d + j = p"
        using that(2) by (simp add: d_def)
      have "(f ^^ (d + i)) a = (f ^^ d) ((f ^^ i) a)"
        by (simp add: funpow_add)
      also have "\<dots> = (f ^^ d) ((f ^^ j) a)"
        by (simp add: that(3))
      also have "\<dots> = (f ^^ (d + j)) a"
        by (simp add: funpow_add)
      also have "\<dots> = a"
        by (simp add: dj per_a)
      finally have returns: "(f ^^ (d + i)) a = a" .
      have pos: "0 < d + i" and short: "d + i < p"
        using that(1,2) by (auto simp: d_def)
      from returns no_short [OF pos short] show False
        by contradiction
    qed
    have inj: "inj_on (\<lambda>k. (f ^^ k) a) {..<p}"
    proof (rule inj_onI)
      fix i j assume i: "i \<in> {..<p}" and j: "j \<in> {..<p}" and eq: "(f ^^ i) a = (f ^^ j) a"
      show "i = j"
      proof (rule linorder_cases [of i j])
        assume "i < j"
        moreover from j have "j < p" by simp
        ultimately have False using eq by (rule collide)
        thus "i = j" by simp
      next
        assume "j < i"
        moreover from i have "i < p" by simp
        ultimately have False using eq [symmetric] by (rule collide)
        thus "i = j" by simp
      qed simp
    qed
    have card_orb: "card orb = p"
      unfolding orb_def using inj by (simp add: card_image)
    have orbA: "orb \<subseteq> A"
      using iterA by (auto simp: orb_def)
    text \<open>The rest \<open>A - orb\<close> is again closed under \<open>f\<close>, with the same fixed points.\<close>
    have rest_maps: "\<forall>b\<in>A - orb. f b \<in> A - orb"
    proof
      fix b assume b: "b \<in> A - orb"
      have "f b \<notin> orb"
      proof
        assume "f b \<in> orb"
        then obtain k where fb: "f b = (f ^^ k) a"
          by (auto simp: orb_def)
        have ps: "Suc (p - 1) = p"
          using p1 by simp
        have "b = (f ^^ p) b"
          using b psubset.prems(2) by auto
        also have "\<dots> = (f ^^ Suc (p - 1)) b"
          using ps by simp
        also have "\<dots> = (f ^^ (p - 1)) (f b)"
          by (simp add: funpow_swap1)
        also have "\<dots> = (f ^^ (p - 1 + k)) a"
          using fb by (simp add: funpow_add)
        finally have "b \<in> orb"
          using in_orb by simp
        with b show False by blast
      qed
      with b psubset.prems(1) show "f b \<in> A - orb" by blast
    qed
    have rest_fix: "{x \<in> A - orb. f x = x} = {x \<in> A. f x = x}"
    proof -
      have "f x \<noteq> x" if "x \<in> orb" for x
      proof
        assume fx: "f x = x"
        from that obtain k where k: "k < p" and x: "x = (f ^^ k) a"
          by (auto simp: orb_def)
        have stay: "(f ^^ n) x = x" for n
          using fx by (induct n) simp_all
        have pk: "p - k + k = p"
          using k by simp
        have "x = (f ^^ (p - k)) x"
          using stay [of "p - k"] by simp
        also have "\<dots> = (f ^^ (p - k + k)) a"
          using x by (simp add: funpow_add)
        also have "\<dots> = a"
          by (simp only: pk per_a)
        finally have xa: "x = a" .
        from xa fx a(2) show False by simp
      qed
      thus ?thesis by blast
    qed
    have sub: "A - orb \<subset> A"
      using orbA in_orb [of 0] a(1) by auto
    have per_rest: "\<forall>b\<in>A - orb. (f ^^ p) b = b"
      using psubset.prems(2) by blast
    have IH: "card (A - orb) mod p = card {x \<in> A - orb. f x = x} mod p"
      using psubset.hyps(2) [OF sub rest_maps per_rest] .
    have fin_orb: "finite orb"
      by (simp add: orb_def)
    have "card A = card (A - orb) + p"
      using card_Diff_subset [OF fin_orb orbA] card_mono [OF psubset.hyps(1) orbA] card_orb
      by simp
    hence "card A mod p = card (A - orb) mod p"
      by simp
    also have "\<dots> = card {x \<in> A. f x = x} mod p"
      using IH rest_fix by simp
    finally show ?thesis .
  qed
qed

section \<open>Consequences of the group axioms\<close>

context grp
begin

lemma idempotent_is_unit:
  assumes x: "x \<in> G" and idem: "x \<cdot> x = x"
  shows "x = e"
proof -
  have "x = (ginv x \<cdot> x) \<cdot> x"
    using x by (simp add: left_inv left_unit)
  also have "\<dots> = ginv x \<cdot> (x \<cdot> x)"
    using x by (simp add: assoc inv_closed)
  also have "\<dots> = e"
    using x idem by (simp add: left_inv)
  finally show ?thesis .
qed

lemma right_inv:
  assumes g: "g \<in> G"
  shows "g \<cdot> ginv g = e"
proof (rule idempotent_is_unit)
  show "g \<cdot> ginv g \<in> G"
    using g by (simp add: closed inv_closed)
  have "(g \<cdot> ginv g) \<cdot> (g \<cdot> ginv g) = g \<cdot> ((ginv g \<cdot> g) \<cdot> ginv g)"
    using g by (simp add: assoc closed inv_closed)
  also have "\<dots> = g \<cdot> ginv g"
    using g by (simp add: left_inv left_unit inv_closed)
  finally show "(g \<cdot> ginv g) \<cdot> (g \<cdot> ginv g) = g \<cdot> ginv g" .
qed

lemma right_unit:
  assumes g: "g \<in> G"
  shows "g \<cdot> e = g"
proof -
  have "g \<cdot> e = g \<cdot> (ginv g \<cdot> g)"
    using g by (simp add: left_inv)
  also have "\<dots> = (g \<cdot> ginv g) \<cdot> g"
    using g by (simp add: assoc inv_closed)
  also have "\<dots> = g"
    using g by (simp add: right_inv left_unit)
  finally show ?thesis .
qed

text \<open>A left factor of \<open>e\<close> is the inverse.\<close>
lemma inv_unique:
  assumes x: "x \<in> G" and y: "y \<in> G" and xy: "x \<cdot> y = e"
  shows "x = ginv y"
proof -
  have "x = x \<cdot> (y \<cdot> ginv y)"
    using x y by (simp add: right_inv right_unit)
  also have "\<dots> = (x \<cdot> y) \<cdot> ginv y"
    using x y by (simp add: assoc inv_closed)
  also have "\<dots> = ginv y"
    using xy y by (simp add: left_unit inv_closed)
  finally show ?thesis .
qed

lemma pow_closed: "x \<in> G \<Longrightarrow> pow x n \<in> G"
  by (induct n) (simp_all add: unit_closed closed)

lemma pow_add: "x \<in> G \<Longrightarrow> pow x (m + n) = pow x m \<cdot> pow x n"
  by (induct m) (simp_all add: left_unit assoc pow_closed)

lemma pow_unit: "pow e n = e"
  by (induct n) (simp_all add: left_unit unit_closed)

lemma pow_mult_unit: "x \<in> G \<Longrightarrow> pow x k = e \<Longrightarrow> pow x (k * s) = e"
  by (induct s) (simp_all add: pow_add left_unit unit_closed)

section \<open>Tuples with product \<open>e\<close>\<close>

definition lprod :: "'a list \<Rightarrow> 'a" where
  "lprod xs = foldr (\<cdot>) xs e"

lemma lprod_Nil [simp]: "lprod [] = e"
  and lprod_Cons [simp]: "lprod (x # xs) = x \<cdot> lprod xs"
  by (simp_all add: lprod_def)

lemma lprod_closed: "set xs \<subseteq> G \<Longrightarrow> lprod xs \<in> G"
  by (induct xs) (simp_all add: unit_closed closed)

lemma lprod_append: "set xs \<subseteq> G \<Longrightarrow> set ys \<subseteq> G \<Longrightarrow> lprod (xs @ ys) = lprod xs \<cdot> lprod ys"
  by (induct xs) (simp_all add: left_unit assoc lprod_closed)

lemma lprod_replicate: "lprod (replicate n x) = pow x n"
  by (induct n) simp_all

definition tuples :: "nat \<Rightarrow> 'a list set" where
  "tuples n = {xs. set xs \<subseteq> G \<and> length xs = n \<and> lprod xs = e}"

text \<open>Rotation keeps the product \<open>e\<close>: \<open>x \<cdot> P = e\<close> forces \<open>x = P\<inverse>\<close>, so \<open>P \<cdot> x = e\<close>.\<close>
lemma rotate1_tuple:
  assumes xs: "xs \<in> tuples n"
  shows "rotate1 xs \<in> tuples n"
proof (cases xs)
  case Nil
  thus ?thesis using xs by simp
next
  case (Cons x ys)
  have x: "x \<in> G" and ys: "set ys \<subseteq> G" and prod: "x \<cdot> lprod ys = e"
    using xs Cons by (auto simp: tuples_def)
  have "x = ginv (lprod ys)"
    by (rule inv_unique [OF x lprod_closed [OF ys] prod])
  hence "lprod (rotate1 xs) = e"
    using Cons x ys by (simp add: lprod_append right_unit right_inv lprod_closed)
  thus ?thesis
    using xs by (simp add: tuples_def)
qed

text \<open>Choosing the last \<open>n - 1\<close> entries freely determines the first: \<open>|tuples n| = |G|\<^sup>n\<^sup>-\<^sup>1\<close>.\<close>
lemma card_tuples:
  assumes fin: "finite G" and n: "0 < n"
  shows "card (tuples n) = card G ^ (n - 1)"
proof -
  let ?L = "{ys. set ys \<subseteq> G \<and> length ys = n - 1}"
  let ?f = "\<lambda>ys. ginv (lprod ys) # ys"
  have bij: "bij_betw ?f ?L (tuples n)"
  proof (rule bij_betw_byWitness [where f' = tl])
    show "\<forall>ys\<in>?L. tl (?f ys) = ys" by simp
    show "\<forall>xs\<in>tuples n. ?f (tl xs) = xs"
    proof
      fix xs assume xs: "xs \<in> tuples n"
      then obtain x ys where xs_eq: "xs = x # ys"
        using n by (cases xs) (auto simp: tuples_def)
      have x: "x \<in> G" and ys: "set ys \<subseteq> G" and prod: "x \<cdot> lprod ys = e"
        using xs xs_eq by (auto simp: tuples_def)
      have "x = ginv (lprod ys)"
        by (rule inv_unique [OF x lprod_closed [OF ys] prod])
      thus "?f (tl xs) = xs"
        using xs_eq by simp
    qed
    show "?f ` ?L \<subseteq> tuples n"
    proof
      fix xs assume "xs \<in> ?f ` ?L"
      then obtain ys where ys: "set ys \<subseteq> G" "length ys = n - 1" and xs_eq: "xs = ?f ys"
        by auto
      show "xs \<in> tuples n"
        using ys xs_eq n by (simp add: tuples_def inv_closed lprod_closed left_inv)
    qed
    show "tl ` tuples n \<subseteq> ?L"
    proof
      fix ys assume "ys \<in> tl ` tuples n"
      then obtain xs where xs: "xs \<in> tuples n" and ys_eq: "ys = tl xs"
        by auto
      have "set ys \<subseteq> G"
        using xs ys_eq by (cases xs) (auto simp: tuples_def)
      moreover have "length ys = n - 1"
        using xs ys_eq by (simp add: tuples_def)
      ultimately show "ys \<in> ?L" by simp
    qed
  qed
  have "card (tuples n) = card ?L"
    using bij_betw_same_card [OF bij] by simp
  also have "\<dots> = card G ^ (n - 1)"
    by (rule card_lists_length_eq [OF fin])
  finally show ?thesis .
qed

text \<open>A list fixed by rotation is constant.\<close>
lemma snoc_const: "ys @ [y] = y # ys \<Longrightarrow> replicate (length ys) y = ys"
proof (induct ys)
  case Nil
  thus ?case by simp
next
  case (Cons z zs)
  from Cons.prems have zy: "z = y" and rest: "zs @ [y] = y # zs"
    by simp_all
  from rest have "replicate (length zs) y = zs"
    by (rule Cons.hyps)
  with zy show ?case by simp
qed

lemma rotate1_fixed:
  assumes rot: "rotate1 xs = xs"
  shows "replicate (length xs) (hd xs) = xs"
proof (cases xs)
  case Nil
  thus ?thesis by simp
next
  case (Cons y ys)
  from Cons rot have "ys @ [y] = y # ys" by simp
  hence "replicate (length ys) y = ys" by (rule snoc_const)
  with Cons show ?thesis by simp
qed

lemma rotate1_replicate: "rotate1 (replicate n x) = replicate n x"
  by (cases n) (simp_all add: replicate_append_same)

text \<open>Fixed tuples are exactly the constant tuples \<open>(x, \<dots>, x)\<close> with \<open>x\<^sup>n = e\<close>.\<close>
lemma card_fixed_tuples:
  assumes n: "0 < n"
  shows "card {xs \<in> tuples n. rotate1 xs = xs} = card {x \<in> G. pow x n = e}"
proof -
  let ?F = "{xs \<in> tuples n. rotate1 xs = xs}"
  let ?S = "{x \<in> G. pow x n = e}"
  have bij: "bij_betw (replicate n) ?S ?F"
  proof (rule bij_betw_byWitness [where f' = hd])
    show "\<forall>x\<in>?S. hd (replicate n x) = x"
      using n by simp
    show "\<forall>xs\<in>?F. replicate n (hd xs) = xs"
    proof
      fix xs assume xs: "xs \<in> ?F"
      hence len: "length xs = n" and rot: "rotate1 xs = xs"
        by (auto simp: tuples_def)
      from len rotate1_fixed [OF rot] show "replicate n (hd xs) = xs"
        by simp
    qed
    show "replicate n ` ?S \<subseteq> ?F"
      using n by (auto simp: tuples_def lprod_replicate rotate1_replicate)
    show "hd ` ?F \<subseteq> ?S"
    proof
      fix x assume "x \<in> hd ` ?F"
      then obtain xs where xs: "xs \<in> ?F" and x: "x = hd xs"
        by auto
      have len: "length xs = n" and setG: "set xs \<subseteq> G" and prod: "lprod xs = e"
        and rot: "rotate1 xs = xs"
        using xs by (auto simp: tuples_def)
      have "xs \<noteq> []"
        using len n by auto
      hence "x \<in> G"
        using setG x by auto
      moreover have "pow x n = e"
        using len rotate1_fixed [OF rot] prod x by (simp add: lprod_replicate [symmetric])
      ultimately show "x \<in> ?S" by simp
    qed
  qed
  show ?thesis
    using bij_betw_same_card [OF bij] by simp
qed

end

section \<open>Cauchy's theorem\<close>

theorem (in grp) cauchy:
  assumes fin: "finite G" and p: "prime p" and dvd: "p dvd card G"
  shows "\<exists>x\<in>G. pow x p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow x k \<noteq> e)"
proof -
  have p1: "1 < p" and p0: "0 < p"
    using p by (simp_all add: prime_def)
  let ?X = "tuples p"
  let ?S = "{x \<in> G. pow x p = e}"
  have "?X \<subseteq> {xs. set xs \<subseteq> G \<and> length xs = p}"
    by (auto simp: tuples_def)
  hence finX: "finite ?X"
    using finite_lists_length_eq [OF fin] by (rule finite_subset)
  have per: "\<forall>xs\<in>?X. (rotate1 ^^ p) xs = xs"
    by (simp add: tuples_def rotate_def [symmetric])
  have maps: "\<forall>xs\<in>?X. rotate1 xs \<in> ?X"
    using rotate1_tuple by blast
  have "card ?X mod p = card {xs \<in> ?X. rotate1 xs = xs} mod p"
    by (rule card_mod_fixpoints [OF p finX maps per])
  moreover have "p dvd card ?X"
  proof -
    obtain q where q: "p = Suc (Suc q)"
      using p1 by (auto dest: less_imp_Suc_add)
    have "p dvd card G ^ (p - 1)"
      using q dvd by simp
    thus ?thesis
      by (simp add: card_tuples [OF fin p0])
  qed
  ultimately have dS: "p dvd card ?S"
    by (simp add: card_fixed_tuples [OF p0] dvd_eq_mod_eq_0)
  have finS: "finite ?S"
    using fin by (rule rev_finite_subset) auto
  have "e \<in> ?S"
    by (simp add: unit_closed pow_unit)
  with finS have "0 < card ?S"
    by (auto simp: card_gt_0_iff)
  hence S_big: "p \<le> card ?S"
    by (rule dvd_imp_le [OF dS])
  have "\<exists>x\<in>?S. x \<noteq> e"
  proof (rule ccontr)
    assume "\<not> (\<exists>x\<in>?S. x \<noteq> e)"
    hence "?S \<subseteq> {e}" by blast
    hence "card ?S \<le> 1"
      using card_mono [of "{e}" ?S] by simp
    with S_big p1 show False by simp
  qed
  then obtain x where x: "x \<in> G" "pow x p = e" "x \<noteq> e"
    by blast
  text \<open>\<open>x\<close> has order exactly \<open>p\<close>: a shorter period \<open>k\<close> would give \<open>x = x\<^sup>k\<^sup>s = e\<close> by Bezout.\<close>
  have order: "pow x k \<noteq> e" if k: "0 < k" "k < p" for k
  proof
    assume xk: "pow x k = e"
    obtain s t where st: "k * s = Suc (p * t)"
      using prime_bezout [OF p k] by blast
    have "x = x \<cdot> pow x (p * t)"
      using x by (simp add: pow_mult_unit right_unit)
    also have "\<dots> = pow x (Suc (p * t))"
      by simp
    also have "\<dots> = pow x (k * s)"
      by (simp only: st)
    also have "\<dots> = e"
      using x(1) xk by (rule pow_mult_unit)
    finally have "x = e" .
    with x(3) show False ..
  qed
  show ?thesis
    using x order by blast
qed

end
