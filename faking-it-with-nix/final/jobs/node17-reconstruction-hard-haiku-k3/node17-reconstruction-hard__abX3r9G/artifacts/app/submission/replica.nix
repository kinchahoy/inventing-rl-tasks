{ config, lib, pkgs, ... }:

let
  coreutils = pkgs.coreutils;

  # PHP 8.1 is no longer packaged in this nixpkgs; PHP 8.4 is the closest supported line.
  php = pkgs.php84.buildEnv {
    extensions = ({ enabled, all }: enabled ++ (with all; [
      mysqli pdo_mysql pdo_pgsql pgsql mbstring opcache
    ]));
  };

  python = pkgs.python3.withPackages (ps: with ps; [
    requests jinja2 certifi urllib3 setuptools jsonschema pyserial pytz babel
  ]);

  # Seeded tenant and service files. They are created only when missing, so
  # later tenant edits survive activation.
  seedFile = path: owner: group: mode: content: ''
    if [ ! -e ${path} ]; then
      ${coreutils}/bin/install -D -o ${owner} -g ${group} -m ${mode} ${pkgs.writeText (baseNameOf path) content} ${path}
    fi
  '';

  seedDir = path: owner: group: mode: ''
    ${coreutils}/bin/install -d -o ${owner} -g ${group} -m ${mode} ${path}
  '';

  vhostBlock = name: ''
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
        SetHandler cgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    <Directory /home/${name}/public_html/wsgi-bin>
        SetHandler wsgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
  '';

  httpdExtra = ''
    ServerName node.test
    Listen 80
    Listen 443
    Timeout 300
    KeepAlive On
    MaxKeepAliveRequests 100
    KeepAliveTimeout 5

    WSGISocketPrefix /run/wsgi

    SSLSessionCache shmcb:/run/httpd/ssl_scache(512000)
    SSLSessionCacheTimeout 300
    SSLCipherSuite HIGH:!aNULL
    SSLProtocol all -SSLv3

    <IfModule reqtimeout_module>
        RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
    </IfModule>

    <IfModule dir_module>
        DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm
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

    <Location /server-status>
        SetHandler server-status
        Require local
    </Location>

    ${vhostBlock "amber"}
    ${vhostBlock "cobalt"}

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
    <VirtualHost *:80>
        ServerName node.test
        ServerAlias node.alt.test
        RedirectPermanent /.well-known/acme-challenge/ http://acme.node.test/.well-known/acme-challenge/
        RedirectPermanent / https://node.test/
    </VirtualHost>
    <Directory /srv/node>
        Require all granted
    </Directory>
  '';

  mysqlInit = pkgs.writeText "node-mysql-init.sql" ''
    CREATE DATABASE IF NOT EXISTS `amber` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    CREATE DATABASE IF NOT EXISTS `cobalt` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    CREATE USER IF NOT EXISTS 'amber'@'localhost' IDENTIFIED BY PASSWORD '*CE994D3F34F0502BC51156503AF81CDDB63F415E' WITH MAX_USER_CONNECTIONS 20;
    CREATE USER IF NOT EXISTS 'cobalt'@'localhost' IDENTIFIED BY PASSWORD '*4E3F82FE2BB932A394FCFB9A3F056ACE68141483' WITH MAX_USER_CONNECTIONS 40;
    GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
    GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
    DROP DATABASE IF EXISTS `test`;
    FLUSH PRIVILEGES;
  '';

  pgInit = pkgs.writeText "node-pg-init.sql" ''
    CREATE ROLE amber LOGIN CONNECTION LIMIT 20 PASSWORD 'SCRAM-SHA-256$4096:1rJz1zqG8QX/Y9iyLfy+lA==$xiy0NZkFo/LAtz2nXOGKIe2zVKP/vQRkaWaOjY+I4Bs=:erHpSa6MlYgT5C+t+fyUrzYeTASwOPfh/4ctsI3JRbQ=';
    CREATE ROLE cobalt LOGIN CONNECTION LIMIT 40 PASSWORD 'SCRAM-SHA-256$4096:0uFjL0lkmELvx5f9FwpW+w==$qqQzU/nP3uNK/vLoe1X7N6sppcWN8hJ7U8Hi1pYp+Ws=:TFrV6ScYH+rMr+DnKDmtpLofLmo94TnqPL3iJIUyguU=';
    CREATE DATABASE amber OWNER amber;
    CREATE DATABASE cobalt OWNER cobalt;
    \c amber
    CREATE EXTENSION IF NOT EXISTS postgis;
    \c cobalt
    CREATE EXTENSION IF NOT EXISTS postgis;
  '';
