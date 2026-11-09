{ config, lib, pkgs, ... }:
let
  pkg = pkgs.apacheHttpd;
  wsgi = pkgs.apacheHttpdPackages.mod_wsgi3;
  tenants = [
    { name = "amber"; uid = 1101; gid = 1000; php = { post = "2M"; }; }
    { name = "cobalt"; uid = 1102; gid = 1001; php = { post = "8M"; }; }
  ];

  mods = [
    "log_config" "logio" "unixd" "version" "watchdog" "access_compat" "alias" "auth_basic" "authn_core"
    "authn_file" "authz_core" "authz_host" "authz_user" "autoindex" "cgid" "deflate" "dir" "env" "filter"
    "headers" "mime" "mpm_event" "negotiation" "proxy" "proxy_fcgi" "reqtimeout" "rewrite" "setenvif"
    "socache_shmcb" "ssl" "status" "userdir"
  ];

  tenantVhost = t: ''
    WSGIDaemonProcess ${t.name} user=${t.name} group=${t.name} processes=1 threads=4
    <VirtualHost *:443>
        ServerName ${t.name}.node.test
        ServerAlias ${t.name}.node.alt.test
        SSLEngine on
        SSLCertificateFile /etc/node/server.crt
        SSLCertificateKeyFile /etc/node/server.key
        DocumentRoot /home/${t.name}/public_html
        ProxyTimeout 90
        RequestHeader unset Proxy early
        UseCanonicalName Off
        WSGIProcessGroup ${t.name}
        CustomLog /var/log/web/${t.name}-access.log combined
        ErrorLog /var/log/web/${t.name}-error.log
        RewriteEngine on
        RewriteCond /home/${t.name}/public_html%{REQUEST_FILENAME} -f
        RewriteRule ^/cgi-bin/(.*)$ /~${t.name}/cgi-bin/$1 [PT,L]
        <FilesMatch ".+\.ph(p|ps|p3|tml)$">
            SetHandler "proxy:unix:/run/php/php-${t.name}-fpm.sock|fcgi://127.0.0.1"
        </FilesMatch>
    </VirtualHost>
    <VirtualHost *:80>
        ServerName ${t.name}.node.test
        ServerAlias ${t.name}.node.alt.test
        RedirectPermanent /.well-known/acme-challenge/ http://acme.node.test/.well-known/acme-challenge/
        RedirectPermanent / https://${t.name}.node.test/
    </VirtualHost>
    <Directory /home/${t.name}/public_html>
        AllowOverride AuthConfig FileInfo Indexes
        Options SymLinksIfOwnerMatch Indexes Includes
        Require all granted
    </Directory>
    <Directory /home/${t.name}/public_html/cgi-bin>
        SetHandler cgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
    <Directory /home/${t.name}/public_html/wsgi-bin>
        SetHandler wsgi-script
        Options ExecCGI SymLinksIfOwnerMatch
        Require all granted
    </Directory>
  '';

  httpdConf = pkgs.writeText "httpd.conf" ''
    ServerRoot ${pkg}
    DefaultRuntimeDir /run/httpd
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
    ServerTokens OS
    ServerSignature On
    TraceEnable Off

    ${lib.concatMapStringsSep "\n" (m: "LoadModule ${m}_module ${pkg}/modules/mod_${m}.so") mods}
    LoadModule wsgi_module ${wsgi}/modules/mod_wsgi.so

    Listen 80
    Listen 443

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
    CustomLog /var/log/apache2/other_vhosts_access.log vhost_combined

    # mods
    <IfModule mpm_event_module>
        StartServers 2
        MinSpareThreads 25
        MaxSpareThreads 75
        ThreadLimit 64
        ThreadsPerChild 25
        MaxRequestWorkers 150
        MaxConnectionsPerChild 0
    </IfModule>
    ScriptSock /run/httpd/cgisock
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript
        AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
        AddOutputFilterByType DEFLATE application/rss+xml
        AddOutputFilterByType DEFLATE application/wasm
        AddOutputFilterByType DEFLATE application/xml
    </IfModule>
    DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm
    TypesConfig ${pkg}/conf/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
    AddType application/x-bzip2 .bz2
    AddType application/x-x509-ca-cert .crt
    AddType application/x-pkcs7-crl .crl
    AddLanguage en .en
    AddLanguage de .de
    AddLanguage fr .fr
    AddLanguage es .es
    LanguagePriority en ca cs da de el eo es et fr he hr it ja ko ltz nl nn no pl pt pt-BR ru sv tr zh-CN zh-TW
    ForceLanguagePriority Prefer Fallback
    RequestReadTimeout header=20-40,minrate=500
    RequestReadTimeout body=10,minrate=500
    SSLRandomSeed startup builtin
    SSLRandomSeed startup file:/dev/urandom 512
    SSLRandomSeed connect builtin
    SSLRandomSeed connect file:/dev/urandom 512
    SSLSessionCache shmcb:/run/httpd/ssl_scache(512000)
    SSLSessionCacheTimeout 300
    SSLCipherSuite HIGH:!aNULL
    SSLProtocol all -SSLv3
    BrowserMatch "Mozilla/2" nokeepalive
    BrowserMatch "MSIE 4\.0b2;" nokeepalive downgrade-1.0 force-response-1.0
    BrowserMatch "RealPlayer 4\.0" force-response-1.0
    BrowserMatch "Java/1\.0" force-response-1.0
    BrowserMatch "JDK/1\.0" force-response-1.0
    <Location /server-status>
        SetHandler server-status
        Require local
    </Location>
    ExtendedStatus On
    ProxyStatus On

    IndexOptions FancyIndexing VersionSort HTMLTable NameWidth=* DescriptionWidth=* Charset=UTF-8
    AddIconByEncoding (CMP,/icons/compressed.gif) x-compress x-gzip x-bzip2
    AddIconByType (TXT,/icons/text.gif) text/*
    AddIconByType (IMG,/icons/image2.gif) image/*
    AddIconByType (SND,/icons/sound2.gif) audio/*
    AddIconByType (VID,/icons/movie.gif) video/*
    AddIcon /icons/binary.gif .bin .exe
    AddIcon /icons/tar.gif .tar
    AddIcon /icons/compressed.gif .Z .z .tgz .gz .zip
    AddIcon /icons/layout.gif .html .shtml .htm .pdf
    AddIcon /icons/text.gif .txt
    AddIcon /icons/c.gif .c
    AddIcon /icons/p.gif .pl .py
    AddIcon /icons/script.gif .conf .sh .shar .csh .ksh .tcl
    AddIcon /icons/back.gif ..
    AddIcon /icons/hand.right.gif README
    AddIcon /icons/folder.gif ^^DIRECTORY^^
    AddIcon /icons/blank.gif ^^BLANKICON^^
    DefaultIcon /icons/unknown.gif
    ReadmeName README.html
    HeaderName HEADER.html
    IndexIgnore .??* *~ *# RCS CVS *,v *,t

    <Directory /usr/share/apache2/icons>
        Options FollowSymlinks
        AllowOverride None
        Require all granted
    </Directory>
    Alias /icons/ "/usr/share/apache2/icons/"
    ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
    <Directory "/usr/lib/cgi-bin">
        AllowOverride None
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        Require all granted
    </Directory>

    UserDir public_html
    UserDir disabled root
    <Directory /home/*/public_html>
        AllowOverride FileInfo AuthConfig Limit Indexes
        Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
        Require method GET POST OPTIONS
    </Directory>

    ServerName node.test
    ${lib.concatMapStringsSep "\n" tenantVhost tenants}

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

  indexFor = n: "${n} workspace\n";
  helloFor = n: ''
    #!${pkgs.python3}/bin/python3
    print("Content-Type: text/plain\n")
    print("hello from ${n}")
  '';

  provision = pkgs.writeShellScript "tenant-provision" ''
    set -eu
    ${lib.concatMapStrings (t: let n = t.name; in ''
      home=/home/${n}
      install -d -o ${n} -g ${n} -m 0755 $home $home/public_html $home/public_html/cgi-bin $home/public_html/wsgi-bin
      install -d -o ${n} -g ${n} -m 0700 $home/private
      [ -e $home/private/token ] || install -o ${n} -g ${n} -m 0600 ${pkgs.writeText "${n}-token" "${n}-private\n"} $home/private/token
      [ -e $home/public_html/index.html ] || install -o ${n} -g ${n} -m 0644 ${pkgs.writeText "${n}-index" (indexFor n)} $home/public_html/index.html
      [ -e $home/public_html/cgi-bin/hello.py ] || install -o ${n} -g ${n} -m 0755 ${pkgs.writeText "${n}-hello" (helloFor n)} $home/public_html/cgi-bin/hello.py
    '') tenants}
  '';

  pgScript = pkgs.writeText "pg-init.sql" ''
    CREATE ROLE amber LOGIN PASSWORD 'SCRAM-SHA-256$4096:0Z+b+mf1dSQy4EM49Waj+g==$CTUCetK5MKtDLgqRxrIoZ+6WOCpTPInC30h2eAhChEw=:Gvcgr43uFIXw7h4Rn84BdD1LB5ESNFTs4Rt6R0KquwA=';
    CREATE ROLE cobalt LOGIN PASSWORD 'SCRAM-SHA-256$4096:51uAA63Hgn9jz24UR48jtQ==$+HKXjRkwpllt0E1pqhKuYZXNMcyeSjdP2GJpRwMYP5w=:JRXGulWBF864Olzd2ky0HUgCtOKaFaKRcAg9DkYAPws=';
    CREATE DATABASE amber OWNER amber;
    CREATE DATABASE cobalt OWNER cobalt;
    REVOKE CONNECT ON DATABASE amber FROM PUBLIC;
    REVOKE CONNECT ON DATABASE cobalt FROM PUBLIC;
  '';
