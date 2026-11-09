theory Canonical
  imports Quantum_Basics
begin

text \<open>Trusted: the canonical statements, parsed where only \<open>Quantum_Basics\<close> is visible,
  so a submission cannot change their meaning by shadowing constants.\<close>

ML \<open>
  val canonical_statements = [
    ("shor_factor", @{prop \<open>(1 < n) \<Longrightarrow> (is_order n a r) \<Longrightarrow> (even r) \<Longrightarrow> (a ^ (r div 2) mod n \<noteq> n - 1) \<Longrightarrow> (1 < gcd (a ^ (r div 2) - 1) n \<and> gcd (a ^ (r div 2) - 1) n < n)\<close>}),
    ("shor_peak", @{prop \<open>(0 < r) \<Longrightarrow> (r < N) \<Longrightarrow> (x0 < r) \<Longrightarrow> (j < N) \<Longrightarrow> (2 * \<bar>int j * int r - c * int N\<bar> \<le> int r) \<Longrightarrow> (is_state N (periodic_state N r x0) \<and>
    4 / (pi\<^sup>2 * real r) * (1 - real r / real N) ^ 3 \<le> prob (qft N (periodic_state N r x0)) j)\<close>}),
    ("shor_general_success", @{prop \<open>(0 < r) \<Longrightarrow> (r * r < N) \<Longrightarrow> (x0 < r) \<Longrightarrow> (4 / pi\<^sup>2 * (real (card {c. c < r \<and> coprime c r}) / real r) * (1 - real r / real N) ^ 3
    \<le> (\<Sum>j \<in> {j. j < N \<and> recover N j = r}. prob (qft N (periodic_state N r x0)) j))\<close>})]

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
