{ config, lib, pkgs, cx, ... }:
let
  tenants = [ "amber" "cobalt" ];
  hello = user: pkgs.writeText "hello-${user}.py" ''
    #!/usr/bin/python3
    print("Content-Type: text/plain\n")
    print("hello from ${user}")
  '';
  php = pkgs.php.buildEnv {
    extensions = { enabled, all }: lib.unique (enabled ++ [
      all.pgsql all.pdo_pgsql all.mysqli all.pdo_mysql all.mbstring
    ]);
  };
  pool = user: {
    inherit user;
    group = user;
    phpPackage = php;
    settings = {
      "listen.owner" = "web";
      "listen.group" = "web";
      "listen.mode" = "0660";
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
      "pm.max_requests" = 10000;
      "request_terminate_timeout" = 180;
      "clear_env" = "yes";
      "env[HOME]" = "/home/${user}";
      "env[PATH]" = "/usr/local/bin:/usr/bin:/bin";
      "env[TMP]" = "/tmp";
      "env[TMPDIR]" = "/tmp";
      "env[NODE_LABEL]" = user;
      "php_value[max_execution_time]" = 120;
      "php_value[memory_limit]" = "128M";
      "php_value[post_max_size]" = if user == "amber" then "2M" else "8M";
      "php_value[upload_max_filesize]" = if user == "amber" then "2M" else "8M";
      "php_admin_value[open_basedir]" = "/home/${user}/:/tmp/:/usr/share/php/";
      "php_flag[display_errors]" = "off";
    };
  };
  tenantConfig = user:
    let source = builtins.replaceStrings [ "@USER@" ] [ user ]
      (builtins.readFile ./tenant.conf);
    in builtins.replaceStrings
      [ "/run/php/php-${user}-fpm.sock" "SetHandler cgi-script" ]
      [ config.services.phpfpm.pools.${user}.socket
        "ProxyFCGIBackendType GENERIC\n    SetHandler \"proxy:unix:/run/cgi-${user}.sock|fcgi://localhost\"" ]
      source;
  modules = [ "mpm_event" "unixd" "authn_core" "authz_core" "authz_host"
    "authn_file" "auth_basic" "authz_user" "access_compat" "mime" "dir"
    "autoindex" "alias" "env" "setenvif" "log_config" "ssl" "socache_shmcb"
    "rewrite" "headers" "proxy" "proxy_fcgi" "userdir" "include" ];
  apache = pkgs.writeText "node-httpd.conf" (''
    ServerRoot /run/node-httpd
    DefaultRuntimeDir /run/node-httpd
    PidFile /run/node-httpd/httpd.pid
    Listen 0.0.0.0:80
    Listen 0.0.0.0:443
  '' + lib.concatMapStringsSep "\n" (name:
    "LoadModule ${name}_module ${pkgs.apacheHttpd}/modules/mod_${name}.so"
  ) modules + ''

    LoadModule wsgi_module ${pkgs.apacheHttpdPackages.mod_wsgi3}/modules/mod_wsgi.so
    WSGIPythonHome ${pkgs.python3}
    WSGISocketPrefix /run/node-httpd/wsgi
    User web
    Group web
    UserDir public_html
    UserDir disabled root
    ErrorLog /var/log/web/error.log
    TypesConfig ${pkgs.mailcap}/etc/mime.types
    DirectoryIndex index.html index.php
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    <Directory />
      AllowOverride None
      Require all denied
    </Directory>
    ${builtins.readFile ./main.conf}
    ${lib.concatMapStringsSep "\n" tenantConfig tenants}
  '');
  postgresInit = pkgs.writeText "node-postgres.sql" (lib.concatMapStringsSep "\n" (user: ''
    CREATE ROLE ${user} LOGIN PASSWORD '${user}-pass';
    CREATE DATABASE ${user} OWNER ${user};
    REVOKE CONNECT ON DATABASE ${user} FROM PUBLIC;
    \connect ${user}
    CREATE EXTENSION postgis;
    \connect postgres
  '') tenants + cx.postgresSql);
  cgiService = user: {
    serviceConfig = {
      ExecStart = "${pkgs.fcgiwrap}/sbin/fcgiwrap -f";
      User = user;
      Group = user;
      StandardInput = "socket";
    };
  };
  mysqlInit = pkgs.writeText "node-mysql.sql" (lib.concatMapStringsSep "\n" (user: ''
    CREATE DATABASE ${user};
    CREATE USER '${user}'@'localhost' IDENTIFIED BY '${user}-pass';
    GRANT ALL ON ${user}.* TO '${user}'@'localhost';
  '') tenants + cx.mysqlSql);
