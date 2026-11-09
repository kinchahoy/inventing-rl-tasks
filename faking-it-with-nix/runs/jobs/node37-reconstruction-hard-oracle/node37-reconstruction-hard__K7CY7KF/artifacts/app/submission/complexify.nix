# Oracle side of the complexifiers (author/complexify.md); the original recipe is replica.nix.
{ ... }: {
  # CX-cmdline-decoy, CX-sysctl-decoy, CX-script-backup: nothing to reproduce; the leftovers on the reference are inert.

  # CX-timer-reset: the reference replaces sysstat's default collection interval with once a minute.
  services.sysstat = {
    enable = true;
    collect-frequency = "*-*-* *:*:00";
  };

  # CX-etc-environment: pam_env applies these to every session, including non-interactive ssh and `su -l`;
  # environment.variables would only reach interactive shells.
  environment.sessionVariables = {
    ACCEL_VISIBLE_DEVICES = "0,1";
    OMP_NUM_THREADS = "8";
  };
}