in
{
  networking.hostName = "node17";
  networking.firewall.enable = false;
  networking.hosts."127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];
  i18n.defaultLocale = "C.UTF-8";
  time.timeZone = "UTC";

  # ---- accounts
  users.mutableUsers = true;
  users.groups = {
    tenants.gid = 1002;
    www-data.gid = 33;
    amber.gid = 1000;
    cobalt.gid = 1001;
    memcache = { };
  };
  users.users = {
    www-data = { uid = 33; group = "www-data"; isSystemUser = true; home = "/var/www"; };
    memcache = { isSystemUser = true; group = "memcache"; };
    amber = {
      uid = 1101; group = "amber"; extraGroups = [ "tenants" ]; isNormalUser = true;
      home = "/home/amber"; homeMode = "755"; shell = pkgs.bashInteractive;
    };
    cobalt = {
      uid = 1102; group = "cobalt"; extraGroups = [ "tenants" ]; isNormalUser = true;
      home = "/home/cobalt"; homeMode = "755"; shell = pkgs.bashInteractive;
    };
  };

  security.sudo.extraConfig = ''
    amber ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/amber-access.log, /bin/cat /var/log/web/amber-error.log, /run/current-system/sw/bin/cat /var/log/web/amber-access.log, /run/current-system/sw/bin/cat /var/log/web/amber-error.log
    cobalt ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/cobalt-access.log, /bin/cat /var/log/web/cobalt-error.log, /run/current-system/sw/bin/cat /var/log/web/cobalt-access.log, /run/current-system/sw/bin/cat /var/log/web/cobalt-error.log
  '';

  security.pam.loginLimits = [
    { domain = "@tenants"; type = "hard"; item = "nproc"; value = "200"; }
    { domain = "@tenants"; type = "soft"; item = "nproc"; value = "200"; }
    { domain = "@tenants"; type = "hard"; item = "nofile"; value = "4096"; }
    { domain = "@tenants"; type = "soft"; item = "nofile"; value = "4096"; }
  ];

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    X11Forwarding = true;
    PrintMotd = false;
  };

  environment.systemPackages = [ pkgs.php pkgs.mariadb pkgs.postgresql pkgs.memcached pkgs.sudo ];

  systemd.tmpfiles.rules = [
    "d /var/log/web 0750 root adm -"
    "f /var/log/web/amber-access.log 0640 root adm -"
    "f /var/log/web/amber-error.log 0640 root adm -"
    "f /var/log/web/cobalt-access.log 0640 root adm -"
    "f /var/log/web/cobalt-error.log 0640 root adm -"
    "d /var/log/apache2 0750 root adm -"
    "d /run/php 0755 www-data www-data -"
    "d /srv/node 0755 root root -"
    "d /usr/bin 0755 root root -"
    "L+ /usr/bin/python3 - - - - ${pkgs.python3}/bin/python3"
    "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
    "L+ /usr/share/apache2/icons - - - - ${pkg}/icons"
  ];

  systemd.services.tenant-provision = {
    wantedBy = [ "multi-user.target" ];
    before = [ "httpd.service" "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; ExecStart = provision; };
  };
  system.activationScripts.srvnode = ''
    mkdir -p /srv/node
    [ -e /srv/node/index.html ] || echo "node service" > /srv/node/index.html
  '';

  # ---- web
  services.httpd = {
    enable = true;
    adminAddr = "root@localhost";
    user = "www-data";
    group = "www-data";
    configFile = httpdConf;
    logDir = "/var/log/apache2";
  };
  systemd.services.httpd.serviceConfig = {
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    RuntimeDirectoryMode = lib.mkForce "0755";
  };
  systemd.services.httpd.after = [ "tenant-provision.service" "phpfpm-amber.service" "phpfpm-cobalt.service" ];

  services.phpfpm.pools = lib.listToAttrs (map (t: lib.nameValuePair t.name {
    user = t.name;
    group = t.name;
    phpPackage = pkgs.php;
    settings = {
      "listen" = "/run/php/php-${t.name}-fpm.sock";
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
      "php_value[post_max_size]" = t.php.post;
      "php_value[upload_max_filesize]" = t.php.post;
      "php_admin_value[open_basedir]" = "/home/${t.name}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
    phpEnv = {
      HOME = "/home/${t.name}";
      PATH = "/usr/local/bin:/usr/bin:/bin";
      TMP = "/tmp";
      TMPDIR = "/tmp";
      NODE_LABEL = t.name;
    };
  }) tenants);

  systemd.services.phpfpm-amber.serviceConfig = { ProtectHome = lib.mkForce false; PrivateTmp = lib.mkForce false; ProtectSystem = lib.mkForce false; };
  systemd.services.phpfpm-cobalt.serviceConfig = { ProtectHome = lib.mkForce false; PrivateTmp = lib.mkForce false; ProtectSystem = lib.mkForce false; };

  services.phpfpm.phpOptions = ''
    expose_php = On
    display_errors = Off
    error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
    log_errors = On
    variables_order = "GPCS"
    register_argc_argv = Off
    html_errors = Off
    max_input_time = 60
    short_open_tag = Off
  '';

  # ---- databases
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "127.0.0.1";
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_general_ci";
    };
    initialDatabases = [ { name = "amber"; } { name = "cobalt"; } ];
    initialScript = pkgs.writeText "mysql-init.sql" ''
      DROP DATABASE IF EXISTS test;
      CREATE USER 'amber'@'localhost' IDENTIFIED BY PASSWORD '*CE994D3F34F0502BC51156503AF81CDDB63F415E';
      CREATE USER 'cobalt'@'localhost' IDENTIFIED BY PASSWORD '*4E3F82FE2BB932A394FCFB9A3F056ACE68141483';
      GRANT ALL PRIVILEGES ON `amber`.* TO 'amber'@'localhost';
      GRANT ALL PRIVILEGES ON `cobalt`.* TO 'cobalt'@'localhost';
    '';
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = false;
    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
      password_encryption = "scram-sha-256";
    };
    initdbArgs = [ "--locale=C.UTF-8" "--encoding=UTF8" ];
    authentication = lib.mkForce ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    initialScript = pgScript;
  };

  services.memcached = {
    enable = true;
    user = "memcache";
    listen = "127.0.0.1";
    port = 11211;
    maxMemory = 32;
    extraOptions = [ "-U" "0" ];
  };

  services.logrotate.enable = true;
  services.logrotate.checkConfig = false;
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
    postrotate = "systemctl reload httpd > /dev/null 2>&1 || true";
  };
}
