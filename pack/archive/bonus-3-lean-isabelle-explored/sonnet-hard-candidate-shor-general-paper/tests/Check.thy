theory Check
  imports Canonical Shor_General
begin

ML \<open>
  val _ = check_theorem "shor_factor" @{thm Shor_General.shor_factor}
  val _ = check_theorem "shor_peak" @{thm Shor_General.shor_peak}
  val _ = check_theorem "shor_general_success" @{thm Shor_General.shor_general_success}
\<close>

end