in
{
  networking.hostName = "node17";
  i18n.defaultLocale = "C.UTF-8";

  # ---- Identities -------------------------------------------------------
  users.groups = {
    amber = { gid = 1000; };
    cobalt = { gid = 1001; };
    tenants = { gid = 1002; members = [ "amber" "cobalt" ]; };
    www-data = { gid = 33; };
    dialout = { gid = lib.mkForce 20; };
    lp = { gid = lib.mkForce 7; };
    sudo = { gid = 27; };
    admin = { gid = 117; };
    memcache = { gid = 122; };
  };

  users.users = {
    amber = {
      isNormalUser = true;
      uid = 1101;
      group = "amber";
      home = "/home/amber";
      createHome = false;
      shell = "/bin/bash";
      hashedPassword = "!";
    };
    cobalt = {
      isNormalUser = true;
      uid = 1102;
      group = "cobalt";
      home = "/home/cobalt";
      createHome = false;
      shell = "/bin/bash";
      hashedPassword = "!";
    };
    www-data = {
      isSystemUser = true;
      uid = 33;
      group = "www-data";
      home = "/var/www";
      shell = "/run/current-system/sw/bin/nologin";
      description = "www-data";
    };
    memcache = {
      isSystemUser = true;
      uid = 113;
      group = "memcache";
      home = "/nonexistent";
      shell = "/run/current-system/sw/bin/nologin";
      description = "Memcached";
    };
  };

  environment.shells = [ "/bin/bash" ];

  # ---- Compatibility paths used by tenants and sudo rules -----------------
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /bin/cat - - - - ${coreutils}/bin/cat"
    "L+ /usr/bin/systemctl - - - - /run/current-system/sw/bin/systemctl"
    "L+ /usr/bin/python3 - - - - ${python}/bin/python3"
    "d /usr/local/bin 0755 root root -"
    "d /run/php 0755 www-data www-data -"
    "d /run/wsgi 0755 root root -"
    "d /var/log/web 0750 root adm -"
    "f /var/log/web/amber-access.log 0640 root adm -"
    "f /var/log/web/amber-error.log 0640 root adm -"
    "f /var/log/web/cobalt-access.log 0640 root adm -"
    "f /var/log/web/cobalt-error.log 0640 root adm -"
  ];

  system.activationScripts.nodeSeed = {
    deps = [ "users" ];
    text = lib.concatStrings [
      (seedDir "/home/amber" "amber" "amber" "0755")
      (seedDir "/home/amber/public_html" "amber" "amber" "0755")
      (seedDir "/home/amber/public_html/cgi-bin" "amber" "amber" "0755")
      (seedDir "/home/amber/public_html/wsgi-bin" "amber" "amber" "0755")
      (seedDir "/home/amber/private" "amber" "amber" "0700")
      (seedFile "/home/amber/private/token" "amber" "amber" "0600" "amber-private\n")
      (seedFile "/home/amber/public_html/index.html" "amber" "amber" "0644" "amber workspace\n")
      (seedFile "/home/amber/public_html/cgi-bin/hello.py" "amber" "amber" "0755" ''
        #!/usr/bin/python3
        print("Content-Type: text/plain\n")
        print("hello from amber")
      '')
      (seedDir "/home/cobalt" "cobalt" "cobalt" "0755")
      (seedDir "/home/cobalt/public_html" "cobalt" "cobalt" "0755")
      (seedDir "/home/cobalt/public_html/cgi-bin" "cobalt" "cobalt" "0755")
      (seedDir "/home/cobalt/public_html/wsgi-bin" "cobalt" "cobalt" "0755")
      (seedDir "/home/cobalt/private" "cobalt" "cobalt" "0700")
      (seedFile "/home/cobalt/private/token" "cobalt" "cobalt" "0600" "cobalt-private\n")
      (seedFile "/home/cobalt/public_html/index.html" "cobalt" "cobalt" "0644" "cobalt workspace\n")
      (seedFile "/home/cobalt/public_html/cgi-bin/hello.py" "cobalt" "cobalt" "0755" ''
        #!/usr/bin/python3
        print("Content-Type: text/plain\n")
        print("hello from cobalt")
      '')
      (seedDir "/srv/node" "root" "root" "0755")
      (seedFile "/srv/node/index.html" "root" "root" "0644" "node service\n")
    ];
  };

  # ---- Name resolution --------------------------------------------------
  # The reference node has no host firewall; the forwarded service ports must be reachable.
  networking.firewall.enable = false;

  # The NixOS-generated logrotate check fails at boot for the httpd log rules; the reference has none.
  systemd.services.logrotate-checkconf.enable = false;

  networking.hosts = {
    "127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];
  };

  # ---- SSH --------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
    };
  };

  # ---- sudo -------------------------------------------------------------
  security.sudo.extraConfig = ''
    Defaults use_pty
    Defaults mail_badpass
    %admin ALL=(ALL) ALL
    %sudo ALL=(ALL:ALL) ALL
    amber ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/amber-access.log, /bin/cat /var/log/web/amber-error.log
    cobalt ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/cobalt-access.log, /bin/cat /var/log/web/cobalt-error.log
    cobalt ALL=(root) NOPASSWD: /usr/bin/systemctl restart apache2, /run/current-system/sw/bin/systemctl restart apache2
    amber ALL=(:adm) NOPASSWD: /run/current-system/sw/bin/cat /var/log/web/amber-access.log, /run/current-system/sw/bin/cat /var/log/web/amber-error.log
    cobalt ALL=(:adm) NOPASSWD: /run/current-system/sw/bin/cat /var/log/web/cobalt-access.log, /run/current-system/sw/bin/cat /var/log/web/cobalt-error.log
  '';

  # ---- Apache -----------------------------------------------------------
  services.httpd = {
    enable = true;
    user = "www-data";
    group = "www-data";
    adminAddr = "webmaster@localhost";
    virtualHosts = lib.mkForce { };
    enablePHP = false;
    extraModules = [
      "access_compat"
      "alias"
      "auth_basic"
      "authn_core"
      "authn_file"
      "authz_core"
      "authz_host"
      "authz_user"
      "autoindex"
      "cgid"
      "deflate"
      "dir"
      "env"
      "filter"
      "headers"
      "mime"
      "negotiation"
      "proxy"
      "proxy_fcgi"
      "reqtimeout"
      "rewrite"
      "setenvif"
      "socache_shmcb"
      "ssl"
      "status"
      "userdir"
      { name = "wsgi"; path = "${pkgs.apacheHttpdPackages.mod_wsgi3}/modules/mod_wsgi.so"; }
    ];
    extraConfig = httpdExtra;
  };
  systemd.services.httpd.aliases = [ "apache2.service" ];
  systemd.services.httpd.serviceConfig.ProtectHome = lib.mkForce false;
  # The master must start as root to open root-owned tenant logs; workers drop to www-data.
  systemd.services.httpd.serviceConfig.User = lib.mkForce "root";

  # ---- PHP-FPM ----------------------------------------------------------
  services.phpfpm = {
    phpPackage = php;
    phpOptions = ''
      expose_php = Off
      max_execution_time = 30
      max_input_time = 60
      memory_limit = 128M
      error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
      display_errors = Off
      display_startup_errors = Off
      log_errors = On
      post_max_size = 8M
      upload_max_filesize = 2M
      default_charset = "UTF-8"
      short_open_tag = Off
      allow_url_include = Off
      session.save_handler = files
    '';
    pools = {
      amber = {
        user = "amber";
        group = "amber";
        listen = "/run/php/php-amber-fpm.sock";
        phpEnv = {
          HOME = "/home/amber";
          PATH = "/usr/local/bin:/usr/bin:/bin";
          TMP = "/tmp";
          TMPDIR = "/tmp";
          NODE_LABEL = "amber";
        };
        settings = {
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
          "php_value[post_max_size]" = "2M";
          "php_value[upload_max_filesize]" = "2M";
          "php_admin_value[open_basedir]" = "/home/amber/:/tmp/:/usr/share/php/";
          "php_flag[display_errors]" = "off";
        };
      };
      cobalt = {
        user = "cobalt";
        group = "cobalt";
        listen = "/run/php/php-cobalt-fpm.sock";
        phpEnv = {
          HOME = "/home/cobalt";
          PATH = "/usr/local/bin:/usr/bin:/bin";
          TMP = "/tmp";
          TMPDIR = "/tmp";
          NODE_LABEL = "cobalt";
        };
        settings = {
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
          "php_value[post_max_size]" = "8M";
          "php_value[upload_max_filesize]" = "8M";
          "php_admin_value[open_basedir]" = "/home/cobalt/:/tmp/:/usr/share/php/";
          "php_flag[display_errors]" = "off";
        };
      };
    };
  };
  # Pools must be able to read their tenant's home directory.
  systemd.services.phpfpm-amber.serviceConfig.ProtectHome = lib.mkForce false;
  systemd.services.phpfpm-cobalt.serviceConfig.ProtectHome = lib.mkForce false;

  # ---- MariaDB ----------------------------------------------------------
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "127.0.0.1";
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_general_ci";
    };
    initialScript = mysqlInit;
  };

  # ---- PostgreSQL -------------------------------------------------------
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    extensions = ps: [ ps.postgis ];
    initdbArgs = [ "--encoding=UTF8" "--locale=C.UTF-8" ];
    enableTCPIP = true;
    authentication = lib.mkForce ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    initialScript = pgInit;
  };

  # ---- memcached --------------------------------------------------------
  services.memcached = {
    enable = true;
    user = "memcache";
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    extraOptions = [ "-U" "0" ];
  };

  # ---- Packages on the default PATH -------------------------------------
  environment.systemPackages = [
    php
    python
    pkgs.mariadb
    pkgs.postgresql_14
    pkgs.netcat-openbsd
    pkgs.socat
    pkgs.openssl
  ];
}