in {
  imports = [ ./complexify.nix ];
  networking.hostName = "node17";
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  networking.hosts."127.0.0.1" = [ "catalog.node.test" "sql.node.test" "cache.node.test" ];
  # Numeric ids match the reference so restored tenant data keeps its owners.
  users.groups = { amber.gid = 1000; cobalt.gid = 1001; web = {}; adm = {}; };
  users.users = lib.genAttrs tenants (user: {
    isNormalUser = true;
    uid = if user == "amber" then 1101 else 1102;
    home = "/home/${user}";
    createHome = true;
    group = user;
    shell = pkgs.bashInteractive;
  }) // { web = { isSystemUser = true; group = "web"; }; };
  environment.systemPackages = [ php config.services.postgresql.package pkgs.mariadb pkgs.memcached pkgs.acl ];
  systemd.slices."user-" = {
    overrideStrategy = "asDropin";
    sliceConfig = { MemoryHigh = "80%"; MemoryMax = "90%"; };
  };
  security.sudo = {
    enable = true;
    extraConfig = lib.concatMapStringsSep "\n" (user:
      "${user} ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/${user}-access.log, /bin/cat /var/log/web/${user}-error.log"
    ) tenants;
  };
  systemd.tmpfiles.rules = [
    "d /usr/bin 0755 root root -"
    "L+ /usr/bin/python3 - - - - ${pkgs.python3}/bin/python3"
    "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
  ];
  systemd.services.node-state = {
    wantedBy = [ "multi-user.target" ];
    before = [ "httpd.service" "phpfpm-amber.service" "phpfpm-cobalt.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    path = [ pkgs.coreutils ];
    script = ''
      install -d -m 0750 -o root -g adm /var/log/web
      install -d -m 0755 /srv/node
      test -e /srv/node/index.html || printf 'node service\n' > /srv/node/index.html
      ${lib.concatMapStringsSep "\n" (user: ''
        chmod 0755 /home/${user}
        for d in public_html public_html/cgi-bin public_html/wsgi-bin; do
          install -d -m 0755 -o ${user} -g ${user} /home/${user}/$d
        done
        install -d -m 0700 -o ${user} -g ${user} /home/${user}/private
        if [ ! -e /home/${user}/private/token ]; then
          printf '${user}-private\n' > /home/${user}/private/token
          chown ${user}:${user} /home/${user}/private/token
          chmod 0600 /home/${user}/private/token
        fi
        if [ ! -e /home/${user}/public_html/index.html ]; then
          printf '${user} workspace\n' > /home/${user}/public_html/index.html
          chown ${user}:${user} /home/${user}/public_html/index.html
        fi
        if [ ! -e /home/${user}/public_html/cgi-bin/hello.py ]; then
          install -m 0755 -o ${user} -g ${user} ${hello user} /home/${user}/public_html/cgi-bin/hello.py
        fi
        for kind in access error; do
          f=/var/log/web/${user}-$kind.log
          test -e "$f" || touch "$f"
          chown root:adm "$f"
          chmod 0640 "$f"
        done
      '') tenants}
    '';
  };
  services.phpfpm = { phpPackage = php; pools = lib.genAttrs tenants pool; };
  # NixOS pools default to ProtectHome; tenant docroots live under /home.
  systemd.services.phpfpm-amber.serviceConfig.ProtectHome = lib.mkForce false;
  systemd.services.phpfpm-cobalt.serviceConfig.ProtectHome = lib.mkForce false;
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    extensions = ps: [ ps.postgis ];
    authentication = lib.mkForce ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';
    settings = { listen_addresses = lib.mkForce "127.0.0.1"; password_encryption = "scram-sha-256"; };
    initialScript = postgresInit;
  };
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = mysqlInit;
    settings.mysqld.bind-address = "127.0.0.1";
  };
  systemd.services.memcached = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.memcached}/bin/memcached -m 32 -p 11211 -l 127.0.0.1 -U 0";
      DynamicUser = true;
    };
  };
  systemd.services.httpd = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "node-state.service" ];
    after = [ "node-state.service" "phpfpm-amber.service" "phpfpm-cobalt.service" "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      RuntimeDirectory = "node-httpd";
      ExecStart = "${pkgs.apacheHttpd}/bin/httpd -f ${apache} -DFOREGROUND";
      ExecReload = "${pkgs.apacheHttpd}/bin/httpd -f ${apache} -k graceful";
    };
  };
  # Nix uses per-user FastCGI sockets for CGI, preserving execution identity
  # without reproducing Ubuntu's distribution-specific suEXEC installation.
  systemd.sockets = lib.genAttrs (map (u: "cgi-${u}") tenants) (name:
    let user = lib.removePrefix "cgi-" name; in {
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "/run/${name}.sock";
        SocketUser = user;
        SocketGroup = "web";
        SocketMode = "0660";
      };
    });
  systemd.services.cgi-amber = cgiService "amber";
  systemd.services.cgi-cobalt = cgiService "cobalt";
}
