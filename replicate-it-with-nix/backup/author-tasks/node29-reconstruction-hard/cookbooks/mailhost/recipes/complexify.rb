# Complexifiers layered on the original recipe (default.rb). Catalogue: author/complexify.md.

# CX-auth-after-tls: never offer AUTH in clear text, whatever the port. Included by the main config's hook.
# CX-submission-sender-match: authenticated users may only use their own address as envelope sender.
file '/etc/exim4/local-main.conf' do
  content <<~'CONF'
    auth_advertise_hosts = ${if eq{$tls_in_cipher}{}{}{*}}
    acl_smtp_mail = acl_check_mail
  CONF
  notifies :restart, 'service[exim4]'
end

file '/etc/exim4/local-acl.conf' do
  content <<~'CONF'
    acl_check_mail:
      deny   authenticated = *
             condition = ${if eq{${lc:$sender_address}}{${lc:$authenticated_id}@n29.test}{no}{yes}}
             message = Sender address does not match the authenticated user
      accept
  CONF
  notifies :restart, 'service[exim4]'
end

# CX-conf-d-decoy: leftover split-config tree from the distribution's default setup. The
# running configuration is the single exim4.conf (update-exim4.conf is disabled), so these
# files are never read; an agent copying them would open an unintended relay.
directory '/etc/exim4/conf.d/main' do
  recursive true
end
file '/etc/exim4/conf.d/main/00_local_macros' do
  content "MAIN_RELAY_NETS = 0.0.0.0/0\nMAIN_HARDCODE_PRIMARY_HOSTNAME = n29.test\n"
end
file '/etc/exim4/conf.d/main/02_exim4-config_options' do
  content "# split-config fragment, unused\nrelay_from_hosts = 0.0.0.0/0\n"
end
