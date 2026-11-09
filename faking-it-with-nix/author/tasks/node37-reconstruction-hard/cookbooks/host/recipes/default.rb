# Derived compute host: kernel command line, module and sysctl policy, custom sleep logic, a
# uv-style tool environment and a sandboxed metrics agent. Source mapping: provenance.md.

def unit(name, content)
  file "/etc/systemd/system/#{name}" do
    content content
    notifies :run, 'execute[daemon-reload]', :delayed
  end
end

execute 'daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Identity
%w[ember].each { |g| group(g) { gid 1000 } }
group('accel') { gid 992 }
group('i2c') { system true } # real host: gid 113, taken by the jammy base image
user 'ember' do
  uid 1000
  gid 1000
  home '/home/ember'
  manage_home true
  shell '/bin/bash'
end
%w[adm sudo video accel i2c].each do |g|
  group g do
    members ['ember']
    append true
    action :modify
  end
end
user 'probe' do
  system true
  shell '/usr/sbin/nologin'
  home '/var/lib/metrics-agent'
  manage_home false
end

file '/etc/hostname' do
  content "node37\n"
end
file '/etc/hosts' do
  content "127.0.0.1 localhost node37\n::1 localhost ip6-localhost\n"
end
link '/etc/localtime' do
  to '/usr/share/zoneinfo/America/Los_Angeles'
end
file('/etc/timezone') { content "America/Los_Angeles\n" }

# Kernel command line: cloud images set GRUB_CMDLINE_LINUX_DEFAULT in 50-cloudimg-settings.cfg,
# so the operator's additions are late drop-ins that append. Applied by update-grub at the end.
file '/etc/default/grub.d/60-node37.cfg' do
  content "GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE_LINUX_DEFAULT intel_iommu=on iommu=pt pcie_aspm=off\"\n"
end
file '/etc/default/grub.d/70-crashkernel.cfg' do
  content "GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE_LINUX_DEFAULT crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M\"\n"
end

# Modules
file '/etc/modprobe.d/node37-blacklist.conf' do
  content "blacklist joydev\n"
end
file '/etc/modprobe.d/node37-watchdog.conf' do
  content "options iTCO_wdt heartbeat=90\n"
end
file '/etc/modprobe.d/node37-hardening.conf' do
  content "# Vendor mitigation: blacklisting alone does not stop explicit loads, so install a failing command.\ninstall algif_aead /bin/false\n"
end

# Sysctl
file '/etc/sysctl.d/90-lockup.conf' do
  content <<~CONF
    # idle-freeze mitigation: NMI hardlockup escalates to panic -> crash dump -> reboot
    kernel.hardlockup_panic = 1
    # auto-reboot 30s after any panic
    kernel.panic = 30
    # deliberately NOT setting kernel.softlockup_panic
  CONF
end
file '/etc/sysctl.d/91-hung-task-recovery.conf' do
  content "kernel.hung_task_timeout_secs = 300\nkernel.hung_task_all_cpu_backtrace = 1\nkernel.hung_task_panic = 1\n"
end
execute('sysctl --system') { command 'sysctl --system >/dev/null' }

# Sleep policy
file '/etc/systemd/logind.conf' do
  content "[Login]\nIdleAction=suspend\nIdleActionSec=4h\n"
end
%w[hibernate hybrid-sleep].each do |t|
  link "/etc/systemd/system/#{t}.target" do
    to '/dev/null'
  end
end
directory '/etc/systemd/system/sleep.target.d'
file '/etc/systemd/system/sleep.target.d/accel-cleanup.conf' do
  content "[Unit]\nRequires=accel-sleep-cleanup.service\nAfter=accel-sleep-cleanup.service\n"
  notifies :run, 'execute[daemon-reload]', :delayed
end

