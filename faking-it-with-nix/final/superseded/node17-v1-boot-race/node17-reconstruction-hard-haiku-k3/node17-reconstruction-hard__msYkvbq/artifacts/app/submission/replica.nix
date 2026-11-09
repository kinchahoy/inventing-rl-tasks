{ config, lib, pkgs, ... }:

let
  php = pkgs.php84;
  python3 = pkgs.python3;
  cgiGateway = ./cgi-gateway.wsgi;

  # Tenant accounts exactly as provisioned on the reference node.
  tenants = {
    amber = {
      uid = 1101;
      gid = 1000;
      dbHash = "*CE994D3F34F0502BC51156503AF81CDDB63F415E";
      dbMaxConn = 20;
      pgScram = "SCRAM-SHA-256$4096:1rJz1zqG8QX/Y9iyLfy+lA==$xiy0NZkFo/LAtz2nXOGKIe2zVKP/vQRkaWaOjY+I4Bs=:erHpSa6MlYgT5C+t+fyUrzYeTASwOPfh/4ctsI3JRbQ=";
      pgConnLimit = 20;
      token = "amber-private\n";
      index = "amber workspace\n";
    };
    cobalt = {
      uid = 1102;
      gid = 1001;
      dbHash = "*4E3F82FE2BB932A394FCFB9A3F056ACE68141483";
      dbMaxConn = 40;
      pgScram = "SCRAM-SHA-256$4096:0uFjL0lkmELvx5f9FwpW+w==$qqQzU/nP3uNK/vLoe1X7N6sppcWN8hJ7U8Hi1pYp+Ws=:TFrV6ScYH+rMr+DnKDmtpLofLmo94TnqPL3iJIUyguU=";
      pgConnLimit = 40;
      token = "cobalt-private\n";
      index = "cobalt workspace\n";
    };
  };

  mkHello = name: pkgs.writeText "hello-${name}.py" ''
    #!/usr/bin/python3
    print("Content-Type: text/plain\n")
    print("hello from ${name}")
  '';

  tenantFiles = lib.concatMapStrings (name: let t = tenants.${name}; in ''
    d /home/${name}/public_html 0755 ${name} ${name} -
    C /home/${name}/public_html/index.html 0644 ${name} ${name} - ${pkgs.writeText "index-${name}.html" t.index}
    d /home/${name}/public_html/cgi-bin 0755 ${name} ${name} -
    C /home/${name}/public_html/cgi-bin/hello.py 0755 ${name} ${name} - ${mkHello name}
    d /home/${name}/public_html/wsgi-bin 0755 ${name} ${name} -
    d /home/${name}/private 0700 ${name} ${name} -
    C /home/${name}/private/token 0600 ${name} ${name} - ${pkgs.writeText "token-${name}" t.token}
  '') (lib.attrNames tenants);

  tenantSite = name: let t = tenants.${name}; in ''
    WSGIDaemonProcess ${name} user=${name} group=${name} processes=1 threads=4
    <VirtualHost *:443>
        ServerName ${name}.node.test
        ServerAlias ${name}.node.alt.test
        SSLEngine on
        SSLCertificateFile /etc/node/server.crt
        SSLCertificateKeyFile /etc/node/server.key
        DocumentRoot /home/${name}/public_html
        ProxyTimeout 90
        RequestHeader unset Proxy early
        UseCanonicalName Off
        WSGIProcessGroup ${name}
        WSGIScriptAliasMatch ^/~[^/]+/cgi-bin/.*$ ${cgiGateway}
        CustomLog /var/log/web/${name}-access.log combined
        ErrorLog /var/log/web/${name}-error.log
        RewriteEngine on
        RewriteCond /home/${name}/public_html%{REQUEST_FILENAME} -f
        RewriteRule ^/cgi-bin/(.*)$ /~${name}/cgi-bin/$1 [PT,L]
        <FilesMatch ".+\.ph(p|ps|p3|tml)$">
            SetHandler "proxy:unix:/run/php/php-${name}-fpm.sock|fcgi://127.0.0.1"
        </FilesMatch>
    </VirtualHost>
    <VirtualHost *:80>
        ServerName ${name}.node.test
        ServerAlias ${name}.node.alt.test
        RedirectPermanent /.well-known/acme-challenge/ http://acme.node.test/.well-known/acme-challenge/
        RedirectPermanent / https://${name}.node.test/
    </VirtualHost>
    <Directory /home/${name}/public_html>
        AllowOverride AuthConfig FileInfo Indexes
        Options SymLinksIfOwnerMatch Indexes Includes
        Require all granted
    </Directory>
    <Directory /home/${name}/public_html/cgi-bin>
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    <Directory /home/${name}/public_html/wsgi-bin>
        SetHandler wsgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
  '';

  phpPool = name: let t = tenants.${name}; in {
    user = name;
    group = name;
    phpPackage = php;
    phpEnv = {
      HOME = "/home/${name}";
      PATH = "/usr/local/bin:/usr/bin:/bin";
      TMP = "/tmp";
      TMPDIR = "/tmp";
      NODE_LABEL = name;
    };
    settings = {
      "listen" = "/run/php/php-${name}-fpm.sock";
      "listen.owner" = "wwwrun";
      "listen.group" = "wwwrun";
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
      "php_value[post_max_size]" = if name == "cobalt" then "8M" else "2M";
      "php_value[upload_max_filesize]" = if name == "cobalt" then "8M" else "2M";
      "php_admin_value[open_basedir]" = "/home/${name}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
  };

  mysqlInit = pkgs.writeText "mysql-init.sql" (lib.concatMapStrings (name: let t = tenants.${name}; in ''
    CREATE USER IF NOT EXISTS '${name}'@'localhost' IDENTIFIED BY PASSWORD '${t.dbHash}' WITH MAX_USER_CONNECTIONS ${toString t.dbMaxConn};
    GRANT ALL PRIVILEGES ON `${name}`.* TO '${name}'@'localhost';
  '') (lib.attrNames tenants));

  pgInit = pkgs.writeText "pg-init.sql" (lib.concatMapStrings (name: let t = tenants.${name}; in ''
    ALTER ROLE ${name} CONNECTION LIMIT ${toString t.pgConnLimit} PASSWORD '${t.pgScram}';
  '') (lib.attrNames tenants));
in
{
  networking.hostName = "node17";
  # The reference serves HTTP/HTTPS directly with no host firewall in front.
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  networking.hosts = {
    "127.0.0.1" = [ "node17" "catalog.node.test" "sql.node.test" "cache.node.test" ];
  };

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  system.stateVersion = "26.05";

  # Keep the closure to what this node actually runs.
  environment.defaultPackages = lib.mkForce [ ];
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;
  documentation.doc.enable = false;
  documentation.nixos.enable = false;

  environment.systemPackages = [
    python3
    php
    pkgs.mariadb
    config.services.postgresql.package
    pkgs.memcached
    pkgs.curl
    pkgs.jq
    pkgs.apacheHttpd
  ];

  # ---- Accounts ----------------------------------------------------------
  users.groups = {
    amber = { gid = 1000; };
    cobalt = { gid = 1001; };
    tenants = { gid = 1002; members = [ "amber" "cobalt" ]; };
  };

  users.users = lib.mapAttrs (name: t: {
    isNormalUser = true;
    uid = t.uid;
    group = name;
    home = "/home/${name}";
    createHome = true;
    homeMode = "755";
    hashedPassword = "!";
    shell = pkgs.bashInteractive;
    extraGroups = [ "tenants" ];
  }) tenants;

  # ---- SSH ---------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
    };
  };

  # ---- sudo ---------------------------------------------------------------
  security.sudo.extraConfig = ''
    Defaults env_reset
    Defaults mail_badpass
    Defaults secure_path="/run/wrappers/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    Defaults use_pty
    amber ALL=(:adm) NOPASSWD: /run/current-system/sw/bin/cat /var/log/web/amber-access.log, /run/current-system/sw/bin/cat /var/log/web/amber-error.log
    cobalt ALL=(:adm) NOPASSWD: /run/current-system/sw/bin/cat /var/log/web/cobalt-access.log, /run/current-system/sw/bin/cat /var/log/web/cobalt-error.log
    cobalt ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl restart apache2
    %sudo ALL=(ALL:ALL) ALL
    %admin ALL=(ALL) ALL
  '';

  # ---- Hosts/system paths expected by tenants -----------------------------
  systemd.tmpfiles.rules = [
    "d /run/php 0755 root root -"
    "L+ /usr/bin/python3 - - - - ${python3}/bin/python3"
    "L+ /usr/bin/php - - - - ${php}/bin/php"
    "d /var/log/web 0750 root adm -"
    "f /var/log/web/amber-access.log 0640 root adm -"
    "f /var/log/web/amber-error.log 0640 root adm -"
    "f /var/log/web/cobalt-access.log 0640 root adm -"
    "f /var/log/web/cobalt-error.log 0640 root adm -"
    "d /srv/node 0755 root root -"
    "C /srv/node/index.html 0644 root root - ${pkgs.writeText "node-index.html" "node service\n"}"
  ] ++ lib.filter (line: line != "") (lib.splitString "\n" tenantFiles);

  # ---- Web: Apache -------------------------------------------------------
  services.httpd = {
    enable = true;
    adminAddr = "webmaster@localhost";
    extraModules = [
      "proxy"
      "proxy_fcgi"
      "rewrite"
      "userdir"
      "headers"
      "ssl"
      "status"
      { name = "wsgi"; path = "${pkgs.apacheHttpdPackages.mod_wsgi3}/modules/mod_wsgi.so"; }
    ];
    extraConfig = ''
      ServerName node.test
      ServerSignature On
      TraceEnable Off
      Listen 443
      WSGISocketPrefix /run/httpd/wsgi
      UserDir public_html
      UserDir disabled root

      <Location /server-status>
          SetHandler server-status
          Require local
      </Location>

      <Directory /home/*/public_html>
          AllowOverride FileInfo AuthConfig Limit Indexes
          Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
          Require method GET POST OPTIONS
      </Directory>

      ${tenantSite "amber"}
      ${tenantSite "cobalt"}

      <VirtualHost *:80>
          ServerName node.test
          ServerAlias node.alt.test
          RedirectPermanent /.well-known/acme-challenge/ http://acme.node.test/.well-known/acme-challenge/
          RedirectPermanent / https://node.test/
      </VirtualHost>
      <VirtualHost *:443>
          ServerName node.test
          ServerAlias node.alt.test
          SSLEngine on
          SSLCertificateFile /etc/node/server.crt
          SSLCertificateKeyFile /etc/node/server.key
          DocumentRoot /srv/node
          RewriteEngine on
          RewriteCond %{REQUEST_URI} ^/~([^/]*)(/.*)?$
          RewriteCond /home/%1/public_html -d
          RewriteRule ^/~([^/]*)(/.*)?$ https://$1.node.test$2 [NS,R=307]
      </VirtualHost>
      <Directory /srv/node>
          Require all granted
      </Directory>
    '';
  };

  # Operators and tenants refer to the web server as apache2. As on the
  # reference, the master process runs as root (it reads the TLS key and
  # opens the logs); worker processes drop to the configured User.
  systemd.services.httpd = {
    aliases = [ "apache2.service" ];
    serviceConfig = {
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
    };
  };

  # ---- PHP-FPM pools (one per tenant) ------------------------------------
  services.phpfpm.pools = lib.mapAttrs (name: _: phpPool name) tenants;

  # ---- MariaDB ------------------------------------------------------------
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "127.0.0.1";
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_general_ci";
    };
    initialDatabases = map (name: { inherit name; }) (lib.attrNames tenants);
    initialScript = mysqlInit;
  };
  systemd.services.mysql.aliases = [ "mariadb.service" ];

  # ---- PostgreSQL ---------------------------------------------------------
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    ensureDatabases = lib.attrNames tenants;
    ensureUsers = map (name: { inherit name; ensureDBOwnership = true; }) (lib.attrNames tenants);
    authentication = lib.mkOverride 10 ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
  };
  systemd.services.tenant-pg-roles = {
    description = "Tenant PostgreSQL role limits and credentials";
    after = [ "postgresql.service" "postgresql-setup.service" ];
    requires = [ "postgresql.service" "postgresql-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      ExecStart = "${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -f ${pgInit}";
    };
  };

  # ---- memcached ----------------------------------------------------------
  services.memcached = {
    enable = true;
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    extraOptions = [ "-U" "0" ];
  };

  # ---- cron ---------------------------------------------------------------
  services.cron.enable = true;
}
