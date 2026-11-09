{ config, lib, pkgs, ... }:
let
  httpd = pkgs.apacheHttpd;
  mod = name: "LoadModule ${name}_module ${httpd}/modules/mod_${name}.so";
  wsgiModule = "${pkgs.apacheHttpdPackages.mod_wsgi3}/modules/mod_wsgi.so";
  php = pkgs.php;
  python = pkgs.python3;

  tenants = {
    amber = { uid = 1101; gid = 1000; sqlHash = "*CE994D3F34F0502BC51156503AF81CDDB63F415E"; sqlMaxConn = 20; pgHash = "SCRAM-SHA-256$4096:1rJz1zqG8QX/Y9iyLfy+lA==$xiy0NZkFo/LAtz2nXOGKIe2zVKP/vQRkaWaOjY+I4Bs=:erHpSa6MlYgT5C+t+fyUrzYeTASwOPfh/4ctsI3JRbQ="; pgConn = 20; };
    cobalt = { uid = 1102; gid = 1001; sqlHash = "*4E3F82FE2BB932A394FCFB9A3F056ACE68141483"; sqlMaxConn = 40; pgHash = "SCRAM-SHA-256$4096:0uFjL0lkmELvx5f9FwpW+w==$qqQzU/nP3uNK/vLoe1X7N6sppcWN8hJ7U8Hi1pYp+Ws=:TFrV6ScYH+rMr+DnKDmtpLofLmo94TnqPL3iJIUyguU="; pgConn = 40; };
  };

  phpPool = name: {
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
      "env[HOME]" = "/home/${name}";
      "env[PATH]" = "/usr/local/bin:/usr/bin:/bin";
      "env[TMP]" = "/tmp";
      "env[TMPDIR]" = "/tmp";
      "env[NODE_LABEL]" = name;
      "php_value[max_execution_time]" = 120;
      "php_value[memory_limit]" = "128M";
      "php_value[post_max_size]" = if name == "amber" then "2M" else "8M";
      "php_value[upload_max_filesize]" = if name == "amber" then "2M" else "8M";
      "php_admin_value[open_basedir]" = "/home/${name}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
  };

  vhostBlock = name: ''
    WSGIDaemonProcess ${name} user=${name} group=${name} processes=1 threads=4
    <VirtualHost *:443>
        ServerName ${name}.node.test
        ServerAlias ${name}.node.alt.test
        SSLEngine on
        SSLCertificateFile /etc/node/server.crt
        SSLCertificateKeyFile /etc/node/server.key
        DocumentRoot /home/${name}/public_html
        SetEnv DOCUMENT_ROOT /home/${name}/public_html
        ProxyTimeout 90
        RequestHeader unset Proxy early
        UseCanonicalName Off
        WSGIProcessGroup ${name}
        CustomLog /var/log/web/${name}-access.log combined
        ErrorLog /var/log/web/${name}-error.log
        RewriteEngine on
        ProxyPassMatch "^/~${name}/(.+\.ph(p|ps|p3|tml))$" "unix:/run/php/php-${name}-fpm.sock|fcgi://127.0.0.1/home/${name}/public_html/$1"
        ProxyPassMatch "^/(.+\.ph(p|ps|p3|tml))$" "unix:/run/php/php-${name}-fpm.sock|fcgi://127.0.0.1/home/${name}/public_html/$1"
        ProxyFCGISetEnvIf "true" SCRIPT_NAME "%{REQUEST_URI}"
        SetEnvIf Request_URI "^/~${name}/(.*)$" USER_SUBPATH=$1
        ProxyFCGISetEnvIf "%{REQUEST_URI} !~ m#^/~#" SCRIPT_FILENAME "%{ENV:DOCUMENT_ROOT}%{REQUEST_URI}"
        ProxyFCGISetEnvIf "%{REQUEST_URI} =~ m#^/~#" SCRIPT_FILENAME "/home/${name}/public_html/%{ENV:USER_SUBPATH}"
        ProxyPassMatch "^/~${name}/cgi-bin/(.*)$" "unix:/run/fcgiwrap-${name}.sock|fcgi://localhost/home/${name}/public_html/cgi-bin/$1"
        ProxyPassMatch "^/cgi-bin/(.*)$" "unix:/run/fcgiwrap-${name}.sock|fcgi://localhost/home/${name}/public_html/cgi-bin/$1"
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

  httpdConf = pkgs.writeText "httpd.conf" ''
    ServerRoot "${httpd}"
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
    AccessFileName .htaccess
    ServerTokens OS
    ServerSignature On
    TraceEnable Off
    TypesConfig ${httpd}/conf/mime.types
    AddType application/x-x509-ca-cert .crt
    AddType application/x-pkcs7-crl .crl
    AddEncoding x-compress .Z
    AddEncoding x-gzip .gz .tgz
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz

    ${lib.concatStringsSep "\n" [
      (mod "access_compat") (mod "alias") (mod "auth_basic") (mod "authn_core")
      (mod "authn_file") (mod "authz_core") (mod "authz_host") (mod "authz_user")
      (mod "autoindex") (mod "cgid") (mod "deflate") (mod "dir") (mod "env")
      (mod "filter") (mod "headers") (mod "log_config") (mod "logio") (mod "mime")
      (mod "mpm_event") (mod "negotiation") (mod "proxy") (mod "proxy_fcgi")
      (mod "reqtimeout") (mod "rewrite") (mod "setenvif") (mod "socache_shmcb")
      (mod "slotmem_shm") (mod "ssl") (mod "status") (mod "unixd") (mod "userdir")
      (mod "version") (mod "watchdog")
      "LoadModule wsgi_module ${wsgiModule}"
    ]}

    <IfModule mpm_event_module>
        StartServers 2
        MinSpareThreads 25
        MaxSpareThreads 75
        ThreadLimit 64
        ThreadsPerChild 25
        MaxRequestWorkers 150
        MaxConnectionsPerChild 0
    </IfModule>

    <IfModule ssl_module>
        Listen 443
        SSLSessionCache shmcb:/run/apache2/ssl_scache(512000)
        SSLSessionCacheTimeout 300
        SSLCipherSuite HIGH:!aNULL
        SSLProtocol all -SSLv3
    </IfModule>
    Listen 80

    <IfModule mod_status.c>
        <Location /server-status>
            SetHandler server-status
            Require local
        </Location>
        ExtendedStatus On
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
    <FilesMatch "^\.ht">
        Require all denied
    </FilesMatch>

    LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
    LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %O" common
    LogFormat "%{Referer}i -> %U" referer
    LogFormat "%{User-agent}i" agent
    CustomLog /var/log/apache2/other_vhosts_access.log vhost_combined

    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json application/xml image/svg+xml
    </IfModule>

    DocumentRoot /var/www/html
    <IfModule dir_module>
        DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm
    </IfModule>

    <IfModule mod_userdir.c>
        UserDir public_html
        UserDir disabled root
        <Directory "/home/*/public_html">
            AllowOverride FileInfo AuthConfig Limit Indexes
            Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
            <Limit GET POST OPTIONS>
                Require all granted
            </Limit>
            <LimitExcept GET POST OPTIONS>
                Require all denied
            </LimitExcept>
        </Directory>
    </IfModule>

    WSGISocketPrefix /run/apache2/wsgi

    ServerName node.test

    ${vhostBlock "amber"}
    ${vhostBlock "cobalt"}

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

  seedTenant = name: t: ''
    home=/home/${name}
    install -d -o ${name} -g ${name} -m 755 "$home" "$home/public_html" "$home/public_html/cgi-bin" "$home/public_html/wsgi-bin"
    install -d -o ${name} -g ${name} -m 700 "$home/private"
    if [ ! -e "$home/public_html/index.html" ]; then
      printf '%s\n' "${name} workspace" > "$home/public_html/index.html"
      chown ${name}:${name} "$home/public_html/index.html"
    fi
    if [ ! -e "$home/public_html/cgi-bin/hello.py" ]; then
      cat > "$home/public_html/cgi-bin/hello.py" <<'PYEOF'
