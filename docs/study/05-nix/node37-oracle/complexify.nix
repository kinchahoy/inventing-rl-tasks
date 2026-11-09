# Oracle side of the complexifiers (author/complexify.md); the original recipe is replica.nix.
{ ... }: {
  # CX-cmdline-decoy, CX-sysctl-decoy, CX-script-backup: nothing to reproduce; the leftovers on the reference are inert.

  # CX-timer-reset: the reference replaces sysstat's default collection interval with once a minute.
  # STUDY: CX-timer-reset: on Ubuntu a drop-in with `OnCalendar=` (empty = reset list) then a new value. On NixOS: one option.
  services.sysstat = {
    enable = true;
    collect-frequency = "*-*-* *:*:00";
  };

  # CX-etc-environment: pam_env applies these to every session, including non-interactive ssh and `su -l`;
  # environment.variables would only reach interactive shells.
  # STUDY: CX-etc-environment: sessionVariables go through pam_env (every session, incl. non-interactive ssh);
  # STUDY: environment.variables only reach interactive shells. A subtle NixOS distinction.
  environment.sessionVariables = {
    ACCEL_VISIBLE_DEVICES = "0,1";
    OMP_NUM_THREADS = "8";
  };
}
