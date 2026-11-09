# Derived mail host: exim4 MX/submission + Dovecot IMAP. Source mapping: provenance.md.

%w[fern moss].each_with_index do |name, i|
  group name do
    gid 1201 + i
  end
  user name do
    uid 1201 + i
    gid 1201 + i
    home "/home/#{name}"
    manage_home true
    shell '/bin/bash'
    password "#{name}-pass".crypt('$6$mailsalt$')
  end
  directory "/home/#{name}" do
    owner name
    group name
    mode '0700'
  end
end

file '/etc/mailname' do
  content "n29.test\n"
end

file '/etc/aliases' do
  content <<~ALIASES
    postmaster: fern
    abuse: fern
    root: fern
    team: fern, moss
  ALIASES
end

# Debian exim4 module convention (Wikimedia modules/exim4): a hand-written exim4.conf,
# update-exim4.conf disabled, combined daemon + queue runner, DKIM directory.
file '/etc/exim4/update-exim4.conf.conf' do
  content "dc_eximconfig_configtype='none'\n"
end

directory '/etc/exim4/dkim' do
  owner 'root'
  group 'Debian-exim'
  mode '0750'
end

execute 'dkim-key' do
  command 'openssl genrsa -out /etc/exim4/dkim/n29.test.key 2048 && chown root:Debian-exim /etc/exim4/dkim/n29.test.key && chmod 0640 /etc/exim4/dkim/n29.test.key'
  creates '/etc/exim4/dkim/n29.test.key'
end

execute 'tls-key-readable' do
  command 'chown root:Debian-exim /etc/node29/server.key && chmod 0640 /etc/node29/server.key'
end

file '/etc/exim4/exim4.conf' do
  content <<~'EXIM'
    # Derived from Wikimedia exim4.minimal.production.erb: loopback relay -> MX + submission.
    primary_hostname = node29.n29.test
    qualify_domain = n29.test
    domainlist local_domains = n29.test : node29.n29.test
    hostlist relay_from_hosts = 127.0.0.1 : ::1

    # Operator hook for site-local main options.
    .include_if_exists /etc/exim4/local-main.conf

    daemon_smtp_ports = 25 : 587
    local_interfaces = <; 0.0.0.0
    tls_certificate = /etc/node29/server.crt
    tls_privatekey = /etc/node29/server.key
    tls_advertise_hosts = *
    smtp_banner = $smtp_active_hostname ESMTP node29
    host_lookup =
    rfc1413_query_timeout = 0s
    message_size_limit = 25M
    check_spool_space = 50M
    remote_max_parallel = 10
    smtp_connect_backlog = 40
    smtp_accept_max = 40
    smtp_accept_max_per_host = 10
    ignore_bounce_errors_after = 0h
    message_logs = false
    add_environment = <; PATH=/bin:/usr/bin
    keep_environment =
    log_selector = +address_rewrite +all_parents +delivery_size +deliver_time +incoming_interface +incoming_port +smtp_confirmation +smtp_protocol_error +smtp_syntax_error
    acl_smtp_rcpt = acl_check_rcpt

    begin acl

    acl_check_rcpt:
      accept hosts = :
      deny   local_parts = ^[.] : ^.*[@%!/|]
      accept hosts = +relay_from_hosts
      accept authenticated = *
      accept domains = +local_domains
             endpass
             message = unknown user
             verify = recipient
      deny   message = relay not permitted

    .include_if_exists /etc/exim4/local-acl.conf

    begin routers

    legacy_app_mail:
      driver = redirect
      domains = +local_domains
      condition = ${if match{$h_X-Mailer:}{Legacy mailer}}
      data = :blackhole:

    system_aliases:
      driver = redirect
      domains = +local_domains
      data = ${lookup{$local_part}lsearch{/etc/aliases}}
      allow_fail
      allow_defer
      forbid_file
      forbid_pipe

    app_route:
      driver = manualroute
      domains = ! +local_domains
      condition = ${if match{$h_X-Mailer:}{Legacy mailer}}
      transport = remote_smtp
      route_list = * smarthost.n29.test::2527

    smart_route:
      driver = manualroute
      domains = ! +local_domains
      transport = remote_smtp
      route_list = * smarthost.n29.test::2526

    localuser:
      driver = accept
      domains = +local_domains
      check_local_user
      transport = local_delivery

    begin transports

    remote_smtp:
      driver = smtp
      hosts_avoid_tls = <; 0.0.0.0/0 ; 0::0/0
      dkim_domain = n29.test
      dkim_selector = mail
      dkim_private_key = /etc/exim4/dkim/n29.test.key

    local_delivery:
      driver = appendfile
      directory = $home/Maildir
      maildir_format
      create_directory
      directory_mode = 0700
      mode = 0600
      delivery_date_add
      envelope_to_add
      return_path_add

    begin retry

    smarthost.n29.test * F,2h,1m
    * * F,2h,5m; F,1d,15m

    begin rewrite

    *@node29.n29.test $1@n29.test Ffs

    begin authenticators

    dovecot_plain:
      driver = dovecot
      public_name = PLAIN
      server_socket = /var/run/dovecot/auth-client
      server_set_id = $auth1

    dovecot_login:
      driver = dovecot
      public_name = LOGIN
      server_socket = /var/run/dovecot/auth-client
      server_set_id = $auth1
  EXIM
  mode '0644'
  notifies :restart, 'service[exim4]'
end

file '/etc/default/exim4' do
  content "QUEUERUNNER='combined'\nQUEUEINTERVAL='5m'\nUPEX4OPTS=''\n"
end

# Module's paniclog rotation, shipped with the exim4 class.
file '/etc/logrotate.d/exim4-paniclog' do
  content "/var/log/exim4/paniclog {\n    daily\n    rotate 10\n    missingok\n    nocreate\n    notifempty\n    su Debian-exim adm\n}\n"
end

file '/etc/dovecot/conf.d/99-local.conf' do
  content <<~'DOVECOT'
    protocols = imap
    listen = *
    mail_location = maildir:~/Maildir
    first_valid_uid = 1000
    ssl = required
    ssl_cert = </etc/node29/server.crt
    ssl_key = </etc/node29/server.key
    ssl_min_protocol = TLSv1.2
    disable_plaintext_auth = yes
    auth_mechanisms = plain login
    login_greeting = Ready.
    namespace inbox {
      inbox = yes
      mailbox Drafts { special_use = \Drafts
        auto = subscribe }
      mailbox Sent { special_use = \Sent
        auto = subscribe }
      mailbox Trash { special_use = \Trash
        auto = subscribe }
      mailbox Junk { special_use = \Junk
        auto = subscribe }
    }
    service auth {
      unix_listener auth-client {
        mode = 0660
        user = Debian-exim
      }
    }
    service imap-login {
      inet_listener imap { port = 143 }
      inet_listener imaps { port = 993
        ssl = yes }
    }
  DOVECOT
  notifies :restart, 'service[dovecot]'
end

service 'exim4' do
  action %i[enable start]
end
service 'dovecot' do
  action %i[enable start]
end