#!/usr/bin/python3
print("Content-Type: text/plain\n")
print("hello from ${name}")
PYEOF
      chown ${name}:${name} "$home/public_html/cgi-bin/hello.py"
      chmod 755 "$home/public_html/cgi-bin/hello.py"
    fi
    if [ ! -e "$home/private/token" ]; then
      printf '%s\n' "${name}-private" > "$home/private/token"
      chown ${name}:${name} "$home/private/token"
      chmod 600 "$home/private/token"
    fi
    if [ ! -e "$home/.profile" ]; then
      printf '%s\n' '# ~/.profile: executed by the command interpreter for login shells.' '[ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"' > "$home/.profile"
      chown ${name}:${name} "$home/.profile"
    fi
    if [ ! -e "$home/.bashrc" ]; then
      printf '%s\n' '# ~/.bashrc: executed by bash(1) for non-login shells.' 'alias ll="ls -alF"' 'alias la="ls -A"' 'alias l="ls -CF"' > "$home/.bashrc"
      chown ${name}:${name} "$home/.bashrc"
    fi
  '';

  pgInit = pkgs.writeText "postgres-init.sql" ''
    CREATE ROLE amber LOGIN CONNECTION LIMIT 20 PASSWORD '${tenants.amber.pgHash}';
    CREATE ROLE cobalt LOGIN CONNECTION LIMIT 40 PASSWORD '${tenants.cobalt.pgHash}';
    CREATE DATABASE amber OWNER amber;
    CREATE DATABASE cobalt OWNER cobalt;
    \c amber
    CREATE EXTENSION IF NOT EXISTS postgis;
    \c cobalt
    CREATE EXTENSION IF NOT EXISTS postgis;
  '';

  mysqlInit = pkgs.writeText "mysql-init.sql" ''
    DROP DATABASE IF EXISTS test;
    CREATE DATABASE IF NOT EXISTS amber;
    CREATE DATABASE IF NOT EXISTS cobalt;
    CREATE USER 'amber'@'localhost' IDENTIFIED BY PASSWORD '${tenants.amber.sqlHash}' WITH MAX_USER_CONNECTIONS ${toString tenants.amber.sqlMaxConn};
    GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
    CREATE USER 'cobalt'@'localhost' IDENTIFIED BY PASSWORD '${tenants.cobalt.sqlHash}' WITH MAX_USER_CONNECTIONS ${toString tenants.cobalt.sqlMaxConn};
    GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
    FLUSH PRIVILEGES;
  '';
