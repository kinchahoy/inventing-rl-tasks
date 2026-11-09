theory Quantum_Basics
  imports Complex_Main
begin

text \<open>Finite-dimensional quantum mechanics from scratch. A vector of dimension \<open>n\<close> is a function
  \<open>nat \<Rightarrow> complex\<close>; only its entries below \<open>n\<close> are ever read. Nothing beyond \<open>Complex_Main\<close>
  (complex numbers, \<open>cis\<close>, \<open>sqrt\<close>, finite sums) is assumed.\<close>

type_synonym vec = "nat \<Rightarrow> complex"

text \<open>Inner product \<open>\<langle>u|v\<rangle>\<close>, states (unit vectors) and computational basis states.\<close>

definition inner :: "nat \<Rightarrow> vec \<Rightarrow> vec \<Rightarrow> complex" where
  "inner n u v = (\<Sum>i<n. cnj (u i) * v i)"

definition is_state :: "nat \<Rightarrow> vec \<Rightarrow> bool" where
  "is_state n v \<longleftrightarrow> inner n v v = 1"

definition ket :: "nat \<Rightarrow> vec" where
  "ket k = (\<lambda>i. if i = k then 1 else 0)"

text \<open>Composite systems: \<open>u \<otimes> v\<close> with \<open>v\<close> of dimension \<open>n\<close>, indexed as \<open>i = n \<cdot> a + b\<close>.\<close>

definition tensor :: "nat \<Rightarrow> vec \<Rightarrow> vec \<Rightarrow> vec" where
  "tensor n u v = (\<lambda>i. u (i div n) * v (i mod n))"

text \<open>Evolution preserves inner products; measurement follows the Born rule.\<close>

definition preserves_inner :: "nat \<Rightarrow> (vec \<Rightarrow> vec) \<Rightarrow> bool" where
  "preserves_inner n U \<longleftrightarrow> (\<forall>u v. inner n (U u) (U v) = inner n u v)"

definition prob :: "vec \<Rightarrow> nat \<Rightarrow> real" where
  "prob v j = (cmod (v j))\<^sup>2"

text \<open>Quantum Fourier transform on \<open>\<int>\<^sub>N\<close>: \<open>|k\<rangle> \<mapsto> N\<^sup>-\<^sup>1\<^sup>/\<^sup>2 \<Sum>\<^sub>j e\<^sup>2\<^sup>\<pi>\<^sup>i\<^sup>j\<^sup>k\<^sup>/\<^sup>N |j\<rangle>\<close>.\<close>

definition qft :: "nat \<Rightarrow> vec \<Rightarrow> vec" where
  "qft N v = (\<lambda>j. (\<Sum>k<N. cis (2 * pi * real j * real k / real N) * v k)
    / complex_of_real (sqrt (real N)))"

text \<open>The uniform superposition over \<open>{x\<^sub>0, x\<^sub>0 + r, x\<^sub>0 + 2r, \<dots>} \<subseteq> \<int>\<^sub>N\<close>: what Shor's algorithm
  holds after measuring the register \<open>a\<^sup>x mod n\<close>. It is normalised by the number of such indices,
  which is \<open>N div r\<close> when \<open>r\<close> divides \<open>N\<close>.\<close>

definition periodic_state :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> vec" where
  "periodic_state N r x0 =
    (\<lambda>k. if k < N \<and> k mod r = x0
      then complex_of_real (1 / sqrt (real (card {i. i < N \<and> i mod r = x0}))) else 0)"

text \<open>Classical side: \<open>r\<close> is the multiplicative order of \<open>a\<close> modulo \<open>n\<close>.\<close>

definition is_order :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "is_order n a r \<longleftrightarrow> 0 < r \<and> a ^ r mod n = 1 \<and> (\<forall>k. 0 < k \<longrightarrow> k < r \<longrightarrow> a ^ k mod n \<noteq> 1)"

text \<open>Classical post-processing: the least denominator \<open>b\<close> of a fraction \<open>a / b\<close> within \<open>1 / (2N)\<close> of the
  measured \<open>j / N\<close>. The continued-fraction expansion of \<open>j / N\<close> computes it efficiently.\<close>

definition recover :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "recover N j = (LEAST b. 0 < b \<and> (\<exists>a::int. 2 * \<bar>int j * int b - a * int N\<bar> \<le> int b))"

end
