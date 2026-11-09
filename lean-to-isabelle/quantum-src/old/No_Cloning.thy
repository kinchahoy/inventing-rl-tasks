theory No_Cloning
  imports Quantum_Basics
begin

text \<open>No-cloning: no inner-product-preserving map \<open>U\<close> on two qubits sends \<open>\<psi> \<otimes> |0\<rangle>\<close> to
  \<open>\<psi> \<otimes> \<psi>\<close> for every one-qubit state \<open>\<psi>\<close>. Take \<open>\<psi> = |0\<rangle>\<close> and \<open>\<phi> = |+\<rangle>\<close>. Preservation of inner
  products on the pair \<open>(\<phi> \<otimes> |0\<rangle>, |0\<rangle> \<otimes> |0\<rangle>)\<close> gives \<open>r = r\<^sup>2\<close> for \<open>r = \<langle>\<phi>|0\<rangle> = 1/\<surd>2\<close>, so \<open>r = 1\<close>
  and \<open>\<surd>2 = 1\<close>, which is false.\<close>

definition plus_vec :: vec where
  "plus_vec = (\<lambda>i. complex_of_real (1 / sqrt 2))"

lemma sqrt2_square: "sqrt 2 * sqrt 2 = (2 :: real)"
  by simp

lemma inner2: "inner 2 u v = cnj (u 0) * v 0 + cnj (u 1) * v 1"
  by (simp add: inner_def lessThan_Suc numeral_eq_Suc)

lemma inner4: "inner 4 u v = cnj (u 0) * v 0 + cnj (u 1) * v 1 + cnj (u 2) * v 2 + cnj (u 3) * v 3"
  by (simp add: inner_def lessThan_Suc numeral_eq_Suc)

lemma inner_tensor2:
  "inner 4 (tensor 2 a b) (tensor 2 c d) = inner 2 a c * inner 2 b d"
  unfolding inner4 inner2 tensor_def
  by (simp add: algebra_simps complex_cnj_mult)

lemma ket0_state: "is_state 2 (ket 0)"
  by (simp add: is_state_def inner2 ket_def)

lemma plus_inner_ket0: "inner 2 plus_vec (ket 0) = complex_of_real (1 / sqrt 2)"
  by (simp add: inner2 plus_vec_def ket_def)

lemma plus_state: "is_state 2 plus_vec"
  by (simp add: is_state_def inner2 plus_vec_def of_real_mult [symmetric] sqrt2_square)

theorem no_cloning:
  shows "\<not> (\<exists>U. preserves_inner 4 U \<and> (\<forall>\<psi>. is_state 2 \<psi> \<longrightarrow> U (tensor 2 \<psi> (ket 0)) = tensor 2 \<psi> \<psi>))"
proof -
  show ?thesis
  proof
    assume "\<exists>U. preserves_inner 4 U \<and> (\<forall>\<psi>. is_state 2 \<psi> \<longrightarrow> U (tensor 2 \<psi> (ket 0)) = tensor 2 \<psi> \<psi>)"
    then obtain U where pres: "preserves_inner 4 U"
      and clone: "\<forall>\<psi>. is_state 2 \<psi> \<longrightarrow> U (tensor 2 \<psi> (ket 0)) = tensor 2 \<psi> \<psi>"
      by blast
    have u0: "U (tensor 2 (ket 0) (ket 0)) = tensor 2 (ket 0) (ket 0)"
      using clone ket0_state by blast
    have uP: "U (tensor 2 plus_vec (ket 0)) = tensor 2 plus_vec plus_vec"
      using clone plus_state by blast
    have ip: "inner 4 (U (tensor 2 plus_vec (ket 0))) (U (tensor 2 (ket 0) (ket 0)))
        = inner 4 (tensor 2 plus_vec (ket 0)) (tensor 2 (ket 0) (ket 0))"
      using pres unfolding preserves_inner_def by blast
    have key: "inner 2 plus_vec (ket 0) * inner 2 plus_vec (ket 0)
        = inner 2 plus_vec (ket 0) * inner 2 (ket 0) (ket 0)"
      using ip by (simp add: inner_tensor2 uP u0)
    define r where "r = 1 / sqrt 2"
    have r_ne: "r \<noteq> 0"
      by (simp add: r_def)
    have fixed: "r * r = r"
      using key by (simp add: plus_inner_ket0 ket0_state[unfolded is_state_def] r_def)
    have "r * (r - 1) = 0"
      using fixed by (simp add: algebra_simps)
    hence "r = 1"
      using r_ne by auto
    hence "sqrt 2 = 1"
      by (simp add: r_def)
    thus False
      using sqrt2_square by simp
  qed
qed

end
