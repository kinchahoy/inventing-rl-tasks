# Oracle side of the complexifiers (author/complexify.md); the original recipe is replica.nix.
{ pkgs, ... }: {
  _module.args.cx = {
    # CX-sd-drop: the retired host stays in the target list and a relabel rule drops it.
    nodeTargets = [ { targets = [ "127.0.0.1:9102" ]; labels = { cluster = "lab"; role = "retired"; decommissioned = "true"; }; } ];
    nodeRelabel = [ { source_labels = [ "decommissioned" ]; regex = "true"; action = "drop"; } ];

    # CX-icmp-probe: an icmp blackbox module and a probe_icmp job for the loopback gateway.
    blackboxModules.icmp = { prober = "icmp"; timeout = "5s"; icmp.preferred_ip_protocol = "ip4"; };
    probeJobs = probeJob: [
      (probeJob "probe_icmp" "icmp" [ "127.0.0.1" ])
    ];
  };

  # CX-rules-glob: nothing to reproduce; the staged rule files on the reference are never loaded.

  # CX-textfile-timer: inventory gauges written into node_exporter's textfile directory.
  systemd.services.node31-inventory = {
    after = [ "systemd-tmpfiles-setup.service" ];
    path = [ pkgs.gawk pkgs.coreutils ];
    serviceConfig.Type = "oneshot";
    script = ''
      out=/var/lib/prometheus/node-exporter
      users=$(awk -F: '$3 >= 1000 && $7 ~ /bash$/ {n++} END {print n+0}' /etc/passwd)
      {
        echo '# TYPE node31_inventory_users gauge'
        echo "node31_inventory_users $users"
        echo '# TYPE node31_inventory_info gauge'
        echo 'node31_inventory_info{role="monitor"} 1'
      } > "$out/node31_inventory.prom.tmp"
      mv "$out/node31_inventory.prom.tmp" "$out/node31_inventory.prom"
    '';
  };
  systemd.timers.node31-inventory = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "5s"; OnUnitActiveSec = "60s"; };
  };
}
