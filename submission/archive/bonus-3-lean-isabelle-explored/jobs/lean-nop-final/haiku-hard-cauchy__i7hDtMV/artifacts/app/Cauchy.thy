theory Cauchy
  imports Group_Axioms
begin

theorem (in grp) cauchy:
  assumes "finite G" and "prime p" and "p dvd card G"
  shows "\<exists>x\<in>G. pow x p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> pow x k \<noteq> e)"
  sorry

end