# Fixture "hardware": the lab VM has no accelerators, so sysfs-shaped regular files stand in.
%w[0000:03:00.0 0000:87:00.0].each do |addr|
  %W[/var/lib/node37 /var/lib/node37/pci /var/lib/node37/pci/#{addr} /var/lib/node37/pci/#{addr}/power /var/lib/node37/pci/#{addr}/hwmon /var/lib/node37/pci/#{addr}/hwmon/hwmon0].each do |d|
    directory(d) { recursive true }
  end
  file("/var/lib/node37/pci/#{addr}/hwmon/hwmon0/power1_cap") { content "300000000\n" }
  file("/var/lib/node37/pci/#{addr}/power/control") { content "auto\n" }
  file("/var/lib/node37/pci/#{addr}/gpu_busy_percent") { content "0\n" }
end

{ 'accel-init.sh' => 'accel-init.sh', 'accel-sleep-cleanup.sh' => 'accel-sleep-cleanup.sh',
  'idle-suspend.sh' => 'idle-suspend.sh', 'lab-suspend' => 'lab-suspend' }.each do |dst, src|
  cookbook_file("/usr/local/bin/#{dst}") { source src; mode '0755' }
end

unit 'accel-setup.service', <<~UNIT
  [Unit]
  Description=Initialize accelerator power state and cap

  [Service]
  Type=oneshot
  Environment=PCI_SYSFS_ROOT=/var/lib/node37/pci
  ExecStart=/usr/local/bin/accel-init.sh
  RemainAfterExit=yes

  [Install]
  WantedBy=multi-user.target
UNIT
unit 'accel-sleep-cleanup.service', <<~UNIT
  [Unit]
  Description=Stop compute workloads before system sleep
  DefaultDependencies=no
  Before=sleep.target
  PartOf=sleep.target

  [Service]
  Type=oneshot
  Environment=PCI_SYSFS_ROOT=/var/lib/node37/pci
  ExecStart=/usr/local/bin/accel-sleep-cleanup.sh
  RemainAfterExit=yes
  ExecStop=/usr/local/bin/accel-init.sh
  TimeoutStartSec=90s
  TimeoutStopSec=30s
UNIT
unit 'idle-check.service', <<~UNIT
  [Unit]
  Description=Network and device idle monitor
  After=network.target

  [Service]
  Type=oneshot
  ExecStart=/usr/local/bin/idle-suspend.sh
  Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  Environment=PCI_SYSFS_ROOT=/var/lib/node37/pci
  Environment=SUSPEND_CMD=/usr/local/bin/lab-suspend
UNIT
unit 'idle-check.timer', <<~UNIT
  [Unit]
  Description=Run idle monitor every 5 minutes

  [Timer]
  OnBootSec=5min
  OnUnitActiveSec=5min
  Unit=idle-check.service

  [Install]
  WantedBy=timers.target
UNIT

# Tool environment (uv project layout; the venv itself is not materialised in the lab)
%w[/home/ember/accel-env /home/ember/accel-env/env /home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin /home/ember/infer].each do |d|
  directory(d) { owner 'ember'; group 'ember'; recursive true }
end
cookbook_file('/home/ember/accel-env/pyproject.toml') { source 'pyproject.toml'; owner 'ember'; group 'ember' }
cookbook_file('/home/ember/accel-env/env/activate.sh') { source 'activate.sh'; owner 'ember'; group 'ember'; mode '0755' }
cookbook_file('/home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin/accel-smi') do
  source 'accel-smi-real'
  owner 'ember'
  group 'ember'
  mode '0755'
end
file '/usr/local/bin/accel-smi' do
  mode '0755'
  content <<~SH
    #!/bin/sh
    # wrapper, not symlink: the tool finds its bindings relative to its real path
    exec /home/ember/accel-env/.venv/lib/python3/site-packages/_accel_sdk_devel/bin/accel-smi "$@"
  SH
end

# Inference service: installed, deliberately not enabled
directory '/opt/node37/bin' do
  recursive true
end
cookbook_file('/opt/node37/bin/infer-server') { source 'infer-server'; mode '0755' }
file '/etc/default/infer-server' do
  content <<~ENV
    INFER_WORKDIR=/home/ember/infer
    INFER_BIN=/opt/node37/bin/infer-server
    INFER_ARGS='--model lab-model --ctx 100000 --split 55,45 --host 192.0.2.83'
  ENV
end
unit 'infer-server.service', <<~UNIT
  [Unit]
  Description=Inference server
  After=network.target

  [Service]
  Type=simple
  User=ember
  Group=ember
  EnvironmentFile=/etc/default/infer-server
  ExecStart=/bin/bash -lc 'cd "$INFER_WORKDIR" && exec "$INFER_BIN" $INFER_ARGS'
  Restart=on-failure
  RestartSec=5
  LimitNOFILE=1048576

  [Install]
  WantedBy=multi-user.target
UNIT

# Metrics agent
directory('/opt/metrics-agent') { recursive true }
cookbook_file('/opt/metrics-agent/metrics-agent') { source 'metrics-agent'; mode '0755' }
unit 'metrics-agent.service', <<~UNIT
  [Unit]
  Description=Metrics agent
  Wants=network-online.target
  After=network-online.target

  [Service]
  Environment="PORT=45876"
  Environment="HUB_URL=https://hub.lab.invalid"
  ExecStart=/opt/metrics-agent/metrics-agent
  User=probe
  Restart=on-failure
  RestartSec=5
  StateDirectory=metrics-agent
  KeyringMode=private
  LockPersonality=yes
  ProtectClock=yes
  ProtectHome=read-only
  ProtectHostname=yes
  ProtectKernelLogs=yes
  ProtectSystem=strict
  RemoveIPC=yes
  RestrictSUIDSGID=true

  [Install]
  WantedBy=multi-user.target
UNIT
unit 'metrics-agent-update.service', <<~UNIT
  [Unit]
  Description=Update metrics agent if needed
  Wants=metrics-agent.service

  [Service]
  Type=oneshot
  ExecStart=/opt/metrics-agent/metrics-agent update
UNIT
unit 'metrics-agent-update.timer', <<~UNIT
  [Unit]
  Description=Run metrics agent update daily

  [Timer]
  OnCalendar=daily
  Persistent=true
  RandomizedDelaySec=4h

  [Install]
  WantedBy=timers.target
UNIT

file '/etc/udev/rules.d/60-i2c.rules' do
  content "KERNEL==\"i2c-[0-9]*\", GROUP=\"i2c\", MODE=\"0660\"\n"
end

file('/etc/default/sysstat') { content "ENABLED=\"true\"\n" }

execute 'daemon-reload-now' do
  command 'systemctl daemon-reload'
end
%w[accel-setup.service idle-check.timer metrics-agent.service metrics-agent-update.timer sysstat.service].each do |s|
  service(s) { action [:enable, :start] }
end
