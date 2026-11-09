{ config, lib, pkgs, ... }:
let
  apache = pkgs.apacheHttpd;
  modWsgi = pkgs.apacheHttpdPackages.mod_wsgi3;
  php = pkgs.php;
  pgPackage = pkgs.postgresql_17.withPackages (ps: [ ps.postgis ]);

  tenants = {
    amber = { uid = 1101; gid = 1000; postMax = "2M"; };
    cobalt = { uid = 1102; gid = 1001; postMax = "8M"; };
  };

  txt = name: text: pkgs.writeText name text;

  # --- Apache -------------------------------------------------------------
  loadModules = [
    "unixd" "log_config" "logio" "access_compat" "alias" "auth_basic" "authn_core" "authn_file" "authz_core"
    "authz_host" "authz_user" "autoindex" "cgid" "deflate" "dir" "env" "filter"
    "headers" "mime" "mpm_event" "negotiation" "proxy" "proxy_fcgi" "reqtimeout"
    "rewrite" "setenvif" "socache_shmcb" "ssl" "status" "userdir"
  ];
  loadLines = lib.concatMapStrings (m: "LoadModule ${m}_module ${apache}/modules/mod_${m}.so\n") loadModules;

  vhostFor = u: ''
    WSGIDaemonProcess ${u} user=${u} group=${u} processes=1 threads=4
    <VirtualHost *:443>
        ServerName ${u}.node.test
        ServerAlias ${u}.node.alt.test
        SSLEngine on
        SSLCertificateFile /etc/node/server.crt
        SSLCertificateKeyFile /etc/node/server.key
        DocumentRoot /home/${u}/public_html
        ProxyTimeout 90
        RequestHeader unset Proxy early
        UseCanonicalName Off
        WSGIProcessGroup ${u}
        CustomLog /var/log/web/${u}-access.log combined
        ErrorLog /var/log/web/${u}-error.log
        RewriteEngine on
        RewriteCond /home/${u}/public_html%{REQUEST_FILENAME} -f
        RewriteRule ^/cgi-bin/(.*)$ /~${u}/cgi-bin/$1 [PT,L]
        <FilesMatch ".+\.ph(p|ps|p3|tml)$">
            SetHandler "proxy:unix:/run/php/php-${u}-fpm.sock|fcgi://127.0.0.1"
        </FilesMatch>
    </VirtualHost>
    <VirtualHost *:80>
        ServerName ${u}.node.test
        ServerAlias ${u}.node.alt.test
        RedirectPermanent /.well-known/acme-challenge/ http://acme.node.test/.well-known/acme-challenge/
        RedirectPermanent / https://${u}.node.test/
    </VirtualHost>
    <Directory /home/${u}/public_html>
        AllowOverride AuthConfig FileInfo Indexes
        Options SymLinksIfOwnerMatch Indexes Includes
        Require all granted
    </Directory>
    <Directory /home/${u}/public_html/cgi-bin>
        SetHandler cgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    <Directory /home/${u}/public_html/wsgi-bin>
        SetHandler wsgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
  '';

  nodeSite = ''
    ServerName node.test
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

  apacheConf = txt "apache2.conf" ''
    ServerRoot "${apache}"
    DefaultRuntimeDir /run/apache2
    PidFile /run/apache2/apache2.pid
    Timeout 300
    KeepAlive On
    MaxKeepAliveRequests 100
    KeepAliveTimeout 5
    User www-data
    Group www-data
    HostnameLookups Off
    ErrorLog /var/log/apache2/error.log
    LogLevel warn
    ServerTokens OS
    ServerSignature On
    TraceEnable Off
    ${loadLines}
    LoadModule wsgi_module ${modWsgi}/modules/mod_wsgi.so
    ScriptSock /run/apache2/cgisock
    SSLSessionCache shmcb:/run/apache2/ssl_scache(512000)
    SSLSessionCacheTimeout 300
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    <IfModule mod_mpm_event.c>
        StartServers 2
        MinSpareThreads 25
        MaxSpareThreads 75
        ThreadLimit 64
        ThreadsPerChild 25
        MaxRequestWorkers 150
        MaxConnectionsPerChild 0
    </IfModule>
    <IfModule mod_userdir.c>
        UserDir public_html
        UserDir disabled root
        <Directory /home/*/public_html>
            AllowOverride FileInfo AuthConfig Limit Indexes
            Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
            Require method GET POST OPTIONS
        </Directory>
    </IfModule>
    <IfModule mod_status.c>
        <Location /server-status>
            SetHandler server-status
            Require local
        </Location>
        ExtendedStatus On
    </IfModule>
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript
        AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
        AddOutputFilterByType DEFLATE application/rss+xml application/wasm application/xml
    </IfModule>
    <IfModule mod_dir.c>
        DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm
    </IfModule>
    TypesConfig ${apache}/conf/mime.types
    <Directory />
        Options FollowSymLinks
        AllowOverride None
        Require all denied
    </Directory>
    <Directory /usr/share>
        AllowOverride None
        Require all granted
    </Directory>
    <Directory /var/www/>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    AccessFileName .htaccess
    <FilesMatch "^\.ht">
        Require all denied
    </FilesMatch>
    LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
    LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %O" common
    LogFormat "%{Referer}i -> %U" referer
    LogFormat "%{User-agent}i" agent
    Listen 80
    Listen 443
    CustomLog /var/log/apache2/other_vhosts_access.log vhost_combined
    IncludeOptional /etc/apache2/sites-enabled/*.conf
  '';

  # --- Tenant content (seeded, not user data) -----------------------------
  helloPy = u: txt "${u}-hello.py" ''
    #!/usr/bin/python3
    print("Content-Type: text/plain\n")
    print("hello from ${u}")
  '';
  tenantRules = lib.concatMap (u: [
    "d /home/${u} 0755 ${u} ${u} -"
    "d /home/${u}/private 0700 ${u} ${u} -"
    "d /home/${u}/public_html 0755 ${u} ${u} -"
    "d /home/${u}/public_html/cgi-bin 0755 ${u} ${u} -"
    "d /home/${u}/public_html/wsgi-bin 0755 ${u} ${u} -"
    "C /home/${u}/public_html/index.html 0644 ${u} ${u} - ${txt "${u}-index.html" "${u} workspace\n"}"
    "C /home/${u}/public_html/cgi-bin/hello.py 0755 ${u} ${u} - ${helloPy u}"
    "C /home/${u}/private/token 0600 ${u} ${u} - ${txt "${u}-token" "${u}-private\n"}"
  ]) (lib.attrNames tenants);

  initSql = pkgs.writeText "postgres-init.sql" (''
    CREATE ROLE amber LOGIN CONNECTION LIMIT 20 PASSWORD 'SCRAM-SHA-256$4096:1rJz1zqG8QX/Y9iyLfy+lA==$xiy0NZkFo/LAtz2nXOGKIe2zVKP/vQRkaWaOjY+I4Bs=:erHpSa6MlYgT5C+t+fyUrzYeTASwOPfh/4ctsI3JRbQ=';
    CREATE ROLE cobalt LOGIN CONNECTION LIMIT 40 PASSWORD 'SCRAM-SHA-256$4096:0uFjL0lkmELvx5f9FwpW+w==$qqQzU/nP3uNK/vLoe1X7N6sppcWN8hJ7U8Hi1pYp+Ws=:TFrV6ScYH+rMr+DnKDmtpLofLmo94TnqPL3iJIUyguU=';
    CREATE DATABASE amber OWNER amber;
    CREATE DATABASE cobalt OWNER cobalt;
    \c amber
    CREATE EXTENSION IF NOT EXISTS postgis;
    \c cobalt
    CREATE EXTENSION IF NOT EXISTS postgis;
  '');

  mysqlInit = pkgs.writeText "mysql-init.sql" ''
    CREATE DATABASE IF NOT EXISTS amber CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    CREATE DATABASE IF NOT EXISTS cobalt CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    CREATE USER IF NOT EXISTS 'amber'@'localhost' IDENTIFIED BY PASSWORD '*CE994D3F34F0502BC51156503AF81CDDB63F415E' WITH MAX_USER_CONNECTIONS 20;
    CREATE USER IF NOT EXISTS 'cobalt'@'localhost' IDENTIFIED BY PASSWORD '*4E3F82FE2BB932A394FCFB9A3F056ACE68141483' WITH MAX_USER_CONNECTIONS 40;
    GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
    GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
    FLUSH PRIVILEGES;
  '';
in
{
  networking.hostName = "node17";
  # The reference runs with no host firewall (ufw inactive, iptables ACCEPT).
  networking.firewall.enable = false;
  networking.hosts = {
    "127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];
  };

  i18n.defaultLocale = "C.UTF-8";

  users.groups = {
    dialout.gid = lib.mkForce 20;
    lp.gid = lib.mkForce 7;
    amber.gid = 1000;
    cobalt.gid = 1001;
    tenants.gid = 1002;
    sudo.gid = 27;
    admin.gid = 117;
    www-data.gid = 33;
    memcache.gid = 122;
  };
  users.users = {
    amber = {
      isNormalUser = true;
      uid = 1101;
      group = "amber";
      home = "/home/amber";
      createHome = false;
      extraGroups = [ "tenants" ];
      hashedPassword = "!";
    };
    cobalt = {
      isNormalUser = true;
      uid = 1102;
      group = "cobalt";
      home = "/home/cobalt";
      createHome = false;
      extraGroups = [ "tenants" ];
      hashedPassword = "!";
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

  # Compatibility paths expected by scripts and tenants.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/python3 - - - - ${pkgs.python3}/bin/python3"
    "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "d /var/www 0755 root root -"
    "d /var/www/html 0755 root root -"
    "d /var/log/apache2 0750 root adm -"
    "f /var/log/apache2/error.log 0640 root adm -"
    "f /var/log/apache2/access.log 0640 root adm -"
    "f /var/log/apache2/other_vhosts_access.log 0640 root adm -"
    "d /var/log/web 0750 root adm -"
    "f /var/log/web/amber-access.log 0640 root adm -"
    "f /var/log/web/amber-error.log 0640 root adm -"
    "f /var/log/web/cobalt-access.log 0640 root adm -"
    "f /var/log/web/cobalt-error.log 0640 root adm -"
    "d /run/php 0755 root root -"
    "d /srv/node 0755 root root -"
    "C /srv/node/index.html 0644 root root - ${txt "node-index.html" "node service\n"}"
  ] ++ tenantRules;

  environment.etc = {
    "apache2/apache2.conf".source = apacheConf;
    "apache2/sites-enabled/amber.conf".text = vhostFor "amber";
    "apache2/sites-enabled/cobalt.conf".text = vhostFor "cobalt";
    "apache2/sites-enabled/node.conf".text = nodeSite;
  };

  environment.systemPackages = [ php pgPackage pkgs.mariadb pkgs.python3 pkgs.coreutils ];

  systemd.services.apache2 = {
    description = "The Apache HTTP Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    wants = [ "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${apache}/bin/httpd -f /etc/apache2/apache2.conf -t";
      ExecStart = "${apache}/bin/httpd -f /etc/apache2/apache2.conf -DFOREGROUND";
      ExecReload = "${apache}/bin/httpd -f /etc/apache2/apache2.conf -t && ${apache}/bin/httpd -f /etc/apache2/apache2.conf -k graceful";
      ExecStop = "${apache}/bin/httpd -f /etc/apache2/apache2.conf -k graceful-stop";
      RuntimeDirectory = "apache2";
      Restart = "on-failure";
    };
  };

  services.phpfpm.pools = lib.mapAttrs (u: t: {
    user = u;
    group = u;
    phpPackage = php;
    phpOptions = ''
      expose_php = Off
    '';
    phpEnv = {
      HOME = "/home/${u}";
      PATH = "/usr/local/bin:/usr/bin:/bin";
      TMP = "/tmp";
      TMPDIR = "/tmp";
      NODE_LABEL = u;
    };
    settings = {
      "listen" = "/run/php/php-${u}-fpm.sock";
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
      "php_value[post_max_size]" = t.postMax;
      "php_value[upload_max_filesize]" = t.postMax;
      "php_admin_value[open_basedir]" = "/home/${u}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
  }) tenants;

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

  services.postgresql = {
    enable = true;
    package = pgPackage;
    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
      password_encryption = "scram-sha-256";
      timezone = "Etc/UTC";
    };
    authentication = lib.mkForce ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    initialScript = initSql;
  };

  services.memcached = {
    enable = true;
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    user = "memcache";
    extraOptions = [ "-U" "0" ];
  };

  security.sudo.extraConfig = ''
    Defaults	env_reset
    Defaults	mail_badpass
    root	ALL=(ALL:ALL) ALL
    %admin ALL=(ALL) ALL
    %sudo	ALL=(ALL:ALL) ALL
    amber ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/amber-access.log, /bin/cat /var/log/web/amber-error.log
    cobalt ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/cobalt-access.log, /bin/cat /var/log/web/cobalt-error.log
  '';

  services.openssh = {
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
  };

  system.stateVersion = "26.05";
}
