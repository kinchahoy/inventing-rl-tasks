# Oracle side of the complexifiers (author/complexify.md); the original recipe is replica.nix.
{ lib, ... }: {
  # CX-negative-ttl-override: the effective negative-cache cap is the drop-in's value (1800), not recursor.conf's;
  # the .dpkg-old leftover is inert, so there is nothing to reproduce for it.
  services.pdns-recursor.settings.recordcache.max_negative_ttl = lib.mkForce 1800;

  # CX-local-resolver: the host resolves through its own resolver; the zone is the search domain.
  networking.nameservers = [ "127.0.0.1" ];
  networking.search = [ "n23.test" ];

  # CX-socket-tuning
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 8388608;
    "net.core.wmem_max" = 8388608;
    "net.ipv4.ip_local_port_range" = "10240 65535";
  };
  systemd.services.pdns-recursor.serviceConfig.LimitNOFILE = 65536;
  systemd.services.dnsdist.serviceConfig.LimitNOFILE = 65536;

  # CX-nsd-secondary: the secondary at 198.51.100.7 may transfer the lab zone; all other transfers stay refused.
  services.nsd.zones."a23.test".provideXFR = [ "198.51.100.7 NOKEY" ];
}
