# Service and VM closures prefetched for agent, verifier and builder.
pkgs: with pkgs; [
  exim dovecot sudo logrotate python3 openssh openssl linuxPackages.kernel systemd qemu_kvm
]
