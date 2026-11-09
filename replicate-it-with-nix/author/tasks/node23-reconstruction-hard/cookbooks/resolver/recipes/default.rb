# Derived DNS resolver host: dnsdist front end -> PowerDNS Recursor -> NSD authoritative.
# Source mapping: provenance.md.

# Packages start the daemons on default ports; stop them so the configs below apply cleanly.
execute 'systemctl stop dnsdist pdns-recursor nsd || true'

{ 'birch' => 1301, 'cedar' => 1302 }.each do |name, id|
  group(name) { gid id }
  user name do
    uid id
    gid id
    home "/home/#{name}"
    manage_home true
    shell '/bin/bash'
  end
end

file '/etc/sudoers.d/dns-operators' do
  content <<~SUDO
    birch ALL=(root) NOPASSWD: /usr/bin/rec_control wipe-cache *, /usr/bin/rec_control get *
    cedar ALL=(root) NOPASSWD: /usr/bin/rec_control get *
  SUDO
  mode '0440'
end

# Port 53 on all addresses is dnsdist's; Ubuntu's resolved stub (127.0.0.53:53) would collide.
directory '/etc/systemd/resolved.conf.d'
file '/etc/systemd/resolved.conf.d/10-no-stub.conf' do
  content "[Resolve]\nDNSStubListener=no\n"
end
execute('systemctl restart systemd-resolved')

directory '/etc/nsd/zones' do
  owner 'root'
  group 'nsd'
  mode '0750'
end

file '/etc/nsd/zones/a23.test.zone' do
  content <<~ZONE
    $ORIGIN a23.test.
    $TTL 300
    @ 7200 IN SOA ns1.a23.test. hostmaster.a23.test. ( 2026110301 3600 600 86400 7200 )
    @ IN NS ns1.a23.test.
    ns1 IN A 192.0.2.10
    app1 IN A 192.0.2.11
    app2 IN A 192.0.2.12
    www IN CNAME app1
    @ IN MX 10 app1
    @ IN TXT "v=spf1 mx -all"
    _svc._tcp IN SRV 10 5 8443 app1
    blocked IN A 192.0.2.66
    long 7200 IN A 192.0.2.77
    *.wild IN A 192.0.2.99
    ext IN CNAME app2
    #{(1..8).map { |i| "big IN TXT \"#{(i.to_s * 100)}\"" }.join("\n")}
  ZONE
  group 'nsd'
  mode '0640'
end

file '/etc/nsd/zones/192.0.2.rev.zone' do
  content <<~ZONE
    $ORIGIN 2.0.192.in-addr.arpa.
    $TTL 300
    @ IN SOA ns1.a23.test. hostmaster.a23.test. ( 2026110301 3600 600 86400 300 )
    @ IN NS ns1.a23.test.
    10 IN PTR ns1.a23.test.
    11 IN PTR app1.a23.test.
    12 IN PTR app2.a23.test.
  ZONE
  group 'nsd'
  mode '0640'
end

file '/etc/nsd/nsd.conf' do
  content <<~NSD
    server:
      ip-address: 127.0.0.1@5301
      do-ip6: no
      hide-version: yes
      hide-identity: no
      identity: "node23-auth"
      zonesdir: "/etc/nsd/zones"
      database: ""
      verbosity: 0
    remote-control:
      control-enable: no
    zone:
      name: "a23.test"
      zonefile: "a23.test.zone"
    zone:
      name: "2.0.192.in-addr.arpa"
      zonefile: "192.0.2.rev.zone"
  NSD
  notifies :restart, 'service[nsd]'
end

# Locally authoritative zone served by the recursor itself (auth-zones), plus extra host records.
directory '/etc/powerdns/zones'
file '/etc/powerdns/zones/i23.test.zone' do
  content <<~ZONE
    $ORIGIN i23.test.
    $TTL 60
    @ IN SOA ns.i23.test. hostmaster.i23.test. 1 3600 600 86400 60
    @ IN NS ns.i23.test.
    ns IN A 10.9.0.1
    host1 IN A 10.9.0.5
  ZONE
end

file '/etc/powerdns/extrarecursorhosts' do
  content "10.20.30.40 svc.n23.test\n10.20.30.41 db.n23.test\n"
end

directory '/etc/powerdns/recursor.d'

# Settings after Wikimedia's dnsrecursor module defaults (dnssec off, 4 threads, TCP limits, ECS off).
file '/etc/powerdns/recursor.conf' do
  content <<~REC
    local-address=127.0.0.1
    local-port=5353
    allow-from=127.0.0.0/8
    setuid=pdns
    setgid=pdns
    threads=4
    reuseport=yes
    dnssec=off
    qname-minimization=no
    max-cache-entries=1000000
    max-cache-ttl=3600
    max-negative-ttl=3600
    max-tcp-clients=128
    max-tcp-per-client=100
    client-tcp-timeout=2
    dont-query=127.0.0.0/8,!127.0.0.1
    forward-zones=a23.test=127.0.0.1:5301,2.0.192.in-addr.arpa=127.0.0.1:5301
    auth-zones=i23.test=/etc/powerdns/zones/i23.test.zone
    export-etc-hosts=on
    etc-hosts-file=/etc/powerdns/extrarecursorhosts
    quiet=yes
    version-string=anonymous
    webserver=yes
    webserver-address=127.0.0.1
    webserver-port=8082
    webserver-allow-from=127.0.0.1
    api-key=lab-api-key
    include-dir=/etc/powerdns/recursor.d
  REC
  notifies :restart, 'service[pdns-recursor]'
end

execute 'chgrp _dnsdist /etc/node23/server.key && chmod 0640 /etc/node23/server.key'

# Wikidough-style front end after Wikimedia's dnsdist module: ACL, ANY/CHAOS refusal,
# per-client rate limit, packet cache, DNS-over-TLS, sinkhole suffix, loopback web API.
file '/etc/dnsdist/dnsdist.conf' do
  content <<~LUA
    setLocal("0.0.0.0:53", {reusePort=true})
    addTLSLocal("0.0.0.0:853", "/etc/node23/server.crt", "/etc/node23/server.key", {minTLSVersion="tls1.2"})
    setACL({"127.0.0.0/8", "10.0.0.0/8", "192.168.0.0/16"})
    newServer({address="127.0.0.1:5353", name="recursor"})
    setServerPolicy(leastOutstanding)
    getPool(""):setCache(newPacketCache(10000, {maxTTL=86400, minTTL=0, temporaryFailureTTL=60, staleTTL=60}))
    addAction(QTypeRule(DNSQType.ANY), RCodeAction(DNSRCode.REFUSED))
    addAction(QClassRule(DNSClass.CHAOS), RCodeAction(DNSRCode.REFUSED))
    sinkhole = newSuffixMatchNode()
    sinkhole:add("blocked.a23.test.")
    addAction(SuffixMatchNodeRule(sinkhole), RCodeAction(DNSRCode.NXDOMAIN))
    addAction(MaxQPSIPRule(50), DropAction())
    webserver("127.0.0.1:8083", "lab-web-pass", "lab-api-key", {}, "127.0.0.1")
    setSecurityPollSuffix("")
  LUA
  notifies :restart, 'service[dnsdist]'
end

execute 'systemctl reset-failed'
%w[nsd pdns-recursor dnsdist].each do |name|
  service(name) { action %i[enable start] }
end
