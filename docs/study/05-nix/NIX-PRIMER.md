# Nix / NixOS primer for reading these submissions

Annotated copies in this folder (`# STUDY:` lines are mine):

| Folder | What | Score |
|---|---|---|
| `node17-oracle/` | reference solution (`replica.nix` + `complexify.nix` + Apache conf fragments) | 1.0 |
| `node37-oracle/` | reference solution + `files/` scripts | 1.0 |
| `node17-haiku-kLthoPm/` | best submitted Haiku node17 trial | 0.83 |
| `node17-opus-YWTivSs/` | Opus 5.5 node17 (side run, verifier v2) | 0.80 |
| `node23-haiku-tBuX9Qx/` | the one Haiku full solve (bonus task, DNS) | 1.0 |
| `HAIKU-VS-ORACLE-node17.md` | difference → failed check map | |

## 1. The language in ten lines

```nix
let
  x = 1;                          # binding
  s = "port ${toString x}";       # string interpolation; ${...} must be a string (or path/derivation)
  ml = ''                         # indented multi-line string; leading indentation stripped;
    echo ${s}                     #   '' inside it escapes ('''), ''${ is a literal ${
  '';
  f = user: "/home/${user}";      # lambda (one argument; curried for more)
  g = { name, uid ? 1000, ... }: uid;   # lambda taking an attrset; ? = default; ... = ignore extra keys
  set = { a = 1; b.c = 2; };      # attrset; b.c = 2 is sugar for b = { c = 2; }
  l = [ "amber" "cobalt" ];       # list (space-separated)
in set // { a = 3; }              # // = right-biased shallow merge
```

- Lazy and pure: nothing is evaluated until needed; no side effects in evaluation.
- Paths are a type: `./tenant.conf` is relative to the file; when interpolated (`"${./files/x}"`) the file
  is **copied into /nix/store** and the string becomes its store path. That is how a submission ships files.
- `builtins.readFile ./x` reads at eval time; `builtins.replaceStrings [from] [to] s` does templating.
- `inherit user;` = `user = user;`. `with pkgs; [ php curl ]` brings attrs into scope.
- `pkgs.writeText "name" "content"` → a derivation producing a file; `writeScript` (0555), `writeShellScriptBin "n" "..."`
  (a package with `bin/n`). These evaluate to store paths when interpolated.
- `lib` helpers you'll see: `lib.genAttrs [names] f`, `lib.concatMapStringsSep sep f list`, `lib.mkForce`,
  `lib.mkOverride N`, `lib.unique`, `lib.removePrefix`.
- A **derivation** is a build recipe; its output lives at `/nix/store/<hash>-<name>`. The whole NixOS
  system is one derivation whose closure contains every package, config file and unit.

## 2. Modules: options vs config

A NixOS module is a function returning an attrset:

```nix
{ config, lib, pkgs, modulesPath, ... }:   # args supplied by the module system
{
  imports = [ ./complexify.nix ];           # more modules to merge
  options = { ... };                        # declare new options (rare in submissions)
  config  = { networking.hostName = "node17"; ... };   # set options
}
```

If a module has no `options`/`config` keys, the whole attrset is treated as `config` (that's what every
submission here does). The module system evaluates **all** modules (the ~2000 in nixpkgs, `harness.nix`,
`replica.nix`, its imports) into one fixed point: `config` is the final merged result, which is why
modules can read `config.services.phpfpm.pools.amber.socket` set elsewhere.

Merging rules: lists concatenate; attrsets merge recursively; two different values for a scalar option
is an error **unless** priorities differ. Priorities: `lib.mkDefault` (1000) < normal (100) <
`lib.mkForce` (50); lower number wins. `lib.mkOverride 10` is stronger still. Every
`ProtectHome = lib.mkForce false` in these files exists because a nixpkgs module set the opposite at
normal priority.

Assertions: modules declare invariants (e.g. unique uids/gids). `check-replica` fails on them. Several
trajectories spend 1-3 minutes on "gid 4 already used by messagebus" because NixOS's static id table
differs from Ubuntu's (`adm` is gid 4 on Ubuntu).

`_module.args.cx = { ... }` (oracle `complexify.nix`) injects an extra function argument into every
module: a clean way to pass data between modules without declaring an option.

## 3. Options you will see

