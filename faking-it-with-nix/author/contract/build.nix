{ submission, nixpkgs }:
let
  machine = import (builtins.toPath (nixpkgs + "/nixos/lib/eval-config.nix")) {
    system = "x86_64-linux";
    modules = [
      /opt/contract/harness.nix
      (builtins.toPath (submission + "/replica.nix"))
    ];
  };
in machine.config.system.build.vm
