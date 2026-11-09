# Complexifiers layered on the original recipe (default.rb). Catalogue: author/complexify.md.

# CX-sudo-decoy: a grant staged for approval. Inert: sudo's includedir skips names containing '.'.
file '/etc/sudoers.d/cobalt-deploy.disabled' do
  content "cobalt ALL=(root) NOPASSWD: /usr/bin/systemctl restart apache2\n"
  mode '0440'
end

# CX-login-limits: fork-bomb and descriptor guard for tenant login sessions (pam_limits).
group 'tenants' do
  members %w[amber cobalt]
end
file '/etc/security/limits.d/50-tenants.conf' do
  content "@tenants hard nproc 200\n@tenants soft nproc 200\n@tenants hard nofile 4096\n@tenants soft nofile 4096\n"
  mode '0644'
end

# CX-log-rotation: rotated logs keep root:adm 0640, so sudo log access survives rotation.
file '/etc/logrotate.d/web' do
  content <<~CONF
    /var/log/web/*.log {
        daily
        rotate 14
        dateext
        missingok
        notifempty
        compress
        delaycompress
        su root adm
        create 0640 root adm
        sharedscripts
        postrotate
            systemctl reload apache2 > /dev/null 2>&1 || true
        endscript
    }
  CONF
  mode '0644'
end

# CX-db-role-limits: noisy-neighbour guard on the shared databases. The state lives in the database catalogs,
# not in any file: connection caps and a statement timeout per tenant role (PostgreSQL), a connection cap per
# account (MariaDB).
{ 'amber' => [20, '30s'], 'cobalt' => [40, '1min'] }.each do |name, (limit, timeout)|
  execute "postgres-limits-#{name}" do
    command "runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c \"ALTER ROLE #{name} CONNECTION LIMIT #{limit}\" -c \"ALTER ROLE #{name} SET statement_timeout = '#{timeout}'\""
  end
  execute "sql-limits-#{name}" do
    command "mysql -e \"ALTER USER '#{name}'@'localhost' WITH MAX_USER_CONNECTIONS #{limit}\""
  end
end