| Area | Options | Notes |
|---|---|---|
| Identity | `networking.hostName`, `networking.hosts."127.0.0.1" = [...]`, `time.timeZone` | hostName also names `run-<hostName>-vm` |
| Users | `users.users.<n> = { isNormalUser; uid; group; extraGroups; home; createHome; shell = pkgs.bashInteractive; hashedPassword; }`, `users.groups.<n> = { gid; members; }` | `isSystemUser` for daemons; `users.mutableUsers` default true |
| Sudo | `security.sudo.extraConfig` (raw sudoers text) or `security.sudo.extraRules = [{ users; runAs; commands = [{ command; options = ["NOPASSWD"]; }]; }]` | sudo matches the resolved command path; `/bin/cat` does not exist on NixOS |
| PAM | `security.pam.loginLimits = [{ domain = "@tenants"; type = "-"; item = "nproc"; value = "200"; }]` | `limits.d` equivalent |
| Env | `environment.systemPackages`, `environment.variables` (shell init), `environment.sessionVariables` (pam_env: all sessions) | `/etc/environment` is not read by NixOS; node37 CX |
| Files in /etc | `environment.etc."path".text` / `.source` / `.mode` | Default: symlink into the read-only store; `mode = "0600"` makes a copy. A read-only store link under `/etc/systemd/system/*.d/` broke one build in the verifier (author/timeline.md 13:03) |
| Other files | `systemd.tmpfiles.rules = [ "d /var/log/web 0750 root adm -" "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat" "f path 0644 u g - content" "C+ dst - - - - ${./src}" ]` | runs at boot; `d` dir, `f` file if absent, `L+` force symlink, `C+` copy. Refuses unsafe ownership chains (node37 trace step 56) |
| Activation | `system.activationScripts.<n> = { deps = [...]; text = "..."; }` | runs on every boot/switch before services; imperative escape hatch |
| systemd | `systemd.services.<n> = { description; wantedBy; after; requires; path = [pkgs...]; environment = {...}; script = "..."; serviceConfig = {...}; unitConfig = {...}; }` | `script` becomes ExecStart; `serviceConfig` keys are verbatim `[Service]` keys |
| | `systemd.sockets.<n>`, `systemd.timers.<n>.timerConfig`, `systemd.targets.<n>`, `systemd.slices."user-" = { overrideStrategy = "asDropin"; sliceConfig = {...}; }` | `.enable = false` masks a unit; `asDropin` writes a drop-in instead of a full unit |
| Kernel | `boot.kernelParams`, `boot.kernel.sysctl`, `boot.blacklistedKernelModules`, `boot.extraModprobeConfig` | |
| udev / logind | `services.udev.extraRules`, `services.logind.settings.Login` | |
| Services | `services.postgresql`, `services.mysql`, `services.phpfpm.pools.<n>`, `services.memcached`, `services.httpd`, `services.nginx`, `services.prometheus{,.alertmanager,.exporters.*}`, `services.logrotate.settings.<n>`, `services.sysstat`, `services.openssh` | see below |

### Service modules: what they do and where they bite

A `services.X` module turns options into packages + config files + systemd units. Its opinions are where
Ubuntu-vs-NixOS gaps hide:

- `services.phpfpm.pools.<n>`: unit `phpfpm-<n>`, socket path chosen by the module (read it from
  `config.services.phpfpm.pools.<n>.socket`), **`ProtectHome = true`** → PHP can't read `/home` docroots.
