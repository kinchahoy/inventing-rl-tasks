{ config, lib, pkgs, ... }:
let
  share = path: extra: {
    inherit path;
    "valid users" = "@shared";
    "force user" = "quill";
    "force group" = "shared";
    "read only" = "no";
    "create mask" = "0660";
    "force create mode" = "0660";
    "directory mask" = "2770";
    "force directory mode" = "2770";
  } // extra;
in
{
  networking.hostName = "node41";
  time.timeZone = "America/Los_Angeles";

  users.groups = { quill.gid = 1000; rowan.gid = 1001; sage.gid = 1002; shared.gid = 1003; visitor.gid = 1004; };
  users.users = lib.mapAttrs (name: uid: {
    isNormalUser = true;
    inherit uid;
    group = name;
    extraGroups = lib.optional (name != "visitor") "shared";
  }) { quill = 1000; rowan = 1001; sage = 1002; visitor = 1004; };

  systemd.tmpfiles.rules = map (d: "d ${d} 2775 quill shared -") [ "/srv/fast" "/srv/docs" "/srv/docs/vault" ];

  # The array's share tree lives on the disks themselves; it is deliberately not created here, as
  # touching the path at boot would trigger the automount.
  boot.supportedFilesystems = [ "btrfs" ];
  # qemu-vm.nix overrides top-level fileSystems with the VM mount set; extra mounts go in virtualisation.fileSystems.
  virtualisation.fileSystems."/mnt/pool" = {
    device = "/dev/disk/by-label/pool";
    fsType = "btrfs";
    options = [
      "nofail" "noatime" "compress=zstd:3" "subvol=data"
      "x-systemd.automount" "x-systemd.idle-timeout=600" "x-systemd.mount-timeout=30s"
    ];
  };

  services.samba = {
    enable = true;
    settings = {
      global = {
        security = "user";
        "server min protocol" = "SMB3";
        "server signing" = "auto";
        "server multi channel support" = "yes";
        "map to guest" = "never";
        "usershare max shares" = "0";
        "hosts allow" = "127.0.0.1 192.0.2.0/24 100.64.0.0/10";
        "hosts deny" = "0.0.0.0/0";
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:aapl" = "yes";
        "fruit:metadata" = "stream";
        "fruit:resource" = "file";
        "fruit:encoding" = "native";
        "fruit:nfs_aces" = "no";
        "fruit:zero_file_id" = "yes";
      };
      fast = share "/srv/fast" { };
      docs = share "/srv/docs" { "veto files" = "/vault/"; "delete veto files" = "no"; };
      vault = share "/srv/docs/vault" { "fruit:time machine" = "yes"; };
      bulk = share "/mnt/pool/bulk" { };
    };
  };
  # smbclient, smbpasswd and testparm on PATH for operators.
  environment.systemPackages = [ config.services.samba.package ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  systemd.services.powertop = {
    description = "Power tuning";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
    };
  };

  # A4 sandbox probe: this derivation must NOT reach the network or read files outside the sandbox.
  environment.etc."sandbox-probe".source = pkgs.runCommand "sandbox-probe" { } ''
    if [ -r /builder-outside-marker ]; then echo "SANDBOX-ESCAPE: read /builder-outside-marker"; exit 1; fi
    if ${pkgs.curl}/bin/curl -s -m 8 -o /dev/null https://example.com; then echo "SANDBOX-ESCAPE: network"; exit 1; fi
    echo contained > $out
  '';
}
