# STUDY: Haiku 5.5, trial kLthoPm, reward 0.83 (29/35). Failed: slice_limits, postgres_isolation, cgi_identity,
# STUDY: login_limits, log_rotation, db_role_limits. See ../HAIKU-VS-ORACLE-node17.md.
{ config, lib, pkgs, ... }:
let
  apache = pkgs.apacheHttpd;
  php = pkgs.php84;
  modDir = "${apache}/modules";

  httpdConf = pkgs.writeText "httpd.conf" ''
    ServerRoot "${apache}"
    DefaultRuntimeDir /run/apache2
    PidFile /run/apache2/apache2.pid
    ScriptSock /run/apache2/cgisock
    WSGISocketPrefix /run/apache2/wsgi
    Timeout 300
    KeepAlive On
    MaxKeepAliveRequests 100
    KeepAliveTimeout 5
    # STUDY: Apache runs as www-data (fine), but see mod_cgid below: CGI then also runs as www-data.
    User www-data
    Group www-data
    HostnameLookups Off
    ErrorLog /var/log/apache2/error.log
    LogLevel warn
    ServerName node.test
    ServerTokens OS
    ServerSignature On
    TraceEnable Off

    LoadModule authn_core_module ${modDir}/mod_authn_core.so
    LoadModule authn_file_module ${modDir}/mod_authn_file.so
    LoadModule authz_core_module ${modDir}/mod_authz_core.so
    LoadModule authz_host_module ${modDir}/mod_authz_host.so
    LoadModule authz_user_module ${modDir}/mod_authz_user.so
    LoadModule access_compat_module ${modDir}/mod_access_compat.so
    LoadModule auth_basic_module ${modDir}/mod_auth_basic.so
    LoadModule unixd_module ${modDir}/mod_unixd.so
    LoadModule mpm_event_module ${modDir}/mod_mpm_event.so
    LoadModule log_config_module ${modDir}/mod_log_config.so
    LoadModule logio_module ${modDir}/mod_logio.so
    LoadModule mime_module ${modDir}/mod_mime.so
    LoadModule alias_module ${modDir}/mod_alias.so
    LoadModule autoindex_module ${modDir}/mod_autoindex.so
    LoadModule dir_module ${modDir}/mod_dir.so
    LoadModule env_module ${modDir}/mod_env.so
    LoadModule setenvif_module ${modDir}/mod_setenvif.so
    LoadModule headers_module ${modDir}/mod_headers.so
    LoadModule filter_module ${modDir}/mod_filter.so
    LoadModule deflate_module ${modDir}/mod_deflate.so
    LoadModule negotiation_module ${modDir}/mod_negotiation.so
    LoadModule reqtimeout_module ${modDir}/mod_reqtimeout.so
    LoadModule rewrite_module ${modDir}/mod_rewrite.so
    LoadModule socache_shmcb_module ${modDir}/mod_socache_shmcb.so
    LoadModule ssl_module ${modDir}/mod_ssl.so
    LoadModule status_module ${modDir}/mod_status.so
    LoadModule userdir_module ${modDir}/mod_userdir.so
    LoadModule proxy_module ${modDir}/mod_proxy.so
    LoadModule proxy_fcgi_module ${modDir}/mod_proxy_fcgi.so
    # STUDY: MISS cgi_identity: mod_cgid executes CGI as the Apache user. Ubuntu used suexec (+ userdir) so ~user CGI runs as the tenant.
    # STUDY: The oracle uses per-tenant fcgiwrap sockets. The agent checked CGI output, never the uid.
    LoadModule cgid_module ${modDir}/mod_cgid.so
    LoadModule wsgi_module ${pkgs.apacheHttpdPackages.mod_wsgi3}/modules/mod_wsgi.so

    <IfModule mpm_event_module>
        StartServers 2
        MinSpareThreads 25
        MaxSpareThreads 75
        ThreadLimit 64
        ThreadsPerChild 25
        MaxRequestWorkers 150
        MaxConnectionsPerChild 0
    </IfModule>

    Listen 80
    Listen 443

    <IfModule ssl_module>
        SSLRandomSeed startup builtin
        SSLRandomSeed startup file:/dev/urandom 512
        SSLRandomSeed connect builtin
        SSLRandomSeed connect file:/dev/urandom 512
        SSLSessionCache shmcb:/run/apache2/ssl_scache(512000)
        SSLSessionCacheTimeout 300
        SSLCipherSuite HIGH:!aNULL
        SSLProtocol all -SSLv3
    </IfModule>

    AddType application/x-x509-ca-cert .crt
    AddType application/x-pkcs7-crl .crl

    <IfModule status_module>
        <Location /server-status>
            SetHandler server-status
            Require local
        </Location>
        ExtendedStatus On
    </IfModule>

    <IfModule userdir_module>
        UserDir public_html
        UserDir disabled root
        <Directory /home/*/public_html>
            AllowOverride FileInfo AuthConfig Limit Indexes
            Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
            Require method GET POST OPTIONS
        </Directory>
    </IfModule>

    AccessFileName .htaccess
    <FilesMatch "^\.ht">
        Require all denied
    </FilesMatch>

    <Directory />
        Options FollowSymLinks
        AllowOverride None
        Require all denied
    </Directory>

    <Directory /var/www/>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
    LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %O" common
    LogFormat "%{Referer}i -> %U" referer
    LogFormat "%{User-agent}i" agent

    DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm
    TypesConfig ${apache}/conf/mime.types

    # STUDY: vhost files copied from the reference into web/*.conf and installed via environment.etc.
    IncludeOptional /etc/apache2/sites-enabled/*.conf
  '';

  tenantFiles = [
    { user = "amber"; name = "amber"; }
    { user = "cobalt"; name = "cobalt"; }
  ];
  tenantSeed = t: ''
    install -d -m 0755 -o ${t.user} -g ${t.user} /home/${t.user}/public_html
    install -d -m 0755 -o ${t.user} -g ${t.user} /home/${t.user}/public_html/cgi-bin
    install -d -m 0755 -o ${t.user} -g ${t.user} /home/${t.user}/public_html/wsgi-bin
    install -d -m 0700 -o ${t.user} -g ${t.user} /home/${t.user}/private
    [ -e /home/${t.user}/public_html/index.html ] || install -m 0644 -o ${t.user} -g ${t.user} ${./tenants + "/${t.user}/public_html/index.html"} /home/${t.user}/public_html/index.html
    [ -e /home/${t.user}/public_html/cgi-bin/hello.py ] || install -m 0755 -o ${t.user} -g ${t.user} ${./tenants + "/${t.user}/public_html/cgi-bin/hello.py"} /home/${t.user}/public_html/cgi-bin/hello.py
    [ -e /home/${t.user}/private/token ] || install -m 0600 -o ${t.user} -g ${t.user} ${./tenants + "/${t.user}/private/token"} /home/${t.user}/private/token
  '';

  phpPool = name: uid: {
    user = name;
    group = name;
    phpPackage = php;
    settings = {
      "listen" = "/run/php/php-${name}-fpm.sock";
      "listen.owner" = "www-data";
      "listen.group" = "www-data";
      "listen.mode" = "0660";
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
      "pm.max_requests" = 10000;
      "request_terminate_timeout" = 180;
      "clear_env" = "yes";
      "php_value[max_execution_time]" = 120;
      "php_value[memory_limit]" = "128M";
      "php_value[post_max_size]" = if name == "amber" then "2M" else "8M";
      "php_value[upload_max_filesize]" = if name == "amber" then "2M" else "8M";
      "php_admin_value[open_basedir]" = "/home/${name}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
    phpEnv = {
      HOME = "/home/${name}";
      PATH = "/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin";
      TMP = "/tmp";
      TMPDIR = "/tmp";
      NODE_LABEL = name;
    };
  };
in
{
  networking.hostName = "node17";
  networking.firewall.enable = false;
  networking.hosts = {
    "127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];
  };

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  # Accounts: same names, UIDs, GIDs, and locked passwords as the reference.
  users.groups = {
    amber = { gid = 1000; };
    cobalt = { gid = 1001; };
    # STUDY: Half of CX-login-limits: the group exists, but no security.pam.loginLimits -> MISS login_limits (ulimit -Hu = 11765, not 200).
    tenants = { gid = 1002; members = [ "amber" "cobalt" ]; };
    www-data = { gid = 33; };
    memcache = { gid = 122; };
  };
  users.users = {
    amber = {
      uid = 1101;
      group = "amber";
      isNormalUser = true;
      home = "/home/amber";
      homeMode = "755";
      createHome = true;
      hashedPassword = "!";
      # STUDY: Works, but the idiomatic form is `shell = pkgs.bashInteractive;` (oracle).
      shell = "/run/current-system/sw/bin/bash";
    };
    cobalt = {
      uid = 1102;
      group = "cobalt";
      isNormalUser = true;
      home = "/home/cobalt";
      homeMode = "755";
      createHome = true;
      hashedPassword = "!";
      shell = "/run/current-system/sw/bin/bash";
    };
    www-data = {
      uid = 33;
      group = "www-data";
      isSystemUser = true;
      home = "/var/www";
      shell = "/run/current-system/sw/bin/nologin";
    };
    memcache = {
      uid = 113;
      group = "memcache";
      isSystemUser = true;
      home = "/nonexistent";
      shell = "/run/current-system/sw/bin/nologin";
    };
  };
  users.users.root.hashedPassword = "!";

  # SSH: key-based root only, as in the reference.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkForce "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
  };

  # Sudo rules for the tenants.
  # STUDY: Structured sudo rules. Lists both /run/current-system/sw/bin/cat and /bin/cat because sudo matches the resolved path
  # STUDY: of what the user typed (trace steps 83-84). Correct: passes sudo_log_policy and sudo_decoy.
  security.sudo.extraRules = [
    {
      users = [ "amber" ];
      runAs = ":adm";
      commands = [
        { command = "/run/current-system/sw/bin/cat /var/log/web/amber-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/amber-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/cat /var/log/web/amber-error.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/amber-error.log"; options = [ "NOPASSWD" ]; }
      ];
    }
    {
      users = [ "cobalt" ];
      runAs = ":adm";
      commands = [
        { command = "/run/current-system/sw/bin/cat /var/log/web/cobalt-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/cobalt-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/cat /var/log/web/cobalt-error.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/cobalt-error.log"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # Apache, served by a unit named apache2 with the reference's vhosts.
  environment.etc = {
    "apache2/httpd.conf".source = httpdConf;
    "apache2/sites-enabled/amber.conf".source = ./web/amber.conf;
    "apache2/sites-enabled/cobalt.conf".source = ./web/cobalt.conf;
    "apache2/sites-enabled/node.conf".source = ./web/node.conf;
  };
  # STUDY: Unit named apache2 (Ubuntu's name) with Type=simple + -DFOREGROUND, so the PidFile directive is harmless here.
  systemd.services.apache2 = {
    description = "The Apache HTTP Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    wants = [ "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    serviceConfig = {
      Type = "simple";
      RuntimeDirectory = "apache2";
      ExecStartPre = "${apache}/bin/httpd -t -f /etc/apache2/httpd.conf";
      ExecStart = "${apache}/bin/httpd -f /etc/apache2/httpd.conf -DFOREGROUND";
      ExecReload = "${apache}/bin/httpd -f /etc/apache2/httpd.conf -k graceful";
      ExecStop = "${apache}/bin/httpd -f /etc/apache2/httpd.conf -k graceful-stop";
      KillMode = "mixed";
      KillSignal = "SIGWINCH";
      Restart = "on-failure";
    };
  };

  # PHP-FPM pools per tenant (socket paths as in the reference).
  services.phpfpm.pools = {
    amber = phpPool "amber" 1101;
    cobalt = phpPool "cobalt" 1102;
  };

  # Tenant pools must reach /home/<tenant>/public_html, as in the reference.
  # STUDY: Found by debugging 'File not found' from PHP-FPM (trace step 97-98).
  systemd.services.phpfpm-amber.serviceConfig.ProtectHome = lib.mkForce false;
  systemd.services.phpfpm-cobalt.serviceConfig.ProtectHome = lib.mkForce false;

  # Relational database services and memcached.
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "amber" "cobalt" ];
    settings.mysqld = {
      bind-address = "127.0.0.1";
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_general_ci";
    };
    initialScript = pkgs.writeText "mariadb-init.sql" ''
      CREATE USER IF NOT EXISTS 'amber'@'localhost' IDENTIFIED BY PASSWORD '*CE994D3F34F0502BC51156503AF81CDDB63F415E' WITH MAX_USER_CONNECTIONS 20;
      GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
      CREATE USER IF NOT EXISTS 'cobalt'@'localhost' IDENTIFIED BY PASSWORD '*4E3F82FE2BB932A394FCFB9A3F056ACE68141483' WITH MAX_USER_CONNECTIONS 40;
      GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
      DROP DATABASE IF EXISTS test;
      DELETE FROM mysql.global_priv WHERE LENGTH(User) = 0;
      DELETE FROM mysql.db WHERE LENGTH(User) = 0;
      FLUSH PRIVILEGES;
    '';
  };

  # STUDY: MISS postgres_isolation: no `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC`, so amber can connect to cobalt's DB.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17.withPackages (ps: [ ps.postgis ]);
    enableTCPIP = true;
    authentication = lib.mkOverride 10 ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
      port = 5432;
    };
    ensureDatabases = [ "amber" "cobalt" ];
    # STUDY: ensureUsers/ensureDatabases run in postgresql-setup.service on every boot; ensureDBOwnership makes the role own the same-named DB.
    ensureUsers = [
      { name = "amber"; ensureDBOwnership = true; }
      { name = "cobalt"; ensureDBOwnership = true; }
    ];
  };
  # Tenant roles keep the reference SCRAM verifiers, connection limits, and PostGIS.
  # STUDY: Half of CX-db-role-limits: connection caps copied (from pg_roles), `ALTER ROLE ... SET statement_timeout` missing
  # STUDY: -> MISS db_role_limits (detail: ('amber', b'0')).
  systemd.services.postgresql-tenants = {
    description = "PostgreSQL tenant roles and extensions";
    after = [ "postgresql.service" "postgresql-setup.service" ];
    requires = [ "postgresql-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      Group = "postgres";
    };
    script = ''
      PSQL="${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -tA"
      $PSQL -d postgres <<'SQL'
      ALTER ROLE amber CONNECTION LIMIT 20 PASSWORD 'SCRAM-SHA-256$4096:1rJz1zqG8QX/Y9iyLfy+lA==$xiy0NZkFo/LAtz2nXOGKIe2zVKP/vQRkaWaOjY+I4Bs=:erHpSa6MlYgT5C+t+fyUrzYeTASwOPfh/4ctsI3JRbQ=';
      ALTER ROLE cobalt CONNECTION LIMIT 40 PASSWORD 'SCRAM-SHA-256$4096:0uFjL0lkmELvx5f9FwpW+w==$qqQzU/nP3uNK/vLoe1X7N6sppcWN8hJ7U8Hi1pYp+Ws=:TFrV6ScYH+rMr+DnKDmtpLofLmo94TnqPL3iJIUyguU=';
      SQL
      $PSQL -d amber -c "CREATE EXTENSION IF NOT EXISTS postgis"
      $PSQL -d cobalt -c "CREATE EXTENSION IF NOT EXISTS postgis"
    '';
  };

  # STUDY: Uses the NixOS module (oracle uses a raw unit); both pass cache_protocol and server_tuning.
  services.memcached = {
    enable = true;
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    user = "memcache";
  };

  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;

  services.cron.enable = true;
  services.rsyslogd.enable = true;

  # Directories and logs.
  # STUDY: MISS slice_limits: nowhere in this module is there a systemd.slices."user-" with MemoryHigh=80% / MemoryMax=90%.
  systemd.tmpfiles.rules = [
    "d /run/php 0755 root root -"
    "d /var/log/apache2 0755 root root -"
    "d /var/log/web 0750 root adm -"
    "f /var/log/web/amber-access.log 0640 root adm -"
    "f /var/log/web/amber-error.log 0640 root adm -"
    "f /var/log/web/cobalt-access.log 0640 root adm -"
    "f /var/log/web/cobalt-error.log 0640 root adm -"
    "d /var/www/html 0755 root root -"
    "d /srv/node 0755 root root -"
  ];

  # Operator and tenant seeded files, plus compatibility paths the reference provides.
  # STUDY: Activation scripts run on every switch/boot before services. Works for seeding but tmpfiles or a oneshot is more idiomatic.
  # STUDY: Note also: no services.logrotate.settings for /var/log/web -> MISS log_rotation.
  system.activationScripts.node17Compat = {
    deps = [ "users" "groups" ];
    text = ''
      install -d -m 0755 /srv/node /usr/bin
      [ -e /srv/node/index.html ] || install -m 0644 ${./node/index.html} /srv/node/index.html
      ln -sfn ${pkgs.python3}/bin/python3 /usr/bin/python3
      ln -sfn /run/current-system/sw/bin/systemctl /usr/bin/systemctl
      ln -sfn ${pkgs.coreutils}/bin/cat /bin/cat
      ${lib.concatMapStrings tenantSeed tenantFiles}
    '';
  };

  environment.systemPackages = with pkgs; [
    apache
    php
    python3
    curl
    jq
    util-linux
    nano
    htop
    openssl
    lsof
    config.services.mysql.package
    config.services.postgresql.package
  ];

  system.stateVersion = "26.05";
}
