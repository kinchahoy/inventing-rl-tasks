# Service and VM closures prefetched for agent, verifier and builder.
pkgs: with pkgs; [
  pdns-recursor dnsdist nsd sudo logrotate python3 openssh linuxPackages.kernel systemd qemu_kvm
]
