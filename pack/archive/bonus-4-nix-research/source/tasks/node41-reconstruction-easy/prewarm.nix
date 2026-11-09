# Service and VM closures prefetched for agent, verifier and builder.
pkgs: with pkgs; [
  python3 util-linux iproute2 gawk gnugrep coreutils bash samba powertop
  openssh linuxPackages.kernel systemd qemu_kvm kmod
]
