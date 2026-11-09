# Service and VM closures prefetched for agent, verifier and builder.
pkgs: with pkgs; [
  prometheus prometheus.cli prometheus-alertmanager prometheus-node-exporter prometheus-blackbox-exporter
  nginx python3 openssl apacheHttpd openssh linuxPackages.kernel systemd qemu_kvm
]
