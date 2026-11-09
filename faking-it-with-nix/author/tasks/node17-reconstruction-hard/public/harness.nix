{ modulesPath, pkgs, ... }: {
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  system.stateVersion = "26.05";
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [ (builtins.readFile ./id_ed25519.pub) ];
  environment.systemPackages = [ pkgs.python3 pkgs.curl pkgs.jq pkgs.util-linux ];
  environment.etc."node/server.crt".source = ./server.crt;
  environment.etc."node/server.key" = { source = ./server.key; mode = "0600"; };
  # Only VM plumbing/SSH/TLS credentials are supplied, not service policy/state.
  virtualisation = {
    memorySize = 3072;
    cores = 2;
    diskSize = 8192;
    graphics = false;
    # qemu-vm.nix already passes -machine accel=kvm:tcg; -cpu host forbids a silent TCG fallback.
    qemu.options = [ "-cpu host" ];
    forwardPorts = [
      { from = "host"; host.port = 3222; guest.port = 22; }
      { from = "host"; host.port = 9080; guest.port = 80; }
      { from = "host"; host.port = 9443; guest.port = 443; }
    ];
  };
}
