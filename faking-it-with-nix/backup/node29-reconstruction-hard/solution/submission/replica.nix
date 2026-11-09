{ config, lib, pkgs, cx, ... }:
let
  # Numeric ids match the reference so restored mailboxes keep their owners.
  mailUsers = { fern = 1201; moss = 1202; };
  eximConf = ''
    primary_hostname = node29.n29.test
    qualify_domain = n29.test
    domainlist local_domains = n29.test : node29.n29.test
    hostlist relay_from_hosts = 127.0.0.1 : ::1
    ${cx.eximMain}
    daemon_smtp_ports = 25 : 587
    local_interfaces = <; 0.0.0.0
    tls_certificate = /etc/node29/server.crt
    tls_privatekey = /etc/node29/server.key
    tls_advertise_hosts = *
    smtp_banner = $smtp_active_hostname ESMTP node29
    host_lookup =
    rfc1413_query_timeout = 0s
    message_size_limit = 25M
    check_spool_space = 50M
    remote_max_parallel = 10
    smtp_connect_backlog = 40
    smtp_accept_max = 40
    smtp_accept_max_per_host = 10
    ignore_bounce_errors_after = 0h
    message_logs = false
    add_environment = <; PATH=/bin:/usr/bin
    keep_environment =
    log_selector = +address_rewrite +all_parents +delivery_size +deliver_time +incoming_interface +incoming_port +smtp_confirmation +smtp_protocol_error +smtp_syntax_error
    acl_smtp_rcpt = acl_check_rcpt

    begin acl

    acl_check_rcpt:
      accept hosts = :
      deny   local_parts = ^[.] : ^.*[@%!/|]
      accept hosts = +relay_from_hosts
      accept authenticated = *
      accept domains = +local_domains
             endpass
             message = unknown user
             verify = recipient
      deny   message = relay not permitted

    ${cx.eximAcl}

    begin routers

    legacy_app_mail:
      driver = redirect
      domains = +local_domains
      condition = ''${if match{$h_X-Mailer:}{Legacy mailer}}
      data = :blackhole:

    system_aliases:
      driver = redirect
      domains = +local_domains
      data = ''${lookup{$local_part}lsearch{/etc/aliases}}
      allow_fail
      allow_defer
      forbid_file
      forbid_pipe

    app_route:
      driver = manualroute
      domains = ! +local_domains
      condition = ''${if match{$h_X-Mailer:}{Legacy mailer}}
      transport = remote_smtp
      route_list = * smarthost.n29.test::2527

    smart_route:
      driver = manualroute
      domains = ! +local_domains
      transport = remote_smtp
      route_list = * smarthost.n29.test::2526

    localuser:
      driver = accept
      domains = +local_domains
      check_local_user
      transport = local_delivery

    begin transports

    remote_smtp:
      driver = smtp
      hosts_avoid_tls = <; 0.0.0.0/0 ; 0::0/0
      dkim_domain = n29.test
      dkim_selector = mail
      dkim_private_key = /var/lib/exim-dkim/n29.test.key

    local_delivery:
      driver = appendfile
      directory = $home/Maildir
      maildir_format
      create_directory
      directory_mode = 0700
      mode = 0600
      delivery_date_add
      envelope_to_add
      return_path_add

    begin retry

    smarthost.n29.test * F,2h,1m
    * * F,2h,5m; F,1d,15m

    begin rewrite

    *@node29.n29.test $1@n29.test Ffs

    begin authenticators

    dovecot_plain:
      driver = dovecot
      public_name = PLAIN
      server_socket = /var/run/dovecot2/auth-client
      server_set_id = $auth1

    dovecot_login:
      driver = dovecot
      public_name = LOGIN
      server_socket = /var/run/dovecot2/auth-client
      server_set_id = $auth1
  '';
in {
  imports = [ ./complexify.nix ];
  networking.hostName = "node29";
  networking.firewall.allowedTCPPorts = [ 22 25 587 143 993 ];
  networking.hosts."127.0.0.1" = [ "node29.n29.test" "smarthost.n29.test" ];

  users.groups = lib.mapAttrs (_: gid: { inherit gid; }) mailUsers;
  users.users = lib.mapAttrs (name: uid: {
    isNormalUser = true;
    inherit uid;
    group = name;
    home = "/home/${name}";
    homeMode = "0700";
    createHome = true;
    shell = pkgs.bashInteractive;
    initialPassword = "${name}-pass";
  }) mailUsers;

  environment.etc."aliases".text = ''
    postmaster: fern
    abuse: fern
    root: fern
    team: fern, moss
  '';
  environment.etc."mailname".text = "n29.test\n";
  # The harness installs the key root-only; exim reads it after dropping privileges.
  environment.etc."node29/server.key" = {
    mode = lib.mkForce "0640";
    group = "exim";
  };

  services.exim = {
    enable = true;
    config = eximConf;
  };
  services.mail.sendmailSetuidWrapper = {
    program = "sendmail";
    source = "${config.services.exim.package}/bin/exim";
    setuid = true;
    owner = "root";
    group = "root";
  };
  # DKIM signing key: generated on first boot, readable by exim only.
  systemd.services.exim-dkim-key = {
    wantedBy = [ "exim.service" ];
    before = [ "exim.service" ];
    path = [ pkgs.openssl ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      install -d -m 0750 -o exim -g exim /var/lib/exim-dkim
      test -e /var/lib/exim-dkim/n29.test.key || {
        openssl genrsa -out /var/lib/exim-dkim/n29.test.key 2048
        chown exim:exim /var/lib/exim-dkim/n29.test.key
        chmod 0640 /var/lib/exim-dkim/n29.test.key
      }
    '';
  };

  # Dovecot 2.4 settings (nixpkgs 26.05); the reference runs 2.3 with equivalent policy.
  services.dovecot2 = {
    enable = true;
    enablePAM = true;
    settings = {
      dovecot_config_version = "2.4.0";
      dovecot_storage_version = "2.4.0";
      protocols.imap = true;
      mail_driver = "maildir";
      mail_path = "~/Maildir";
      mail_inbox_path = "~/Maildir";
      first_valid_uid = 1000;
      ssl = "required";
      ssl_server_cert_file = "/etc/node29/server.crt";
      ssl_server_key_file = "/etc/node29/server.key";
      ssl_min_protocol = "TLSv1.2";
      auth_allow_cleartext = false;
      auth_mechanisms = "plain login";
      login_greeting = "Ready.";
      "namespace inbox" = {
        inbox = true;
        "mailbox Drafts" = { special_use = "\\Drafts"; auto = "subscribe"; };
        "mailbox Sent" = { special_use = "\\Sent"; auto = "subscribe"; };
        "mailbox Trash" = { special_use = "\\Trash"; auto = "subscribe"; };
        "mailbox Junk" = { special_use = "\\Junk"; auto = "subscribe"; };
      };
      "service auth"."unix_listener auth-client" = { mode = "0660"; user = "exim"; };
      "service imap-login"."inet_listener imap".port = 143;
      "service imap-login"."inet_listener imaps" = { port = 993; ssl = true; };
    };
  };

  # Debian-style tooling paths used by operators' scripts.
  systemd.tmpfiles.rules = [
    "d /usr/sbin 0755 root root -"
    "L+ /usr/sbin/sendmail - - - - /run/wrappers/bin/sendmail"
  ];
}
