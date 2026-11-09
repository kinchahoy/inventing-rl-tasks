# Oracle side of the complexifiers (author/complexify.md); the original recipe is replica.nix.
{ ... }: {
  # CX-db-role-limits: connection caps and a statement timeout per tenant role, a connection cap per SQL account.
  # STUDY: _module.args adds an extra argument to every module's function (here `cx`), so replica.nix can append this SQL
  # STUDY: to its initialScripts. Clean way to keep complexifier state separate from the recipe port.
  _module.args.cx = {
    postgresSql = ''
      ALTER ROLE amber CONNECTION LIMIT 20;
      # STUDY: Per-role setting stored in pg_db_role_setting, not in any file. Both Haiku and Opus copied CONNECTION LIMIT (visible in
      # STUDY: pg_roles) but missed this (visible only via `\drds` or `SHOW statement_timeout` as the role).
      ALTER ROLE amber SET statement_timeout = '30s';
      ALTER ROLE cobalt CONNECTION LIMIT 40;
      ALTER ROLE cobalt SET statement_timeout = '1min';
    '';
    mysqlSql = ''
      ALTER USER 'amber'@'localhost' WITH MAX_USER_CONNECTIONS 20;
      ALTER USER 'cobalt'@'localhost' WITH MAX_USER_CONNECTIONS 40;
    '';
  };

  # CX-sudo-decoy: nothing to reproduce; the staged grant is inactive on the reference.

  # CX-login-limits
  # STUDY: CX-login-limits: Chef created group `tenants` and /etc/security/limits.d/50-tenants.conf.
  users.groups.tenants.members = [ "amber" "cobalt" ];
  # STUDY: NixOS writes these into the PAM limits config; type "-" sets both soft and hard. Check `login_limits` runs `ulimit -Hu/-Hn` in a login shell.
  security.pam.loginLimits = [
    { domain = "@tenants"; type = "-"; item = "nproc"; value = "200"; }
    { domain = "@tenants"; type = "-"; item = "nofile"; value = "4096"; }
  ];

  # CX-log-rotation
  # STUDY: CX-log-rotation: one attrset per logrotate stanza; keys map 1:1 to logrotate directives. `create 0640 root adm` keeps sudo log access after rotation.
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
