{ config, lib, pkgs, ... }:

# Multi-tenant web node "node17": Apache (TLS vhosts per tenant, UserDir,
# per-tenant CGI and WSGI running as the tenant), per-tenant PHP-FPM pools,
# MariaDB and PostgreSQL/PostGIS databases, memcached, sudo log access.
#
# Supporting seed files live in ./files and are copied into place only when
# missing, so data written later by tenants is never overwritten.

let
  fileDir = ./files;

  apache = pkgs.apacheHttpd;
  mod_wsgi = pkgs.apacheHttpdPackages.mod_wsgi3;

  phpPkg = pkgs.php;

  pgPackage = pkgs.postgresql_17;

  # Tenant layout: uid/gid as provisioned on the reference node.
  tenants = {
    amber = { uid = 1101; gid = 1000; uploadMax = "2M"; };
    cobalt = { uid = 1102; gid = 1001; uploadMax = "8M"; };
  };

  tenantPath = "/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin";

  mkTenantFpm = name: {
    user = name;
    group = name;
    phpPackage = phpPkg;
    # Production php.ini values as provisioned on the reference.
    phpOptions = ''
      expose_php = Off
      include_path = ".:/usr/share/php"
      session.save_path = "/var/lib/php/sessions"
    '';
    settings = {
      listen = "/run/php/php-${name}-fpm.sock";
      "listen.owner" = "www-data";
      "listen.group" = "www-data";
      "listen.mode" = "0660";
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
      "pm.max_requests" = 10000;
      request_terminate_timeout = 180;
      clear_env = "yes";
      "php_value[max_execution_time]" = 120;
      "php_value[memory_limit]" = "128M";
      "php_value[post_max_size]" = tenants.${name}.uploadMax;
      "php_value[upload_max_filesize]" = tenants.${name}.uploadMax;
      "php_admin_value[open_basedir]" = "/home/${name}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
    phpEnv = {
      HOME = "/home/${name}";
      PATH = tenantPath;
      TMP = "/tmp";
      TMPDIR = "/tmp";
      NODE_LABEL = name;
    };
  };

  # One CGI executor per tenant: fcgiwrap runs as the tenant, so CGI scripts
  # under /home/<tenant>/public_html/cgi-bin execute with the tenant's uid.
  mkTenantCgi = name: {
    process.user = name;
    process.group = name;
    socket = {
      type = "unix";
      address = "/run/fcgiwrap-${name}.sock";
      user = name;
      group = "www-data";
      mode = "0660";
    };
  };

  fpmUnsandboxed = {
    ProtectHome = lib.mkForce false;
    ProtectSystem = lib.mkForce false;
    PrivateTmp = lib.mkForce false;
  };
  cgiCleanEnv = [ "HOME" "USER" "LOGNAME" ];

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
        # Proxied handlers (PHP-FPM, fcgiwrap) need the real script path;
        # mod_proxy would otherwise pass a "proxy:fcgi://..." SCRIPT_FILENAME.
        ProxyFCGISetEnvIf "%{REQUEST_URI} =~ m#^/(?:~${name}/)?([^?]+)#" SCRIPT_FILENAME "/home/${name}/public_html/$1"
        ProxyFCGISetEnvIf "%{REQUEST_URI} =~ m#^/~([^/?]+)/([^?]*)#" SCRIPT_FILENAME "/home/$1/public_html/$2"
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
        SetHandler "proxy:unix:/run/fcgiwrap-${name}.sock|fcgi://localhost"
        <If "-d %{REQUEST_FILENAME}">
            SetHandler None
        </If>
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    <Directory /home/${name}/public_html/wsgi-bin>
        SetHandler wsgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
  '';

  # Ubuntu's apache2ctl: service control goes through systemd (the unit is
  # also named apache2.service); everything else runs httpd with this config.
  apache2ctl = pkgs.writeShellScriptBin "apache2ctl" ''
    conf=/etc/httpd/httpd.conf
    case "''${1:-}" in
      start|stop|restart|reload) exec ${config.systemd.package}/bin/systemctl "$1" apache2.service ;;
      graceful) exec ${config.systemd.package}/bin/systemctl reload apache2.service ;;
      graceful-stop) exec ${config.systemd.package}/bin/systemctl stop apache2.service ;;
      configtest) exec ${apache}/bin/httpd -f "$conf" -t ;;
      *) exec ${apache}/bin/httpd -f "$conf" "$@" ;;
    esac
  '';

  httpdConf = pkgs.writeText "httpd.conf" ''
    ServerRoot "${apache}"
    ServerName node.test
    ServerTokens OS
    ServerSignature On
    TraceEnable Off

    DefaultRuntimeDir /run/httpd/runtime
    PidFile /run/httpd/httpd.pid
    Timeout 300
    KeepAlive On
    MaxKeepAliveRequests 100
    KeepAliveTimeout 5
    User www-data
    Group www-data
    HostnameLookups Off
    ErrorLog /var/log/apache2/error.log
    LogLevel warn
    AccessFileName .htaccess
    WSGISocketPrefix /run/httpd/wsgi

    LoadModule access_compat_module ${apache}/modules/mod_access_compat.so
    LoadModule alias_module ${apache}/modules/mod_alias.so
    LoadModule auth_basic_module ${apache}/modules/mod_auth_basic.so
    LoadModule authn_core_module ${apache}/modules/mod_authn_core.so
    LoadModule authn_file_module ${apache}/modules/mod_authn_file.so
    LoadModule authz_core_module ${apache}/modules/mod_authz_core.so
    LoadModule authz_host_module ${apache}/modules/mod_authz_host.so
    LoadModule authz_user_module ${apache}/modules/mod_authz_user.so
    LoadModule autoindex_module ${apache}/modules/mod_autoindex.so
    LoadModule deflate_module ${apache}/modules/mod_deflate.so
    LoadModule dir_module ${apache}/modules/mod_dir.so
    LoadModule env_module ${apache}/modules/mod_env.so
    LoadModule filter_module ${apache}/modules/mod_filter.so
    LoadModule headers_module ${apache}/modules/mod_headers.so
    LoadModule mime_module ${apache}/modules/mod_mime.so
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
    LoadModule unixd_module ${apache}/modules/mod_unixd.so
    LoadModule log_config_module ${apache}/modules/mod_log_config.so
    LoadModule logio_module ${apache}/modules/mod_logio.so
    LoadModule slotmem_shm_module ${apache}/modules/mod_slotmem_shm.so
    LoadModule wsgi_module ${mod_wsgi}/modules/mod_wsgi.so

    Listen 80
    Listen 443

    AddHandler type-map var
    TypesConfig ${apache}/conf/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
    AddType application/x-bzip2 .bz2
    AddType application/x-x509-ca-cert .crt
    AddType application/x-pkcs7-crl .crl
    AddType text/html .shtml
    AddType text/markdown md markdown
    AddType image/vnd.microsoft.icon ico
    RemoveType .webp
    DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm

    <Files ~ "^\.ht">
        Require all denied
    </Files>

    LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-agent}i\"" vhost_combined
    LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %O" common
    LogFormat "%{Referer}i -> %U" referer
    LogFormat "%{User-agent}i" agent

    <IfModule mod_deflate.c>
        <IfModule mod_filter.c>
            AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript
            AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
            AddOutputFilterByType DEFLATE application/rss+xml
            AddOutputFilterByType DEFLATE application/wasm
            AddOutputFilterByType DEFLATE application/xml
        </IfModule>
    </IfModule>

    <IfModule mod_userdir.c>
        UserDir public_html
        UserDir disabled root
        <Directory "/home/*/public_html">
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
        ProxyStatus On
    </IfModule>

    <IfModule mod_autoindex.c>
        Include ${apache}/conf/extra/httpd-autoindex.conf
        IndexOptions FancyIndexing VersionSort HTMLTable NameWidth=* DescriptionWidth=* Charset=UTF-8
    </IfModule>

    <IfModule mod_negotiation.c>
        LanguagePriority en ca cs da de el eo es et fr he hr it ja ko ltz nl nn no pl pt pt-BR ru sv tr zh-CN zh-TW
        ForceLanguagePriority Prefer Fallback
    </IfModule>

    <IfModule mpm_event_module>
        StartServers 2
        MinSpareThreads 25
        MaxSpareThreads 75
        ThreadLimit 64
        ThreadsPerChild 25
        MaxRequestWorkers 150
        MaxConnectionsPerChild 0
    </IfModule>

    <IfModule mod_reqtimeout.c>
        RequestReadTimeout header=20-40,minrate=500
        RequestReadTimeout body=10,minrate=500
    </IfModule>

    <IfModule mod_ssl.c>
        SSLRandomSeed startup builtin
        SSLRandomSeed startup file:/dev/urandom 512
        SSLRandomSeed connect builtin
        SSLRandomSeed connect file:/dev/urandom 512
        SSLSessionCache shmcb:/run/httpd/ssl_scache(512000)
        SSLSessionCacheTimeout 300
        SSLCipherSuite HIGH:!aNULL
        SSLProtocol all -SSLv3
    </IfModule>

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

    DocumentRoot /var/www/html
    CustomLog /var/log/apache2/other_vhosts_access.log vhost_combined

    ${tenantVhost "amber"}
    ${tenantVhost "cobalt"}
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

  # Initial database contents for first start only (provisioned state).
  mariadbInit = pkgs.writeText "mariadb-init.sql" ''
    DROP DATABASE IF EXISTS test;
    CREATE USER IF NOT EXISTS 'amber'@'localhost' IDENTIFIED BY 'amber-pass' WITH MAX_USER_CONNECTIONS 20;
    GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
    CREATE USER IF NOT EXISTS 'cobalt'@'localhost' IDENTIFIED BY 'cobalt-pass' WITH MAX_USER_CONNECTIONS 40;
    GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
    FLUSH PRIVILEGES;
  '';

  postgresInit = pkgs.writeText "postgresql-init.sql" ''
    CREATE ROLE amber LOGIN PASSWORD 'amber-pass' CONNECTION LIMIT 20;
    CREATE ROLE cobalt LOGIN PASSWORD 'cobalt-pass' CONNECTION LIMIT 40;
    CREATE DATABASE amber OWNER amber;
    CREATE DATABASE cobalt OWNER cobalt;
    \c amber
    CREATE EXTENSION IF NOT EXISTS postgis;
    \c cobalt
    CREATE EXTENSION IF NOT EXISTS postgis;
  '';

  seedTenant = name:
    let
      own = "${name}:${name}";
    in ''
      install -d -m 0755 -o ${name} -g ${name} /home/${name}
      install -d -m 0700 -o ${name} -g ${name} /home/${name}/private
      install -d -m 0755 -o ${name} -g ${name} /home/${name}/public_html
      install -d -m 0755 -o ${name} -g ${name} /home/${name}/public_html/cgi-bin
      install -d -m 0755 -o ${name} -g ${name} /home/${name}/public_html/wsgi-bin
      seed_file ${fileDir}/tenants/${name}/private/token /home/${name}/private/token 0600 ${own}
      seed_file ${fileDir}/tenants/${name}/public_html/index.html /home/${name}/public_html/index.html 0644 ${own}
      seed_file ${fileDir}/tenants/${name}/public_html/cgi-bin/hello.py /home/${name}/public_html/cgi-bin/hello.py 0755 ${own}
      seed_file ${fileDir}/skel/.bashrc /home/${name}/.bashrc 0644 ${own}
      seed_file ${fileDir}/skel/.profile /home/${name}/.profile 0644 ${own}
      seed_file ${fileDir}/skel/.bash_logout /home/${name}/.bash_logout 0644 ${own}
    '';
