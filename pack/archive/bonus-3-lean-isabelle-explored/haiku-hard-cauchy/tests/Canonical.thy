theory Canonical
  imports Group_Axioms
begin

text \<open>Trusted: the canonical statement, parsed where the submission is not visible, so it
  cannot change its meaning by shadowing constants.\<close>

ML \<open>
  val canonical_statements = [
    ("cauchy", @{prop \<open>grp G mult e ginv \<Longrightarrow> finite G \<Longrightarrow> prime p \<Longrightarrow> p dvd card G \<Longrightarrow>
      \<exists>x\<in>G. gpow mult e x p = e \<and> (\<forall>k. 0 < k \<longrightarrow> k < p \<longrightarrow> gpow mult e x k \<noteq> e)\<close>})]

  fun check_theorem name thm =
    let
      val expected = Logic.varify_global (the (AList.lookup (op =) canonical_statements name))
    in
      if Thm.prop_of thm aconv expected then ()
      else error ("Statement of " ^ name ^ " differs from the canonical statement");
      if null (Thm_Deps.all_oracles [thm]) then ()
      else error (name ^ " depends on an oracle (e.g. sorry or skip_proofs)")
    end
\<close>

end
