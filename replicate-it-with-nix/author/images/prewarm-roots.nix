# Task-declared closures, prefetched into the inputs image and the builder store.
let
  flake = builtins.getFlake "/opt/nix-inputs";
  pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; };
in import /opt/prewarm.nix pkgs