- `services.postgresql`: `ensureDatabases`/`ensureUsers` reconcile on every boot; `initialScript` runs
  only when the data dir is first created (so test from a fresh disk!). `authentication` = pg_hba.conf;
  `extensions = ps: [ ps.postgis ]` installs PostGIS on the server but does **not** `CREATE EXTENSION` in
  any database (Opus's `postgis` miss).
- `services.httpd`: Type=forking, waits for its own PID file. Overriding `PidFile` in a hand-written
  config makes the unit never "start" (v1 boot race, `07-evidence/final-scores.md`). Oracle, Haiku and
  Opus all hand-rolled an Apache unit with `-DFOREGROUND` instead.
- `services.nginx`: runs the whole service as the nginx user with a seccomp filter and a capability
  bounding set; reading a root-only key needs `LoadCredential` (node31 trace, steps 52-79).
- `services.prometheus.alertmanager`: runs the daemon; does **not** put `amtool` on users' PATH. Ubuntu's
  package does. The canonical "Nix mental-model" miss (`07-evidence/missed-items.md`).

## 4. The harness module and how build-replica builds

`/opt/contract/harness.nix` (copy in `04-harness/author/tasks/node17-reconstruction-hard/public/`):

```nix
{ modulesPath, pkgs, ... }: {
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];   # turns the config into a runnable VM
  system.stateVersion = "26.05";
  services.openssh = { enable = true; settings.PermitRootLogin = "prohibit-password"; };
  users.users.root.openssh.authorizedKeys.keys = [ (builtins.readFile ./id_ed25519.pub) ];
  environment.etc."node/server.key" = { source = ./server.key; mode = "0600"; };
  virtualisation = { memorySize = 3072; cores = 2; diskSize = 8192; graphics = false;
                     qemu.options = [ "-cpu host" ];
                     forwardPorts = [ { from = "host"; host.port = 3222; guest.port = 22; } ... ]; };
}
```

`qemu-vm.nix` provides `config.system.build.vm`: a script `bin/run-<hostname>-vm` that boots the
system's kernel/initrd with the host's `/nix/store` shared read-only into the guest (9p/virtiofs) and a
writable `<hostname>.qcow2` created in the current directory for `/`. Consequences: builds are fast (no
disk image to assemble), the VM's `/var`, `/home` start empty on a fresh qcow2, and the module replaces
`fileSystems` (node41 trap: extra mounts go under `virtualisation.fileSystems`).

Build path:

```
build-replica → nix build --file /opt/contract/build.nix --argstr submission /app/submission --argstr nixpkgs /opt/nixpkgs
  build.nix → import <nixpkgs>/nixos/lib/eval-config.nix { system = "x86_64-linux"; modules = [ harness.nix replica.nix ]; }
           → .config.system.build.vm
  restrict-eval + allowed-uris "" + -I {submission, /opt/contract, /nix/store}: only those paths readable, no URLs
  agent: builds locally as nixbld users; verifier: --max-jobs 0 --builders ssh-ng://buildclient@builder (sandboxed)
  → /app/replica-vm → /nix/store/...-nixos-vm/bin/run-node17-vm
```

## 5. Ubuntu → NixOS translation table (the recurring traps)

| On Ubuntu | On NixOS | Seen in |
|---|---|---|
| `/bin/cat`, `/usr/bin/python3` exist | they don't (`/usr/bin` may not exist); create with tmpfiles `L+` | node17 sudo, CGI shebang |
| `#!/usr/bin/env bash` works in units | unit PATH is minimal; use `path = [ pkgs.bash ... ]` or store-path shebangs | node37 trace step 36 |
| `/etc/sudoers.d/x` | `security.sudo.extraConfig`/`extraRules`; command paths resolve to `/run/current-system/sw/bin/...` | node17, node23 |
| `/etc/security/limits.d/*` | `security.pam.loginLimits` | login_limits |
| `/etc/logrotate.d/*` | `services.logrotate.settings.<name>` | log_rotation |
| `/etc/systemd/system/user-.slice.d/*.conf` | `systemd.slices."user-"` with `overrideStrategy = "asDropin"` | slice_limits |
| `/etc/environment` (pam_env) | `environment.sessionVariables` | etc_environment |
| `/etc/udev/rules.d/*` | `services.udev.extraRules` | udev_i2c |
| `/etc/default/grub.d/*.cfg` | `boot.kernelParams` | kernel_cmdline |
| `ln -s /dev/null /etc/systemd/system/x.target` | `systemd.targets.x.enable = false` | sleep_policy |
| package puts CLI on PATH (`amtool`, `promtool`, `htpasswd`) | add to `environment.systemPackages` explicitly (`prometheus.cli`, `apacheHttpd`) | operator_tools, amtool_operator |
| suexec + userdir: CGI runs as tenant | no suexec in stock nixpkgs Apache; per-tenant fcgiwrap socket (oracle) | cgi_identity |
| gids from Debian's table (`adm` 4, `sudo` 27) | NixOS static ids collide (`messagebus` 4, `dialout` 27) | every trace |
| config edits persist on disk | `/etc` regenerated each boot from the store | general |
| DB state created once by Chef `execute` | `initialScript` (first init) or a oneshot after `postgresql.service` | postgres_isolation, db_role_limits |
