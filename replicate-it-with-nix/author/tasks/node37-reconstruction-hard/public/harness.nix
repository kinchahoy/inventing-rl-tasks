{ modulesPath, pkgs, lib, ... }: {
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  system.stateVersion = "26.05";
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [ (builtins.readFile ./id_ed25519.pub) ];
  environment.systemPackages = [ pkgs.python3 pkgs.curl pkgs.jq pkgs.util-linux ];
  # Only VM plumbing and SSH are supplied, not host policy or state.
  virtualisation = {
    memorySize = 3072;
    cores = 2;
    diskSize = 8192;
    graphics = false;
    # qemu-vm.nix already passes -machine accel=kvm:tcg; -cpu host forbids a silent TCG fallback.
    qemu.options = [ "-cpu host" ];
    forwardPorts = [ { from = "host"; host.port = 3222; guest.port = 22; } ];
  };
}
