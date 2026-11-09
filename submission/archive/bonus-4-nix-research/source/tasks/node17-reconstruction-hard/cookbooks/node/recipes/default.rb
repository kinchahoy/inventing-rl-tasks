# Scoped, renamed adaptation; provenance retained outside the guest image.
%w[amber cobalt].each_with_index do |name, index|
  group name
  user name do
    uid 1101 + index
    gid name
    home "/home/#{name}"
    shell '/bin/bash'
    manage_home true
  end
  directory "/home/#{name}" do
    owner name
    group name
    mode '0755'
  end
  %w[public_html public_html/cgi-bin public_html/wsgi-bin private].each do |subdir|
    directory "/home/#{name}/#{subdir}" do
      owner name
      group name
      mode subdir == 'private' ? '0700' : '0755'
    end
  end
  file "/home/#{name}/private/token" do
    content "#{name}-private\n"
    owner name
    group name
    mode '0600'
  end
  file "/home/#{name}/public_html/index.html" do
    content "#{name} workspace\n"
    owner name
    group name
    mode '0644'
  end
  file "/home/#{name}/public_html/cgi-bin/hello.py" do
    content "#!/usr/bin/python3\nprint(\"Content-Type: text/plain\\n\")\nprint(\"hello from #{name}\")\n"
    owner name
    group name
    mode '0755'
  end
  template "/etc/php/8.1/fpm/pool.d/#{name}.conf" do
    source 'pool.erb'
    variables :user => name, :limit => index == 0 ? 2 : 8
  end
  template "/etc/apache2/sites-available/#{name}.conf" do
    source 'tenant.erb'
    variables :user => name
  end
  file "/etc/sudoers.d/#{name}" do
    content "#{name} ALL=(:adm) NOPASSWD: /bin/cat /var/log/web/#{name}-access.log, /bin/cat /var/log/web/#{name}-error.log\n"
    mode '0440'
  end
end
file '/etc/php/8.1/fpm/pool.d/www.conf' do
  action :delete
end
directory '/var/log/web' do
  owner 'root'
  group 'adm'
  mode '0750'
end
%w[amber cobalt].each do |name|
  %w[access error].each do |kind|
    file "/var/log/web/#{name}-#{kind}.log" do
      owner 'root'
      group 'adm'
      mode '0640'
    end
  end
end
directory '/srv/node' do
  mode '0755'
end
file '/srv/node/index.html' do
  content "node service\n"
end
template '/etc/apache2/sites-available/node.conf' do
  source 'main.erb'
end
execute 'enable-web-modules' do
  command 'a2enmod ssl rewrite headers proxy proxy_fcgi suexec userdir cgid wsgi && a2dissite 000-default && a2ensite node amber cobalt'
end
file '/etc/memcached.conf' do
  content "-d\nlogfile /var/log/memcached.log\n-m 32\n-p 11211\n-u memcache\n-l 127.0.0.1\n-U 0\n"
end
file '/etc/postgresql/14/main/pg_hba.conf' do
  content "local all all peer\nhost all all 127.0.0.1/32 scram-sha-256\nhost all all ::1/128 scram-sha-256\n"
end
file '/etc/postgresql/14/main/conf.d/node.conf' do
  content "listen_addresses = '127.0.0.1'\npassword_encryption = 'scram-sha-256'\n"
end
directory '/etc/systemd/system/user-.slice.d' do
  recursive true
end
file '/etc/systemd/system/user-.slice.d/50-node.conf' do
  content "[Slice]\nMemoryHigh=80%\nMemoryMax=90%\n"
end
execute 'reload-systemd' do
  command 'systemctl daemon-reload'
end
%w[php8.1-fpm postgresql mariadb memcached apache2].each do |name|
  service name do
    action [:enable, :restart]
  end
end
%w[amber cobalt].each do |name|
  execute "postgres-role-#{name}" do
    command "runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c \"CREATE ROLE #{name} LOGIN PASSWORD '#{name}-pass'\""
    not_if "runuser -u postgres -- psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='#{name}'\" | grep -q 1"
  end
  execute "postgres-database-#{name}" do
    command "runuser -u postgres -- createdb -O #{name} #{name}"
    not_if "runuser -u postgres -- psql -tAc \"SELECT 1 FROM pg_database WHERE datname='#{name}'\" | grep -q 1"
  end
  execute "postgres-access-#{name}" do
    command "runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c \"REVOKE CONNECT ON DATABASE #{name} FROM PUBLIC\" && runuser -u postgres -- psql -d #{name} -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS postgis'"
  end
  execute "sql-account-#{name}" do
    command "mysql -e \"CREATE DATABASE IF NOT EXISTS #{name}; CREATE USER IF NOT EXISTS '#{name}'@'localhost' IDENTIFIED BY '#{name}-pass'; GRANT ALL ON #{name}.* TO '#{name}'@'localhost';\""
  end
end
