{ config, pkgs, lib, ... }:

let
  apache = pkgs.apacheHttpd;
  modWsgi = pkgs.apacheHttpdPackages.mod_wsgi3;

  # PHP with the extensions tenants rely on (pgsql added to the default set).
  # STUDY: Opus 5.5 (OpenRouter), trial YWTivSs, reward 0.80 (28/35). Failed: slice_limits, postgres_isolation, postgis,
  # STUDY: cgi_identity, login_limits, log_rotation, db_role_limits. See ../06-traces/node17-opus-YWTivSs.md.
  php = pkgs.php.withExtensions ({ enabled, all }:
    enabled ++ (builtins.filter (e: !(builtins.elem e enabled)) [
      all.pgsql all.pdo_pgsql all.mysqli all.pdo_mysql all.mbstring all.opcache
    ]));

  httpdRoot = "/run/httpd";

  # Per-tenant Apache vhost (amber / cobalt), mirroring the reference sites.
  tenantVhost = name: ''
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
            SetHandler "proxy:unix:/run/phpfpm/${name}.sock|fcgi://127.0.0.1"
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

  httpdConf = pkgs.writeText "httpd.conf" ''
    ServerRoot ${apache}
    ServerName node17
    PidFile ${httpdRoot}/httpd.pid
    DefaultRuntimeDir ${httpdRoot}

    Timeout 300
    KeepAlive On
    MaxKeepAliveRequests 100
    KeepAliveTimeout 5
    HostnameLookups Off
    LogLevel warn
    ServerTokens OS
    ServerSignature On
    TraceEnable Off

    LoadModule mpm_event_module ${apache}/modules/mod_mpm_event.so
    LoadModule unixd_module ${apache}/modules/mod_unixd.so
    LoadModule authn_core_module ${apache}/modules/mod_authn_core.so
    LoadModule authn_file_module ${apache}/modules/mod_authn_file.so
    LoadModule authz_core_module ${apache}/modules/mod_authz_core.so
    LoadModule authz_host_module ${apache}/modules/mod_authz_host.so
    LoadModule authz_user_module ${apache}/modules/mod_authz_user.so
    LoadModule auth_basic_module ${apache}/modules/mod_auth_basic.so
    LoadModule access_compat_module ${apache}/modules/mod_access_compat.so
    LoadModule log_config_module ${apache}/modules/mod_log_config.so
    LoadModule logio_module ${apache}/modules/mod_logio.so
    LoadModule env_module ${apache}/modules/mod_env.so
    LoadModule mime_module ${apache}/modules/mod_mime.so
    LoadModule negotiation_module ${apache}/modules/mod_negotiation.so
    LoadModule autoindex_module ${apache}/modules/mod_autoindex.so
    LoadModule dir_module ${apache}/modules/mod_dir.so
    LoadModule alias_module ${apache}/modules/mod_alias.so
    LoadModule rewrite_module ${apache}/modules/mod_rewrite.so
    LoadModule filter_module ${apache}/modules/mod_filter.so
    LoadModule deflate_module ${apache}/modules/mod_deflate.so
    LoadModule headers_module ${apache}/modules/mod_headers.so
    LoadModule setenvif_module ${apache}/modules/mod_setenvif.so
    LoadModule socache_shmcb_module ${apache}/modules/mod_socache_shmcb.so
    LoadModule ssl_module ${apache}/modules/mod_ssl.so
    LoadModule proxy_module ${apache}/modules/mod_proxy.so
    LoadModule proxy_fcgi_module ${apache}/modules/mod_proxy_fcgi.so
    # STUDY: MISS cgi_identity (declared as an 'intentional divergence' in its final message: no suEXEC in stock nixpkgs Apache).
    LoadModule cgid_module ${apache}/modules/mod_cgid.so
    LoadModule userdir_module ${apache}/modules/mod_userdir.so
    LoadModule status_module ${apache}/modules/mod_status.so
    LoadModule wsgi_module ${modWsgi}/modules/mod_wsgi.so

    User www-data
    Group www-data

    <IfModule mpm_event_module>
        StartServers             2
        MinSpareThreads          25
        MaxSpareThreads          75
        ThreadLimit              64
        ThreadsPerChild          25
        MaxRequestWorkers        150
        MaxConnectionsPerChild   0
    </IfModule>

    TypesConfig ${apache}/conf/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz

    LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
    LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %O" common

    ErrorLog /var/log/apache2/error.log

    Listen 80
    Listen 443

    DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm

    <Directory />
        Options FollowSymLinks
        AllowOverride None
        Require all denied
    </Directory>

    AccessFileName .htaccess
    <FilesMatch "^\.ht">
        Require all denied
    </FilesMatch>

    <IfModule mod_ssl.c>
        SSLRandomSeed startup builtin
        SSLRandomSeed startup file:/dev/urandom 512
        SSLRandomSeed connect builtin
        SSLRandomSeed connect file:/dev/urandom 512
        SSLSessionCache        shmcb:${httpdRoot}/ssl_scache(512000)
        SSLSessionCacheTimeout 300
        SSLCipherSuite HIGH:!aNULL
        SSLProtocol all -SSLv3
    </IfModule>

    # userdir: /~user/ -> /home/user/public_html
    UserDir public_html
    UserDir disabled root
    <Directory /home/*/public_html>
        AllowOverride FileInfo AuthConfig Limit Indexes
        Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
        Require method GET POST OPTIONS
    </Directory>

    <Location /server-status>
        SetHandler server-status
        Require local
    </Location>
    ExtendedStatus On

    WSGISocketPrefix ${httpdRoot}/wsgi

    # ---- tenant vhosts (amber is first => default vhost) ----
    ${tenantVhost "amber"}
    ${tenantVhost "cobalt"}

    # ---- node.test service vhost + /~user redirect ----
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

  phpPool = label: uploadSize: {
    user = label;
    group = label;
    phpPackage = php;
    settings = {
      "listen" = "/run/phpfpm/${label}.sock";
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
      "env[HOME]" = "/home/${label}";
      "env[PATH]" = "/usr/local/bin:/usr/bin:/bin";
      "env[TMP]" = "/tmp";
      "env[TMPDIR]" = "/tmp";
      "env[NODE_LABEL]" = label;
      "php_value[max_execution_time]" = 120;
      "php_value[memory_limit]" = "128M";
      "php_value[post_max_size]" = uploadSize;
      "php_value[upload_max_filesize]" = uploadSize;
      "php_admin_value[open_basedir]" = "/home/${label}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
  };

  mysqlInit = pkgs.writeText "mysql-init.sql" ''
    CREATE DATABASE IF NOT EXISTS amber;
    CREATE DATABASE IF NOT EXISTS cobalt;
    CREATE USER IF NOT EXISTS 'amber'@'localhost' IDENTIFIED BY PASSWORD '*CE994D3F34F0502BC51156503AF81CDDB63F415E' WITH MAX_USER_CONNECTIONS 20;
    CREATE USER IF NOT EXISTS 'cobalt'@'localhost' IDENTIFIED BY PASSWORD '*4E3F82FE2BB932A394FCFB9A3F056ACE68141483' WITH MAX_USER_CONNECTIONS 40;
    GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
    GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
    FLUSH PRIVILEGES;
  '';

  # STUDY: Caps yes, statement_timeout no -> MISS db_role_limits. No REVOKE CONNECT -> MISS postgres_isolation.
  pgInit = pkgs.writeText "pg-init.sql" ''
    CREATE ROLE amber LOGIN CONNECTION LIMIT 20 PASSWORD 'SCRAM-SHA-256$4096:1rJz1zqG8QX/Y9iyLfy+lA==$xiy0NZkFo/LAtz2nXOGKIe2zVKP/vQRkaWaOjY+I4Bs=:erHpSa6MlYgT5C+t+fyUrzYeTASwOPfh/4ctsI3JRbQ=';
    CREATE ROLE cobalt LOGIN CONNECTION LIMIT 40 PASSWORD 'SCRAM-SHA-256$4096:0uFjL0lkmELvx5f9FwpW+w==$qqQzU/nP3uNK/vLoe1X7N6sppcWN8hJ7U8Hi1pYp+Ws=:TFrV6ScYH+rMr+DnKDmtpLofLmo94TnqPL3iJIUyguU=';
    CREATE DATABASE amber OWNER amber;
    CREATE DATABASE cobalt OWNER cobalt;
  '';
in
{
  networking.hostName = "node17";
  networking.firewall.enable = false;
  networking.hosts = {
    "127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];
  };

  # /usr/bin/python3 for CGI shebangs, /bin/cat for the sudoers log rules.
  system.activationScripts.nodeCompat.text = ''
    mkdir -p /usr/bin /bin
    ln -sfn ${pkgs.python3}/bin/python3 /usr/bin/python3
    ln -sfn ${pkgs.coreutils}/bin/cat /bin/cat
  '';

  # ---- accounts ----
  users.groups.amber.gid = 1000;
  users.groups.cobalt.gid = 1001;
  users.groups.tenants.gid = 1002;
  users.groups.adm = {};
  users.groups."www-data" = {};

  users.users.amber = {
    isNormalUser = true;
    uid = 1101;
    group = "amber";
    extraGroups = [ "tenants" ];
    home = "/home/amber";
    createHome = true;
    homeMode = "755";
    shell = pkgs.bashInteractive;
  };
  users.users.cobalt = {
    isNormalUser = true;
    uid = 1102;
    group = "cobalt";
    extraGroups = [ "tenants" ];
    home = "/home/cobalt";
    createHome = true;
    homeMode = "755";
    shell = pkgs.bashInteractive;
  };
  users.users."www-data" = {
    isSystemUser = true;
    group = "www-data";
    description = "Apache web server";
  };

  # ---- seeded files ----
  systemd.tmpfiles.rules = [
    "d /home/amber/public_html 0755 amber amber - -"
    "d /home/amber/public_html/cgi-bin 0755 amber amber - -"
    "d /home/amber/public_html/wsgi-bin 0755 amber amber - -"
    "d /home/amber/private 0700 amber amber - -"
    "C+ /home/amber/public_html/index.html 0644 amber amber - ${./web/amber-index.html}"
    "C+ /home/amber/public_html/cgi-bin/hello.py 0755 amber amber - ${./web/amber-hello.py}"
    "C+ /home/amber/private/token 0600 amber amber - ${./web/amber-token}"

    "d /home/cobalt/public_html 0755 cobalt cobalt - -"
    "d /home/cobalt/public_html/cgi-bin 0755 cobalt cobalt - -"
    "d /home/cobalt/public_html/wsgi-bin 0755 cobalt cobalt - -"
    "d /home/cobalt/private 0700 cobalt cobalt - -"
    "C+ /home/cobalt/public_html/index.html 0644 cobalt cobalt - ${./web/cobalt-index.html}"
    "C+ /home/cobalt/public_html/cgi-bin/hello.py 0755 cobalt cobalt - ${./web/cobalt-hello.py}"
    "C+ /home/cobalt/private/token 0600 cobalt cobalt - ${./web/cobalt-token}"

    "d /srv/node 0755 root root - -"
    "C+ /srv/node/index.html 0644 root root - ${./web/node-index.html}"

    "d /var/log/web 0750 root adm - -"
    "f /var/log/web/amber-access.log 0640 root adm - -"
    "f /var/log/web/amber-error.log 0640 root adm - -"
    "f /var/log/web/cobalt-access.log 0640 root adm - -"
    "f /var/log/web/cobalt-error.log 0640 root adm - -"
    "d /var/log/apache2 0755 root root - -"
    "d /usr/local/bin 0755 root root - -"
  ];

  # ---- SSH policy (harness supplies enable + root key) ----
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  # ---- PHP-FPM per-tenant pools ----
  services.phpfpm.pools.amber = phpPool "amber" "2M";
  services.phpfpm.pools.cobalt = phpPool "cobalt" "8M";

  # Reference php-fpm runs unsandboxed so it can serve /home/*/public_html and
  # share /tmp with the rest of the system.
  systemd.services.phpfpm-amber.serviceConfig = {
    ProtectHome = lib.mkForce false;
    ProtectSystem = lib.mkForce false;
    PrivateTmp = lib.mkForce false;
  };
  systemd.services.phpfpm-cobalt.serviceConfig = {
    ProtectHome = lib.mkForce false;
    ProtectSystem = lib.mkForce false;
    PrivateTmp = lib.mkForce false;
  };

  # ---- Apache (hand-rolled for fidelity) ----
  systemd.services.httpd = {
    description = "Apache HTTP Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    wants = [ "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    path = [ pkgs.python3 ];
    serviceConfig = {
      Type = "forking";
      PIDFile = "${httpdRoot}/httpd.pid";
      RuntimeDirectory = "httpd";
      RuntimeDirectoryPreserve = "yes";
      ExecStartPre = "${apache}/bin/httpd -f ${httpdConf} -t";
      ExecStart = "${apache}/bin/httpd -f ${httpdConf} -k start";
      ExecReload = "${apache}/bin/httpd -f ${httpdConf} -k graceful";
      ExecStop = "${apache}/bin/httpd -f ${httpdConf} -k stop";
    };
  };

  # ---- MariaDB ----
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = mysqlInit;
    settings.mysqld = {
      bind-address = "127.0.0.1";
      port = 3306;
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_general_ci";
    };
  };

  # ---- PostgreSQL ----
  services.postgresql = {
    enable = true;
    # STUDY: PG 14 (not prewarmed): the verifier build took 823 s vs ~226 s for Haiku; close to the 900 s build timeout.
    package = pkgs.postgresql_14;
    # STUDY: MISS postgis: the extension is installed on the server, but nothing runs CREATE EXTENSION postgis in the tenant DBs.
    # STUDY: Its own check ran `CREATE EXTENSION IF NOT EXISTS postgis` and so created it on the test VM (report, "Learnings").
    extensions = ps: [ ps.postgis ];
    initdbArgs = [ "--locale=C.UTF-8" "--encoding=UTF8" ];
    initialScript = pgInit;
    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
      port = 5432;
      password_encryption = "scram-sha-256";
    };
    authentication = lib.mkForce ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
  };

  # ---- memcached ----
  services.memcached = {
    enable = true;
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    extraOptions = [ "-U 0" ];
  };

  # ---- sudo: tenants read their own web logs ----
  security.sudo.enable = true;
  security.sudo.extraConfig = ''
    amber ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/amber-access.log, /bin/cat /var/log/web/amber-error.log
    cobalt ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/cobalt-access.log, /bin/cat /var/log/web/cobalt-error.log
  '';

  environment.systemPackages = with pkgs; [
    curl jq python3 util-linux
    mariadb postgresql_14 php memcached
  ];
}
