# Complexifiers layered on the original recipe (default.rb). Catalogue: author/complexify.md.

# CX-cmdline-decoy: an abandoned experiment profile. Only *.cfg is sourced, so it is inert.
file '/etc/default/grub.d/99-experiment.cfg.disabled' do
  content "# profile: experiment-07\nGRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE_LINUX_DEFAULT pci=noats pci=realloc nomodeset\"\n"
end

# CX-sysctl-decoy: package-upgrade leftovers are not read by systemd-sysctl.
file '/etc/sysctl.d/93-swap-late.conf.dpkg-old' do
  content "vm.swappiness = 100\nkernel.panic = 0\n"
end

# CX-script-backup: dated previous versions with other caps sit next to the live script.
file '/usr/local/bin/accel-init.sh.pre-200w-20260815' do
  mode '0755'
  content "#!/usr/bin/env bash\n# previous caps (200 W / 170 W), superseded\nexit 1\n"
end

# CX-timer-reset: sysstat's collection interval is shortened with a list-reset drop-in.
directory '/etc/systemd/system/sysstat-collect.timer.d'
file '/etc/systemd/system/sysstat-collect.timer.d/override.conf' do
  content "[Timer]\nOnCalendar=\nOnCalendar=*-*-* *:*:00\n"
  notifies :run, 'execute[daemon-reload-cx]', :immediately
end
execute 'daemon-reload-cx' do
  command 'systemctl daemon-reload && systemctl restart sysstat-collect.timer'
  action :nothing
end

# CX-etc-environment: fleet-wide device selection for every session. Ubuntu's pam_env reads /etc/environment for
# ssh (interactive or not), su and login sessions; NixOS does not read this file.
%w[ACCEL_VISIBLE_DEVICES=0,1 OMP_NUM_THREADS=8].each do |entry|
  execute "etc-environment-#{entry.split('=').first}" do
    command "echo '#{entry}' >> /etc/environment"
    not_if "grep -qx '#{entry}' /etc/environment"
  end
end