in
{
  networking.hostName = "node17";
  networking.firewall.enable = false;
  networking.hosts."127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "C.UTF-8";

  users.groups = {

    amber.gid = 1000;
    cobalt.gid = 1001;
    tenants = { gid = 1002; members = [ "amber" "cobalt" ]; };
    www-data.gid = 33;
    memcache.gid = 122;
  };

  users.users = {
    amber = {
      isNormalUser = true;
      uid = 1101;
      group = "amber";
      home = "/home/amber";
      homeMode = "755";
      createHome = true;
      hashedPassword = "!";
    };
    cobalt = {
      isNormalUser = true;
      uid = 1102;
      group = "cobalt";
      home = "/home/cobalt";
      homeMode = "755";
      createHome = true;
      hashedPassword = "!";
    };
    www-data = {
      isSystemUser = true;
      uid = 33;
      group = "www-data";
      home = "/var/www";
      createHome = false;
    };
    memcache = {
      isSystemUser = true;
      uid = 113;
      group = "memcache";
      home = "/nonexistent";
      createHome = false;
    };
  };

  systemd.tmpfiles.rules = [
    "L+ /usr/bin/python3 - - - - ${python}/bin/python3"
    "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
    "d /run/apache2 0755 root root -"
    "d /run/php 0755 root root -"
    "d /var/log/apache2 0755 root root -"
    "d /var/log/web 0750 root adm -"
    "f /var/log/web/amber-access.log 0640 root adm -"
    "f /var/log/web/amber-error.log 0640 root adm -"
    "f /var/log/web/cobalt-access.log 0640 root adm -"
    "f /var/log/web/cobalt-error.log 0640 root adm -"
    "d /srv/node 0755 root root -"
    "d /var/www/html 0755 root root -"
  ];

  systemd.services = lib.listToAttrs (map (n: lib.nameValuePair "phpfpm-${n}" {
    serviceConfig.ProtectHome = lib.mkForce false;
  }) (lib.attrNames tenants));

  system.activationScripts.nodeSeed = {
    deps = [ "users" "groups" ];
    text = ''
      install -d -m 755 /srv/node /var/www/html
      if [ ! -e /srv/node/index.html ]; then
        printf '%s\n' 'node service' > /srv/node/index.html
        chmod 644 /srv/node/index.html
      fi
      if [ ! -e /var/www/html/index.html ]; then
        printf '%s\n' '<html><body><h1>It works!</h1></body></html>' > /var/www/html/index.html
      fi
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList seedTenant tenants)}
    '';
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "amber" ];
      runAs = ":adm";
      commands = [
        { command = "/bin/cat /var/log/web/amber-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/amber-error.log"; options = [ "NOPASSWD" ]; }
      ];
    }
    {
      users = [ "cobalt" ];
      runAs = ":adm";
      commands = [
        { command = "/bin/cat /var/log/web/cobalt-access.log"; options = [ "NOPASSWD" ]; }
        { command = "/bin/cat /var/log/web/cobalt-error.log"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  services.httpd = {
    enable = true;
    package = httpd;
    user = "root";
    group = "root";
    configFile = httpdConf;
  };

  services.fcgiwrap.instances = lib.mapAttrs (name: t: {
    process.user = name;
    process.group = name;
    socket = {
      type = "unix";
      address = "/run/fcgiwrap-${name}.sock";
      user = "www-data";
      group = "www-data";
      mode = "0660";
    };
  }) tenants;

  services.phpfpm = {
    phpPackage = php;
    phpOptions = ''
      expose_php = Off
      error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
      display_errors = Off
      log_errors = On
      session.save_handler = files
      session.gc_maxlifetime = 1440
    '';
    settings.error_log = lib.mkForce "/var/log/php-fpm.log";
    pools = {
      amber = phpPool "amber";
      cobalt = phpPool "cobalt";
    };
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld.bind-address = "127.0.0.1";
    initialScript = mysqlInit;
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    extensions = ps: [ ps.postgis ];
    authentication = lib.mkOverride 10 ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    initialScript = pgInit;
  };

  services.memcached = {
    enable = true;
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    user = "memcache";
    extraOptions = [ "-U" "0" ];
  };

  environment.systemPackages = [
    httpd
    php
    python
    pkgs.mariadb
    pkgs.postgresql_17
    pkgs.memcached
    pkgs.curl
    pkgs.wget
    pkgs.jq
    pkgs.git
    pkgs.rsync
    pkgs.vim
    pkgs.nano
    pkgs.htop
    pkgs.tmux
    pkgs.screen
    pkgs.strace
    pkgs.tcpdump
    pkgs.lsof
    pkgs.socat
    pkgs.netcat-openbsd
    pkgs.bc
    pkgs.file
    pkgs.acl
    pkgs.mtr
    pkgs.iputils
    pkgs.bind.dnsutils
    pkgs.openssl
  ];
}
