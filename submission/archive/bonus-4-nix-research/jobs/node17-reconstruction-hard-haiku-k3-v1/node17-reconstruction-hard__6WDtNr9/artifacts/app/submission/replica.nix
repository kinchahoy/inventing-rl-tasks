{ config, lib, pkgs, ... }:

let
  apache = pkgs.apacheHttpd;
  mod_wsgi = pkgs.apacheHttpdPackages.mod_wsgi3;

  php = pkgs.php.withExtensions ({ all, ... }: with all; [
    mysqli
    pdo_mysql
    pgsql
    pdo_pgsql
    mbstring
    opcache
  ]);

  phpIni = pkgs.writeText "php.ini" ''
    [PHP]
    engine = On
    short_open_tag = Off
    precision = 14
    output_buffering = 4096
    zlib.output_compression = Off
    implicit_flush = Off
    serialize_precision = -1
    zend.enable_gc = On
    zend.exception_ignore_args = On
    zend.exception_string_param_max_len = 0
    expose_php = Off
    max_execution_time = 30
    max_input_time = 60
    memory_limit = 128M
    error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
    display_errors = Off
    display_startup_errors = Off
    log_errors = On
    report_memleaks = On
    variables_order = "GPCS"
    request_order = "GP"
    register_argc_argv = Off
    auto_globals_jit = On
    post_max_size = 8M
    default_mimetype = "text/html"
    default_charset = "UTF-8"
    enable_dl = Off
    file_uploads = On
    upload_max_filesize = 2M
    max_file_uploads = 20
    allow_url_fopen = On
    allow_url_include = Off
    default_socket_timeout = 60

    [Session]
    session.save_handler = files
    session.use_strict_mode = 0
    session.use_cookies = 1
    session.use_only_cookies = 1
    session.name = PHPSESSID
    session.auto_start = 0
    session.cookie_lifetime = 0
    session.cookie_path = /
    session.serialize_handler = php
    session.gc_probability = 0
    session.gc_divisor = 1000
    session.gc_maxlifetime = 1440
    session.cache_limiter = nocache
    session.cache_expire = 180
    session.use_trans_sid = 0
    session.sid_length = 26
    session.sid_bits_per_character = 5

    [mail function]
    SMTP = localhost
    smtp_port = 25
    mail.add_x_header = Off

    [MySQLi]
    mysqli.default_port = 3306
    mysqli.default_socket = /run/mysqld/mysqld.sock
    mysqli.reconnect = Off

    [PostgreSQL]
    pgsql.allow_persistent = On
    pgsql.auto_reset_persistent = Off
    pgsql.max_persistent = -1
    pgsql.max_links = -1
    pgsql.ignore_notice = 0
    pgsql.log_notice = 0

    [Pdo_mysql]
    pdo_mysql.default_socket = /run/mysqld/mysqld.sock

    [mysqlnd]
    mysqlnd.collect_statistics = On
    mysqlnd.collect_memory_statistics = Off
  '';

  poolConf = name: uid: ''
    [${name}]
    user = ${name}
    group = ${name}
    listen = /run/php/php-${name}-fpm.sock
    listen.owner = www-data
    listen.group = www-data
    listen.mode = 0660
    pm = dynamic
    pm.max_children = 10
    pm.start_servers = 2
    pm.min_spare_servers = 1
    pm.max_spare_servers = 3
    pm.max_requests = 10000
    request_terminate_timeout = 180
    clear_env = yes
    env[HOME] = /home/${name}
    env[PATH] = /run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin
    env[TMP] = /tmp
    env[TMPDIR] = /tmp
    env[NODE_LABEL] = ${name}
    php_value[max_execution_time] = 120
    php_value[memory_limit] = 128M
    php_value[post_max_size] = ${if name == "amber" then "2M" else "8M"}
    php_value[upload_max_filesize] = ${if name == "amber" then "2M" else "8M"}
    php_admin_value[open_basedir] = /home/${name}/:/tmp/:/usr/share/php/
    php_flag[display_errors] = off
  '';

  fpmConf = pkgs.writeText "php8.1-fpm.conf" ''
    [global]
    pid = /run/php/php8.1-fpm.pid
    error_log = /var/log/php8.1-fpm.log
    include=${pkgs.writeText "pool-amber.conf" (poolConf "amber" 1101)}
    include=${pkgs.writeText "pool-cobalt.conf" (poolConf "cobalt" 1102)}
  '';

  httpdConf = ''
    ServerRoot "/etc/apache2"
    ServerName node.test
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

    LoadModule unixd_module ${apache}/modules/mod_unixd.so
    LoadModule access_compat_module ${apache}/modules/mod_access_compat.so
    LoadModule alias_module ${apache}/modules/mod_alias.so
    LoadModule auth_basic_module ${apache}/modules/mod_auth_basic.so
    LoadModule authn_core_module ${apache}/modules/mod_authn_core.so
    LoadModule authn_file_module ${apache}/modules/mod_authn_file.so
    LoadModule authz_core_module ${apache}/modules/mod_authz_core.so
    LoadModule authz_host_module ${apache}/modules/mod_authz_host.so
    LoadModule authz_user_module ${apache}/modules/mod_authz_user.so
    LoadModule autoindex_module ${apache}/modules/mod_autoindex.so
    LoadModule cgid_module ${apache}/modules/mod_cgid.so
    LoadModule deflate_module ${apache}/modules/mod_deflate.so
    LoadModule dir_module ${apache}/modules/mod_dir.so
    LoadModule env_module ${apache}/modules/mod_env.so
    LoadModule filter_module ${apache}/modules/mod_filter.so
    LoadModule headers_module ${apache}/modules/mod_headers.so
    LoadModule mime_module ${apache}/modules/mod_mime.so
    LoadModule log_config_module ${apache}/modules/mod_log_config.so
    LoadModule mpm_event_module ${apache}/modules/mod_mpm_event.so
    LoadModule negotiation_module ${apache}/modules/mod_negotiation.so
    LoadModule proxy_module ${apache}/modules/mod_proxy.so
    LoadModule proxy_fcgi_module ${apache}/modules/mod_proxy_fcgi.so
    LoadModule reqtimeout_module ${apache}/modules/mod_reqtimeout.so
    LoadModule rewrite_module ${apache}/modules/mod_rewrite.so
    LoadModule setenvif_module ${apache}/modules/mod_setenvif.so
    LoadModule socache_shmcb_module ${apache}/modules/mod_socache_shmcb.so
    LoadModule ssl_module ${apache}/modules/mod_ssl.so
    LoadModule status_module ${apache}/modules/mod_status.so
    LoadModule userdir_module ${apache}/modules/mod_userdir.so
    LoadModule wsgi_module ${mod_wsgi}/modules/mod_wsgi.so

    <IfModule mpm_event_module>
        StartServers             2
        MinSpareThreads          25
        MaxSpareThreads          75
        ThreadLimit              64
        ThreadsPerChild          25
        MaxRequestWorkers        150
        MaxConnectionsPerChild   0
    </IfModule>

    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json image/svg+xml
    </IfModule>

    <IfModule mod_status.c>
        <Location /server-status>
            SetHandler server-status
            Require local
        </Location>
        ExtendedStatus On
        <IfModule mod_proxy.c>
            ProxyStatus On
        </IfModule>
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

    <IfModule mod_dir.c>
        DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm
    </IfModule>

    Listen 80
    Listen 443

    <IfModule ssl_module>
        SSLRandomSeed startup builtin
        SSLRandomSeed connect builtin
        SSLPassPhraseDialog builtin
        SSLSessionCache shmcb:/run/apache2/ssl_scache(512000)
        SSLSessionCacheTimeout 300
        SSLCipherSuite HIGH:!aNULL
        SSLProtocol all -SSLv3
    </IfModule>

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

    TypesConfig ${apache}/conf/mime.types
    AddType application/x-x509-ca-cert .crt
    AddType application/x-pkcs7-crl .crl

    ServerTokens OS
    ServerSignature On
    TraceEnable Off

    LogFormat "%v:%p %h %l %u %t \"%r\" %>s %B \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
    LogFormat "%h %l %u %t \"%r\" %>s %B \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %B" common
    LogFormat "%{Referer}i -> %U" referer
    LogFormat "%{User-agent}i" agent

    CustomLog /var/log/apache2/other_vhosts_access.log vhost_combined

    WSGISocketPrefix /run/apache2/wsgi
    WSGIDaemonProcess amber user=amber group=amber processes=1 threads=4
    WSGIDaemonProcess cobalt user=cobalt group=cobalt processes=1 threads=4

    <VirtualHost *:443>
        ServerName amber.node.test
        ServerAlias amber.node.alt.test
        SSLEngine on
        SSLCertificateFile /etc/node/server.crt
        SSLCertificateKeyFile /etc/node/server.key
        DocumentRoot /home/amber/public_html
        ProxyTimeout 90
        RequestHeader unset Proxy early
        UseCanonicalName Off
        WSGIProcessGroup amber
        CustomLog /var/log/web/amber-access.log combined
        ErrorLog /var/log/web/amber-error.log
        RewriteEngine on
        RewriteCond /home/amber/public_html%{REQUEST_FILENAME} -f
        RewriteRule ^/cgi-bin/(.*)$ /~amber/cgi-bin/$1 [PT,L]
        <FilesMatch ".+\.ph(p|ps|p3|tml)$">
            SetHandler "proxy:unix:/run/php/php-amber-fpm.sock|fcgi://127.0.0.1"
        </FilesMatch>
    </VirtualHost>
    <VirtualHost *:80>
        ServerName amber.node.test
        ServerAlias amber.node.alt.test
        RedirectPermanent /.well-known/acme-challenge/ http://acme.node.test/.well-known/acme-challenge/
        RedirectPermanent / https://amber.node.test/
    </VirtualHost>
    <Directory /home/amber/public_html>
        AllowOverride AuthConfig FileInfo Indexes
        Options SymLinksIfOwnerMatch Indexes Includes
        Require all granted
    </Directory>
    <Directory /home/amber/public_html/cgi-bin>
        SetHandler cgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    <Directory /home/amber/public_html/wsgi-bin>
        SetHandler wsgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>

    <VirtualHost *:443>
        ServerName cobalt.node.test
        ServerAlias cobalt.node.alt.test
        SSLEngine on
        SSLCertificateFile /etc/node/server.crt
        SSLCertificateKeyFile /etc/node/server.key
        DocumentRoot /home/cobalt/public_html
        ProxyTimeout 90
        RequestHeader unset Proxy early
        UseCanonicalName Off
        WSGIProcessGroup cobalt
        CustomLog /var/log/web/cobalt-access.log combined
        ErrorLog /var/log/web/cobalt-error.log
        RewriteEngine on
        RewriteCond /home/cobalt/public_html%{REQUEST_FILENAME} -f
        RewriteRule ^/cgi-bin/(.*)$ /~cobalt/cgi-bin/$1 [PT,L]
        <FilesMatch ".+\.ph(p|ps|p3|tml)$">
            SetHandler "proxy:unix:/run/php/php-cobalt-fpm.sock|fcgi://127.0.0.1"
        </FilesMatch>
    </VirtualHost>
    <VirtualHost *:80>
        ServerName cobalt.node.test
        ServerAlias cobalt.node.alt.test
        RedirectPermanent /.well-known/acme-challenge/ http://acme.node.test/.well-known/acme-challenge/
        RedirectPermanent / https://cobalt.node.test/
    </VirtualHost>
    <Directory /home/cobalt/public_html>
        AllowOverride AuthConfig FileInfo Indexes
        Options SymLinksIfOwnerMatch Indexes Includes
        Require all granted
    </Directory>
    <Directory /home/cobalt/public_html/cgi-bin>
        SetHandler cgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    <Directory /home/cobalt/public_html/wsgi-bin>
        SetHandler wsgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>

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
in
{
  imports = [ ];

  networking.hostName = "node17";
  networking.hosts."127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];
  networking.firewall.enable = false;
  i18n.defaultLocale = "C.UTF-8";
  time.timeZone = "Etc/UTC";

  system.stateVersion = "26.05";

  # ---- SSH: root key login only (harness supplies the key), no passwords ----
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  # ---- Accounts and groups ----
  users.groups = {
    amber = { gid = 1000; };
    cobalt = { gid = 1001; };
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
      hashedPassword = "!";
      description = "";
    };
    cobalt = {
      uid = 1102;
      group = "cobalt";
      isNormalUser = true;
      home = "/home/cobalt";
      homeMode = "755";
      hashedPassword = "!";
      description = "";
    };
    www-data = {
      uid = 33;
      group = "www-data";
      isSystemUser = true;
      home = "/var/www";
      createHome = false;
      shell = "/run/current-system/sw/bin/nologin";
    };
    memcache = {
      uid = 113;
      group = "memcache";
      isSystemUser = true;
      home = "/nonexistent";
      createHome = false;
      shell = "/run/current-system/sw/bin/nologin";
    };
  };

  security.sudo.extraConfig = ''
    amber ALL=(:adm) NOPASSWD: /run/current-system/sw/bin/cat /var/log/web/amber-access.log, /run/current-system/sw/bin/cat /var/log/web/amber-error.log
    cobalt ALL=(:adm) NOPASSWD: /run/current-system/sw/bin/cat /var/log/web/cobalt-access.log, /run/current-system/sw/bin/cat /var/log/web/cobalt-error.log
    cobalt ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl restart apache2
  '';

  # ---- Log and runtime directories ----
  systemd.tmpfiles.rules = [
    "d /var/log/web 0750 root adm -"
    "f /var/log/web/amber-access.log 0640 root adm -"
    "f /var/log/web/amber-error.log 0640 root adm -"
    "f /var/log/web/cobalt-access.log 0640 root adm -"
    "f /var/log/web/cobalt-error.log 0640 root adm -"
    "d /var/log/apache2 0750 root adm -"
    "L+ /usr/bin/python3 - - - - ${pkgs.python3}/bin/python3"
    "L+ /usr/bin/perl - - - - ${pkgs.perl}/bin/perl"
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];

  # ---- Tenant files and seeded data (created only if absent) ----
  system.activationScripts.tenantSeed = {
    deps = [ "users" ];
    text = ''
      seed() { # path mode owner group content(printf %b escapes)
        if [ ! -e "$1" ]; then
          printf '%b' "$5" > "$1"
          chmod "$2" "$1"
          chown "$3:$4" "$1"
        fi
      }
      for u in amber cobalt; do
        install -d -m 0755 -o "$u" -g "$u" /home/$u/public_html /home/$u/public_html/cgi-bin /home/$u/public_html/wsgi-bin
        install -d -m 0700 -o "$u" -g "$u" /home/$u/private
      done
      seed /home/amber/public_html/index.html 0644 amber amber 'amber workspace\n'
      seed /home/cobalt/public_html/index.html 0644 cobalt cobalt 'cobalt workspace\n'
      seed /home/amber/private/token 0600 amber amber 'amber-private\n'
      seed /home/cobalt/private/token 0600 cobalt cobalt 'cobalt-private\n'
      for u in amber cobalt; do
        if [ ! -e /home/$u/public_html/cgi-bin/hello.py ]; then
          cat > /home/$u/public_html/cgi-bin/hello.py <<EOF
#!/usr/bin/python3
print("Content-Type: text/plain\n")
print("hello from $u")
EOF
          chmod 0755 /home/$u/public_html/cgi-bin/hello.py
          chown "$u:$u" /home/$u/public_html/cgi-bin/hello.py
        fi
      done
      install -d -m 0755 /srv/node
      seed /srv/node/index.html 0644 root root 'node service\n'
    '';
  };

  # PostgreSQL TLS uses the node certificate; the key is copied to a postgres-readable runtime path.
  system.activationScripts.postgresTls = {
    deps = [ "users" ];
    text = ''
      install -d -m 0700 -o postgres -g postgres /run/postgresql-tls
      install -m 0644 -o postgres -g postgres /etc/node/server.crt /run/postgresql-tls/server.crt
      install -m 0600 -o postgres -g postgres /etc/node/server.key /run/postgresql-tls/server.key
    '';
  };

  # ---- Apache: apache2 unit, config at /etc/apache2/httpd.conf ----
  environment.etc."apache2/httpd.conf".text = httpdConf;

  systemd.services.apache2 = {
    description = "The Apache HTTP Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "php8.1-fpm.service" ];
    wants = [ "php8.1-fpm.service" ];
    restartTriggers = [ config.environment.etc."apache2/httpd.conf".source ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${apache}/bin/httpd -f /etc/apache2/httpd.conf -DFOREGROUND";
      ExecReload = "${apache}/bin/httpd -f /etc/apache2/httpd.conf -k graceful";
      ExecStop = "${apache}/bin/httpd -f /etc/apache2/httpd.conf -k graceful-stop";
      KillMode = "mixed";
      KillSignal = "SIGWINCH";
      RuntimeDirectory = "apache2";
      Restart = "on-failure";
    };
  };

  # ---- PHP-FPM: per-tenant pools ----
  systemd.services."php8.1-fpm" = {
    description = "The PHP 8.1 FastCGI Process Manager";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    restartTriggers = [ fpmConf phpIni ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${php}/bin/php-fpm -y ${fpmConf} -c ${phpIni} -F";
      ExecReload = "${pkgs.coreutils}/bin/kill -USR2 $MAINPID";
      RuntimeDirectory = "php";
      Restart = "on-failure";
    };
  };

  # ---- MariaDB ----
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "amber" "cobalt" ];
    settings.mysqld.bind-address = "127.0.0.1";
    initialScript = pkgs.writeText "mariadb-init.sql" ''
      DROP DATABASE IF EXISTS test;
      DELETE FROM mysql.db WHERE Db LIKE 'test%';
      DELETE FROM mysql.global_priv WHERE LENGTH(User) = 0;
      CREATE USER IF NOT EXISTS 'amber'@'localhost' IDENTIFIED BY PASSWORD '*CE994D3F34F0502BC51156503AF81CDDB63F415E' WITH MAX_USER_CONNECTIONS 20;
      GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
      CREATE USER IF NOT EXISTS 'cobalt'@'localhost' IDENTIFIED BY PASSWORD '*4E3F82FE2BB932A394FCFB9A3F056ACE68141483' WITH MAX_USER_CONNECTIONS 40;
      GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
    '';
  };

  # ---- PostgreSQL 14 with PostGIS ----
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    extensions = ps: [ ps.postgis ];
    settings = {
      listen_addresses = "localhost";
      ssl = true;
      ssl_cert_file = "/run/postgresql-tls/server.crt";
      ssl_key_file = "/run/postgresql-tls/server.key";
    };
    authentication = lib.mkOverride 10 ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    initialScript = pkgs.writeText "postgres-init.sql" ''
      CREATE ROLE amber LOGIN CONNECTION LIMIT 20 PASSWORD 'SCRAM-SHA-256$4096:1rJz1zqG8QX/Y9iyLfy+lA==$xiy0NZkFo/LAtz2nXOGKIe2zVKP/vQRkaWaOjY+I4Bs=:erHpSa6MlYgT5C+t+fyUrzYeTASwOPfh/4ctsI3JRbQ=';
      CREATE ROLE cobalt LOGIN CONNECTION LIMIT 40 PASSWORD 'SCRAM-SHA-256$4096:0uFjL0lkmELvx5f9FwpW+w==$qqQzU/nP3uNK/vLoe1X7N6sppcWN8hJ7U8Hi1pYp+Ws=:TFrV6ScYH+rMr+DnKDmtpLofLmo94TnqPL3iJIUyguU=';
      CREATE DATABASE amber OWNER amber;
      CREATE DATABASE cobalt OWNER cobalt;
      \c amber
      CREATE EXTENSION IF NOT EXISTS postgis;
      \c cobalt
      CREATE EXTENSION IF NOT EXISTS postgis;
    '';
  };

  # ---- Memcached ----
  systemd.services.memcached = {
    description = "memcached daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.memcached}/bin/memcached -m 32 -p 11211 -u memcache -l 127.0.0.1 -U 0";
      StandardOutput = "append:/var/log/memcached.log";
      StandardError = "inherit";
      Restart = "on-failure";
    };
  };

  environment.systemPackages = with pkgs; [
    php
    mariadb
    postgresql_14
    python3
    perl
    curl
    jq
    git
    rsync
    wget
    vim
  ];
}
