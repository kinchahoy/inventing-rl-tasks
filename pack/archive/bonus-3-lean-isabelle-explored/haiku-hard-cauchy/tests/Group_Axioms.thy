theory Group_Axioms
  imports Main
begin

text \<open>A group given only by the basic axioms: closure, associativity, a left identity and left
  inverses. Nothing else about groups is available; right-sided laws must be derived.\<close>

locale grp =
  fixes G :: "'a set"
    and mult :: "'a \<Rightarrow> 'a \<Rightarrow> 'a"  (infixl \<open>\<cdot>\<close> 70)
    and e :: 'a
    and ginv :: "'a \<Rightarrow> 'a"
  assumes closed: "\<lbrakk>x \<in> G; y \<in> G\<rbrakk> \<Longrightarrow> x \<cdot> y \<in> G"
    and assoc: "\<lbrakk>x \<in> G; y \<in> G; z \<in> G\<rbrakk> \<Longrightarrow> (x \<cdot> y) \<cdot> z = x \<cdot> (y \<cdot> z)"
    and unit_closed: "e \<in> G"
    and left_unit: "x \<in> G \<Longrightarrow> e \<cdot> x = x"
    and inv_closed: "x \<in> G \<Longrightarrow> ginv x \<in> G"
    and left_inv: "x \<in> G \<Longrightarrow> ginv x \<cdot> x = e"

text \<open>Primality from first principles (\<open>Main\<close> has no notion of primes).\<close>

definition prime :: "nat \<Rightarrow> bool" where
  "prime p \<longleftrightarrow> 1 < p \<and> (\<forall>d. d dvd p \<longrightarrow> d = 1 \<or> d = p)"

text \<open>Natural-number powers \<open>x\<^sup>n = x \<cdot> (x \<cdot> (\<dots> \<cdot> e))\<close>, and their name inside the locale.\<close>

primrec gpow :: "('a \<Rightarrow> 'a \<Rightarrow> 'a) \<Rightarrow> 'a \<Rightarrow> 'a \<Rightarrow> nat \<Rightarrow> 'a" where
  "gpow m u x 0 = u"
| "gpow m u x (Suc n) = m x (gpow m u x n)"

abbreviation (in grp) pow :: "'a \<Rightarrow> nat \<Rightarrow> 'a" where
  "pow x n \<equiv> gpow mult e x n"

end
