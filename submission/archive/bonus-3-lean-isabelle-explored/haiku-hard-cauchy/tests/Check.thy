theory Check
  imports Canonical Cauchy
begin

ML \<open>
  val _ = check_theorem "cauchy" @{thm Cauchy.grp.cauchy}
\<close>

end
