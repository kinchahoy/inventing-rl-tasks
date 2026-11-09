{ config, lib, pkgs, ... }:
let
  operators = { birch = 1301; cedar = 1302; };
  soa = "2026110301 3600 600 86400 300";
  labSoa = "2026110301 3600 600 86400 7200";
  labZone = ''
    $ORIGIN a23.test.
    $TTL 300
    @ 7200 IN SOA ns1.a23.test. hostmaster.a23.test. ( ${labSoa} )
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
    ${lib.concatMapStringsSep "\n" (i: ''big IN TXT "${lib.concatStrings (lib.replicate 100 (toString i))}"'') (lib.range 1 8)}
  '';
  revZone = ''
    $ORIGIN 2.0.192.in-addr.arpa.
    $TTL 300
    @ IN SOA ns1.a23.test. hostmaster.a23.test. ( ${soa} )
    @ IN NS ns1.a23.test.
    10 IN PTR ns1.a23.test.
    11 IN PTR app1.a23.test.
    12 IN PTR app2.a23.test.
  '';
in {
  imports = [ ./complexify.nix ];
  networking.hostName = "node23";
  networking.firewall = { allowedTCPPorts = [ 22 53 853 ]; allowedUDPPorts = [ 53 ]; };
  networking.hosts."127.0.0.1" = [ "node23.n23.test" ];

  users.groups = lib.mapAttrs (_: gid: { inherit gid; }) operators;
  users.users = lib.mapAttrs (name: uid: {
    isNormalUser = true;
    inherit uid;
    group = name;
    home = "/home/${name}";
    shell = pkgs.bashInteractive;
  }) operators;

  security.sudo.extraConfig = ''
    birch ALL=(root) NOPASSWD: /usr/bin/rec_control wipe-cache *, /usr/bin/rec_control get *
    cedar ALL=(root) NOPASSWD: /usr/bin/rec_control get *
  '';
  systemd.tmpfiles.rules = [
    "d /usr/bin 0755 root root -"
    "L+ /usr/bin/rec_control - - - - ${pkgs.pdns-recursor}/bin/rec_control"
  ];

  # The harness installs the key root-only; dnsdist reads it as its own user.
  environment.etc."node23/server.key" = {
    mode = lib.mkForce "0640";
    group = "dnsdist";
  };
  environment.etc."powerdns/zones/i23.test.zone".text = ''
    $ORIGIN i23.test.
    $TTL 60
    @ IN SOA ns.i23.test. hostmaster.i23.test. 1 3600 600 86400 60
    @ IN NS ns.i23.test.
    ns IN A 10.9.0.1
    host1 IN A 10.9.0.5
  '';
  environment.etc."powerdns/extrarecursorhosts".text = ''
    10.20.30.40 svc.n23.test
    10.20.30.41 db.n23.test
  '';

  services.nsd = {
    enable = true;
    interfaces = [ "127.0.0.1" ];
    ipv6 = false;
    port = 5301;
    identity = "node23-auth";
    zones."a23.test".data = labZone;
    zones."2.0.192.in-addr.arpa".data = revZone;
  };

  # Settings follow PowerDNS Recursor 5 YAML names; the reference runs 4.6 with equivalent policy.
  services.pdns-recursor = {
    enable = true;
    dns.address = [ "127.0.0.1" ];
    dns.port = 5353;
    dns.allowFrom = [ "127.0.0.0/8" ];
    api.address = "127.0.0.1";
    api.port = 8082;
    api.allowFrom = [ "127.0.0.1" ];
    dnssecValidation = "off";
    exportHosts = true;
    forwardZones = {
      "a23.test" = "127.0.0.1:5301";
      "2.0.192.in-addr.arpa" = "127.0.0.1:5301";
    };
    settings = {
      recursor = {
        threads = 4;
        version_string = "anonymous";
        etc_hosts_file = "/etc/powerdns/extrarecursorhosts";
        auth_zones = [ { zone = "i23.test"; file = "/etc/powerdns/zones/i23.test.zone"; } ];
      };
      incoming = {
        reuseport = true;
        max_tcp_clients = 128;
        max_tcp_per_client = 100;
        tcp_timeout = 2;
      };
      outgoing.dont_query = [ "127.0.0.0/8" "!127.0.0.1" ];
      recordcache = { max_negative_ttl = 3600; max_ttl = 3600; };
      logging.quiet = true;
      webservice = { webserver = true; api_key = "lab-api-key"; };
    };
  };

  services.dnsdist = {
    enable = true;
    listenAddress = "0.0.0.0";
    listenPort = 53;
    extraConfig = ''
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
      webserver("127.0.0.1:8083")
      setWebserverConfig({password="lab-web-pass", apiKey="lab-api-key", acl="127.0.0.1"})
      setSecurityPollSuffix("")
    '';
  };
}
