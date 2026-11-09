{ modulesPath, pkgs, lib, ... }: {
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  system.stateVersion = "26.05";
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [ (builtins.readFile ./id_ed25519.pub) ];
  boot.kernelModules = [ "xhci_pci" "usb_storage" ];
  environment.systemPackages = [ pkgs.python3 pkgs.curl pkgs.jq pkgs.util-linux ];
  # Only VM plumbing and SSH are supplied, not host policy or state.
  virtualisation = {
    memorySize = 3072;
    cores = 2;
    diskSize = 8192;
    graphics = false;
    # qemu-vm.nix already passes -machine accel=kvm:tcg; -cpu host forbids a silent TCG fallback.
    # The machine's two USB data disks: fixture images in the directory the VM script is started from (the script cds into a scratch dir first).
    qemu.options = [
      "-cpu host"
      "-device qemu-xhci"
      "-drive if=none,id=usba,file=$OLDPWD/usb-a.img,format=raw" "-device usb-storage,drive=usba"
      "-drive if=none,id=usbb,file=$OLDPWD/usb-b.img,format=raw" "-device usb-storage,drive=usbb"
    ];
    forwardPorts = [ { from = "host"; host.port = 3222; guest.port = 22; } ];
  };
}
