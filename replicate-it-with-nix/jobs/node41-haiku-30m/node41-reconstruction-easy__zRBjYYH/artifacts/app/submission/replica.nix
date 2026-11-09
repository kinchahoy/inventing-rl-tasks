{ config, lib, pkgs, ... }:

let
  # Samba share defaults shared by the fast, docs, vault and bulk shares.
  groupShare = path: extra: {
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
  # The reference runs with no host firewall (iptables policy ACCEPT, ufw inactive).
  networking.firewall.enable = false;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "C.UTF-8";

  boot.supportedFilesystems = [ "btrfs" ];

  boot.kernel.sysctl = {
    "kernel.printk" = "4 4 1 7";
    "kernel.kptr_restrict" = 1;
    "kernel.sysrq" = 176;
    "kernel.yama.ptrace_scope" = 1;
    "vm.mmap_min_addr" = 65536;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.use_tempaddr" = lib.mkForce 0;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 0;
  };

  # Accounts. UIDs/GIDs and the shared group membership match the provisioned machine.
  users.groups = {
    quill.gid = 1000;
    rowan.gid = 1001;
    sage.gid = 1002;
    shared = {
      gid = 1003;
      members = [ "quill" "rowan" "sage" ];
    };
    visitor.gid = 1004;
  };

  users.users = let
    person = name: uid: {
      isNormalUser = true;
      inherit uid;
      group = name;
      home = "/home/${name}";
      createHome = true;
      homeMode = "750";
      shell = pkgs.bashInteractive;
      hashedPassword = "!";
    };
  in {
    quill = person "quill" 1000;
    rowan = person "rowan" 1001;
    sage = person "sage" 1002;
    visitor = person "visitor" 1004;
  };

  # OpenSSH: key-only root login (harness supplies the key), no password logins, X11 forwarding on.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
  };
  # The reference unit is ssh.service; keep that name resolvable.
  systemd.services.sshd.aliases = [ "ssh.service" ];

  services.cron.enable = true;

  # Samba file server.
  services.samba = {
    enable = true;
    smbd.enable = true;
    nmbd.enable = true;
    openFirewall = false;
    settings = lib.mkForce {
      global = {
        security = "user";
        "server min protocol" = "SMB3";
        "server signing" = "auto";
        "server multi channel support" = "yes";
        "usershare max shares" = "0";
        "map to guest" = "never";
        # The reference has no invalid-users list; drop the NixOS default of root.
        "invalid users" = lib.mkForce [ ];
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
      fast = groupShare "/srv/fast" { };
      docs = groupShare "/srv/docs" {
        "veto files" = "/vault/";
        "delete veto files" = "no";
      };
      vault = groupShare "/srv/docs/vault" {
        "fruit:time machine" = "yes";
      };
      bulk = groupShare "/mnt/pool/bulk" { };
    };
  };
  # Reference unit names are smbd.service and nmbd.service.
  systemd.services.samba-smbd.aliases = [ "smbd.service" ];
  systemd.services.samba-nmbd.aliases = [ "nmbd.service" ];

  # Shared data directories on the root disk.
  systemd.tmpfiles.rules = [
    "d /srv 0755 root root -"
    "d /srv/docs 2775 quill shared -"
    "d /srv/docs/vault 2775 quill shared -"
    "d /srv/fast 2775 quill shared -"
  ];

  # Btrfs pool on the two USB data disks (label "pool"), subvolume "data",
  # automounted on first access and unmounted after 10 minutes idle.
  virtualisation.fileSystems."/mnt/pool" = {
    device = "/dev/disk/by-label/pool";
    fsType = "btrfs";
    options = [
      "nofail"
      "noatime"
      "compress=zstd:3"
      "subvol=data"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=30s"
    ];
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    rsync
    cifs-utils
  ];
}
