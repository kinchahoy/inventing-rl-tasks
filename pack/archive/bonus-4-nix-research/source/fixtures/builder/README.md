# Builder fixture keys (not secrets)

Lab-only SSH keys for the per-trial builder sidecar. The builder exists only inside one trial's
compose project and dies with it, so these keys grant nothing outside that project. They are
published on purpose; never reuse them for anything else.
