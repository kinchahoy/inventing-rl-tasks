# Complexifiers layered on the original recipe (default.rb). Catalogue: author/complexify.md.

# CX-negative-ttl-override: a later drop-in lowers the negative-cache cap that recursor.conf sets; a stale
# package-upgrade leftover (not *.conf) is inert and must not be copied.
file '/etc/powerdns/recursor.d/50-ttl.conf' do
  content "max-negative-ttl=1800\n"
  notifies :restart, 'service[pdns-recursor]'
end
file '/etc/powerdns/recursor.d/60-legacy.conf.dpkg-old' do
  content "forward-zones-recurse=a23.test=192.0.2.250\nallow-from=0.0.0.0/0\nmax-negative-ttl=60\n"
end

# CX-local-resolver: the host resolves through its own resolver, with the zone as search domain.
service('systemd-resolved') { action %i[stop disable] }
file('/etc/resolv.conf') { action :delete }
file '/etc/resolv.conf' do
  content "nameserver 127.0.0.1\nsearch n23.test\n"
  mode '0644'
end

# CX-socket-tuning: larger UDP socket buffers, a wider ephemeral range and more descriptors.
file '/etc/sysctl.d/90-dns.conf' do
  content "net.core.rmem_max = 8388608\nnet.core.wmem_max = 8388608\nnet.ipv4.ip_local_port_range = 10240 65535\n"
end
execute('sysctl --system')
%w[pdns-recursor dnsdist].each do |unit|
  directory "/etc/systemd/system/#{unit}.service.d"
  file "/etc/systemd/system/#{unit}.service.d/limits.conf" do
    content "[Service]\nLimitNOFILE=65536\n"
  end
end
execute('systemctl daemon-reload && systemctl restart pdns-recursor dnsdist')

# CX-nsd-secondary: a secondary name server at 198.51.100.7 may transfer the lab zone; everyone else stays refused.
edit_resource!(:file, '/etc/nsd/nsd.conf') do
  content(content.sub(%(  zonefile: "a23.test.zone"\n), %(  zonefile: "a23.test.zone"\n  provide-xfr: 198.51.100.7 NOKEY\n)))
end
