# Derived small file server: Samba shares (one on a Btrfs RAID1 over two USB disks, mounted by automount) with forced identity, setgid share trees, a vetoed nested
# share, forwarding sysctl and a power-tuning oneshot. Source mapping: provenance.md.

execute 'daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Identity. Share accounts use fixed ids; the operator owns every share tree.
{ 'quill' => 1000, 'rowan' => 1001, 'sage' => 1002, 'visitor' => 1004 }.each do |name, id|
  group(name) { gid id }
end
group('shared') { gid 1003 }
{ 'quill' => 1000, 'rowan' => 1001, 'sage' => 1002, 'visitor' => 1004 }.each do |name, id|
  user name do
    uid id
    gid id
    home "/home/#{name}"
    manage_home true
    shell '/bin/bash'
  end
end
group 'shared' do
  members %w[quill rowan sage]
  append true
  action :modify
end

file('/etc/hostname') { content "node41\n" }
file '/etc/hosts' do
  content "127.0.0.1 localhost node41\n::1 localhost ip6-localhost\n"
end
link('/etc/localtime') { to '/usr/share/zoneinfo/America/Los_Angeles' }
file('/etc/timezone') { content "America/Los_Angeles\n" }

# Share trees: setgid, group-writable, owned by the operator. `docs` contains the `vault` tree,
# which is served by its own share and hidden from `docs` by a veto.
%w[/srv/fast /srv/docs /srv/docs/vault].each do |dir|
  directory dir do
    owner 'quill'
    group 'shared'
    mode '2775'
    recursive true
  end
end

# Bulk storage: the two USB disks form a Btrfs RAID1 (label `pool`), mounted on first access.
# The share tree lives on the array, so it exists only once the array is mounted.
directory '/mnt/pool'
bash 'create-array' do
  code <<~SH
    set -euo pipefail
    devs=$(lsblk -dnpo NAME,TRAN | awk '$2=="usb"{print $1}')
    [ "$(echo "$devs" | wc -l)" = 2 ]
    mkfs.btrfs -f -L pool -m raid1 -d raid1 $devs
    mount LABEL=pool /mnt/pool
    btrfs subvolume create /mnt/pool/data
    umount /mnt/pool
  SH
  not_if 'blkid -L pool'
end
bash 'array-fstab' do
  code <<~SH
    echo 'LABEL=pool /mnt/pool btrfs nofail,noatime,compress=zstd:3,subvol=data,x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.mount-timeout=30s 0 0' >> /etc/fstab
  SH
  not_if 'grep -q "^LABEL=pool " /etc/fstab'
  notifies :run, 'execute[daemon-reload]', :immediately
end
execute 'systemctl start mnt-pool.automount'
directory '/mnt/pool/bulk' do
  owner 'quill'
  group 'shared'
  mode '2775'
end

share_common = <<~SHARE
  valid users = @shared
  force user = quill
  force group = shared
  read only = no
  create mask = 0660
  force create mode = 0660
  directory mask = 2770
  force directory mode = 2770
SHARE

file '/etc/samba/smb.conf' do
  content <<~CONF
    [global]
    security = user
    server min protocol = SMB3
    server signing = auto
    server multi channel support = yes
    map to guest = never
    usershare max shares = 0
    hosts allow = 127.0.0.1 192.0.2.0/24 100.64.0.0/10
    hosts deny = 0.0.0.0/0
    vfs objects = catia fruit streams_xattr
    fruit:aapl = yes
    fruit:metadata = stream
    fruit:resource = file
    fruit:encoding = native
    fruit:nfs_aces = no
    fruit:zero_file_id = yes

    [fast]
    path = /srv/fast
    #{share_common.rstrip}

    [docs]
    path = /srv/docs
    #{share_common.rstrip}
    veto files = /vault/
    delete veto files = no

    [vault]
    path = /srv/docs/vault
    #{share_common.rstrip}
    fruit:time machine = yes

    [bulk]
    path = /mnt/pool/bulk
    #{share_common.rstrip}
  CONF
  notifies :restart, 'service[smbd]', :delayed
  notifies :restart, 'service[nmbd]', :delayed
end

service('smbd') { action %i[enable start] }
service('nmbd') { action %i[enable start] }

# Routing sysctls.
file '/etc/sysctl.d/99-forwarding.conf' do
  content "net.ipv4.ip_forward=1\nnet.ipv6.conf.all.forwarding=1\n"
  notifies :run, 'execute[sysctl-system]', :immediately
end
execute 'sysctl-system' do
  command 'sysctl --system'
  action :nothing
end

# Power tuning applied once at boot. Enabled only: powertop is not expected to succeed in a VM.
file '/etc/systemd/system/powertop.service' do
  content <<~UNIT
    [Unit]
    Description=Power tuning

    [Service]
    Type=oneshot
    ExecStart=/usr/sbin/powertop --auto-tune
    RemainAfterExit=true

    [Install]
    WantedBy=multi-user.target
  UNIT
  notifies :run, 'execute[daemon-reload]', :immediately
end
service('powertop') { action :enable }
