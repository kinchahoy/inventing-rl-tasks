# Oracle side of the complexifiers (author/complexify.md); the original recipe is replica.nix.
{ ... }: {
  # CX-db-role-limits: connection caps and a statement timeout per tenant role, a connection cap per SQL account.
  _module.args.cx = {
    postgresSql = ''
      ALTER ROLE amber CONNECTION LIMIT 20;
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
  users.groups.tenants.members = [ "amber" "cobalt" ];
  security.pam.loginLimits = [
    { domain = "@tenants"; type = "-"; item = "nproc"; value = "200"; }
    { domain = "@tenants"; type = "-"; item = "nofile"; value = "4096"; }
  ];

  # CX-log-rotation
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