in
{

  networking.hostName = "node17";
  networking.firewall.enable = false;
  networking.hosts = {
    "127.0.0.1" = [ "node17" "catalog.node.test" "sql.node.test" "cache.node.test" ];
    "127.0.0.2" = lib.mkForce [ ];
    "::1" = [ "ip6-localhost" ];
  };
  environment.etc."timezone".text = "Etc/UTC\n";
  services.resolved = {
    enable = true;
    llmnr = "false";
  };

  i18n.defaultLocale = "C.UTF-8";

  environment.systemPackages = [
    apache2ctl
    pkgs.python3
    pkgs.curl
    pkgs.jq
    pkgs.acl
    pkgs.openssl
    pkgs.mariadb
    pgPackage
    phpPkg
  ];

  # Accounts. Tenant and service identities keep the provisioned uid/gid
  # values; passwords are locked, tenants have no interactive login.
  users.groups = {
    amber.gid = tenants.amber.gid;
    cobalt.gid = tenants.cobalt.gid;
    tenants = {
      gid = 1002;
      members = [ "amber" "cobalt" ];
    };
    adm = {
      gid = lib.mkForce 4;
      members = [ "syslog" ];
    };
    syslog.gid = 111;
    messagebus.gid = lib.mkForce 105;
    www-data.gid = 33;
    memcache.gid = 122;
    ssl-cert = {
      gid = 121;
      members = [ "postgres" ];
    };
    postgres.gid = lib.mkForce 123;
    mysql.gid = lib.mkForce 120;
  };

  users.users = {
    amber = {
      isNormalUser = true;
      uid = tenants.amber.uid;
      group = "amber";
      home = "/home/amber";
      createHome = false;
      hashedPassword = "!";
      shell = "/bin/bash";
      description = "";
    };
    cobalt = {
      isNormalUser = true;
      uid = tenants.cobalt.uid;
      group = "cobalt";
      home = "/home/cobalt";
      createHome = false;
      hashedPassword = "!";
      shell = "/bin/bash";
      description = "";
    };
    www-data = {
      uid = 33;
      group = "www-data";
      isSystemUser = true;
      home = "/var/www";
      description = "www-data";
    };
    postgres.uid = lib.mkForce 114;
    syslog = {
      uid = 104;
      group = "syslog";
      isSystemUser = true;
      home = "/var/spool/rsyslog";
      description = "Log daemon";
    };
    mysql.uid = lib.mkForce 112;
    memcache = {
      uid = 113;
      group = "memcache";
      isSystemUser = true;
      home = "/nonexistent";
      description = "Memcached";
    };
  };

  # Tenant login limits (applied to PAM sessions).
  security.pam.loginLimits = [
    { domain = "@tenants"; type = "hard"; item = "nproc"; value = "200"; }
    { domain = "@tenants"; type = "soft"; item = "nproc"; value = "200"; }
    { domain = "@tenants"; type = "hard"; item = "nofile"; value = "4096"; }
    { domain = "@tenants"; type = "soft"; item = "nofile"; value = "4096"; }
  ];

  systemd.slices."user-".sliceConfig = {
    MemoryHigh = "80%";
    MemoryMax = "90%";
  };

  # Tenants may read their own access/error logs via sudo as group adm.
  security.sudo.extraRules = [
    {
      users = [ "amber" ];
      runAs = ":adm";
      commands = [
        { command = "/bin/cat /var/log/web/amber-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/cat /var/log/web/amber-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/amber-error.log"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/cat /var/log/web/amber-error.log"; options = [ "NOPASSWD" ]; }
      ];
    }
    {
      users = [ "cobalt" ];
      runAs = ":adm";
      commands = [
        { command = "/bin/cat /var/log/web/cobalt-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/cat /var/log/web/cobalt-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/cobalt-error.log"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/cat /var/log/web/cobalt-error.log"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
      PrintMotd = false;
      AcceptEnv = [ "LANG" "LC_*" ];
    };
  };

  # Apache. Starts as root; workers run as www-data; mod_wsgi daemons and
  # CGI executors run as the tenant.
  services.httpd = {
    enable = true;
    package = apache;
    user = "www-data";
    group = "www-data";
    configFile = httpdConf;
    logFormat = "none";
  };
  systemd.services.httpd = {
    aliases = [ "apache2.service" ];
    serviceConfig = {
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
      RuntimeDirectoryMode = lib.mkForce "0755";
      AmbientCapabilities = lib.mkForce [ ];
    };
  };

  services.fcgiwrap.instances = lib.mapAttrs (name: _: mkTenantCgi name) tenants;

  services.phpfpm.pools = lib.mapAttrs (name: _: mkTenantFpm name) tenants;
  # Pools run unsandboxed like the reference (tenant homes and /tmp stay visible).
  systemd.services."phpfpm-amber".serviceConfig = fpmUnsandboxed;
  systemd.services."phpfpm-cobalt".serviceConfig = fpmUnsandboxed;
  # One operator-facing unit for both tenant FPM pools, as on the reference.
  systemd.services."phpfpm-amber".partOf = [ "php8.1-fpm.service" ];
  systemd.services."phpfpm-cobalt".partOf = [ "php8.1-fpm.service" ];
  systemd.services."php8.1-fpm" = {
    description = "PHP FastCGI Process Manager (tenant pools)";
    wantedBy = [ "multi-user.target" ];
    requires = [ "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    after = [ "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
    };
  };
  systemd.services.sshd.aliases = [ "ssh.service" ];
  systemd.services.syslog.aliases = [ "rsyslog.service" ];

  services.rsyslogd = {
    enable = true;
    defaultConfig = "";
    extraConfig = ''
      $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
      $FileOwner syslog
      $FileGroup adm
      $FileCreateMode 0640
      auth,authpriv.*                 /var/log/auth.log
      *.*;auth,authpriv.none          -/var/log/syslog
      kern.*                          -/var/log/kern.log
      cron.*                          /var/log/cron.log
    '';
  };
  # suexec-style clean environment for tenant CGI.
  systemd.services."fcgiwrap-amber".serviceConfig.UnsetEnvironment = cgiCleanEnv;
  systemd.services."fcgiwrap-cobalt".serviceConfig.UnsetEnvironment = cgiCleanEnv;

  services.memcached = {
    enable = true;
    user = "memcache";
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    extraOptions = [ "-U" "0" ];
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "127.0.0.1";
      port = 3306;
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_general_ci";
    };
    initialDatabases = [
      { name = "amber"; }
      { name = "cobalt"; }
    ];
    initialScript = mariadbInit;
  };
  systemd.services.mysql.aliases = [ "mariadb.service" ];

  services.postgresql = {
    enable = true;
    package = pgPackage;
    extensions = ps: [ ps.postgis ];
    enableTCPIP = false;
    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
      password_encryption = "scram-sha-256";
      ssl = "on";
      ssl_cert_file = "/etc/ssl/certs/ssl-cert-snakeoil.pem";
      ssl_key_file = "/etc/ssl/private/ssl-cert-snakeoil.key";
      log_timezone = "Etc/UTC";
      log_line_prefix = "%m [%p] %q%u@%d ";
      timezone = "Etc/UTC";
      datestyle = "iso, mdy";
      lc_messages = "C.UTF-8";
      lc_monetary = "C.UTF-8";
      lc_numeric = "C.UTF-8";
      lc_time = "C.UTF-8";
      default_text_search_config = "pg_catalog.english";
    };
    authentication = lib.mkOverride 10 ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    initialScript = postgresInit;
  };

  systemd.services.postgresql-snakeoil = {
    description = "Snake-oil TLS certificate for PostgreSQL";
    before = [ "postgresql.service" ];
    wantedBy = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0755 /etc/ssl/certs
      install -d -m 0710 -o root -g ssl-cert /etc/ssl/private
      install -m 0644 /etc/node/server.crt /etc/ssl/certs/ssl-cert-snakeoil.pem
      install -m 0600 -o postgres -g postgres /etc/node/server.key /etc/ssl/private/ssl-cert-snakeoil.key
    '';
  };

  services.cron.enable = true;

  services.logrotate.settings.web = {
    files = "/var/log/web/*.log";
    frequency = "daily";
    rotate = 14;
    dateext = true;
    missingok = true;
    notifempty = true;
    compress = true;
    delaycompress = true;
    su = "root adm";
    create = "0640 root adm";
    sharedscripts = true;
    postrotate = "systemctl reload apache2 > /dev/null 2>&1 || true";
  };

  systemd.tmpfiles.rules = [
    "d /run/php 0755 www-data www-data -"
    "d /var/lib/php/sessions 1733 root root -"
    "d /usr/bin 0755 root root -"
    "d /usr/local/bin 0755 root root -"
    "d /usr/local/sbin 0755 root root -"
    "L+ /usr/bin/python3 - - - - ${pkgs.python3}/bin/python3"
    "L+ /usr/bin/php - - - - ${phpPkg}/bin/php"
    "L+ /usr/bin/perl - - - - ${pkgs.perl}/bin/perl"
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /bin/cat - - - - /run/current-system/sw/bin/cat"
    "L+ /usr/bin/cat - - - - /run/current-system/sw/bin/cat"
  ];

  system.activationScripts.nodeSeed = {
    deps = [ "users" "groups" ];
    text = ''
      seed_file() {
        # $1 source, $2 destination, $3 mode, $4 owner:group.
        if [ ! -e "$2" ]; then
          install -m "$3" -o "''${4%%:*}" -g "''${4##*:}" "$1" "$2"
        fi
      }

      install -d -m 0755 /srv /srv/node
      seed_file ${fileDir}/srv-node/index.html /srv/node/index.html 0644 root:root

      install -d -m 0755 /var/www /var/www/html
      install -d -m 0750 -o root -g adm /var/log/apache2
      install -d -m 0750 -o root -g adm /var/log/web
      for f in amber-access amber-error cobalt-access cobalt-error; do
        if [ ! -e /var/log/web/$f.log ]; then
          install -m 0640 -o root -g adm /dev/null /var/log/web/$f.log
        fi
      done

      install -d -m 0755 /etc/node
      ${lib.concatMapStrings seedTenant (builtins.attrNames tenants)}
    '';
  };

  environment.etc."cinc/client.rb".text = ''
    # The client.rb file specifies how Chef Infra Client is configured on a node
    # See https://docs.chef.io/config_rb_client/ for detailed configuration options
    #
    # Minimal example configuration:
    # node_name  "THIS_NODE_NAME"
    # chef_server_url  "https://CHEF.MYCOMPANY.COM/organizations/MY_CHEF_ORG"
    # chef_license  "accept"
  '';

}
