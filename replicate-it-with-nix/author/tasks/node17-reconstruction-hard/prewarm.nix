# Service and VM closures prefetched for agent, verifier and builder.
pkgs: with pkgs; [
  php mariadb postgresql_17 postgresql_17.pkgs.postgis
  memcached apacheHttpdPackages.mod_wsgi3 fcgiwrap sudo
  apacheHttpd python3 openssh linuxPackages.kernel systemd qemu_kvm
]
