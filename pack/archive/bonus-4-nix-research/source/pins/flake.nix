{
  # Shared nixpkgs pin for every replica task; flake.lock is the record.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs = _: { };
}
