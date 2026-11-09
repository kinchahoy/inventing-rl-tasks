let
  p = import /opt/nixpkgs { system = "x86_64-linux"; };
  subdirClosure = p.closureInfo { rootPaths = [ "${p.coreutils}/bin" ]; };
in p.runCommand "replica-cache-smoke-${builtins.getEnv "SMOKE_ID"}" {} ''
  test -s ${subdirClosure}/store-paths
  test "$(id -u)" -ne 0
  test ! -e /builder-outside-marker
  printf 'build-uid=%s\n' "$(id -u)" > "$out"
  date +%s%N >> "$out"
''
