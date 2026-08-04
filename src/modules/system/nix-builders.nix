# Nix remote builders over the lab LAN.
#
# Topology: the x86_64-linux servers form a full build mesh — each offloads to
# the others. da-n1x (aarch64-darwin) is a client-only consumer: it offloads
# x86_64-linux builds to every server and keeps its on-demand `linux-builder`
# VM (see system/nix.nix) as the away-from-home fallback. The servers carry a
# higher `speedFactor` than that VM (which defaults to 1), so real hardware
# wins whenever it's reachable.
#
# The mesh is derived from the den host registry (`den.hosts.<system>`) — the
# same source den itself enumerates — so adding/removing a host needs no edit
# here. `maxJobs` comes from each host's facter CPU report when one exists,
# else a default. `bootstrap` (the installer image) is excluded.
#
# Addressing: builders are reached over Tailscale at `<host>.tailcab76.ts.net`
# (MagicDNS). Tailscale selects the optimal path automatically — a direct LAN
# connection when da-n1x is home, a DERP/WAN relay when it's away — so the one
# address works everywhere. Tailscale is already enabled fleet-wide via
# <rbn/services/tailscale> and auto-authenticates from a sops pre-auth key;
# da-n1x (darwin) needs a one-time `tailscale up`. Host-key trust is wired up
# here directly (keyed to the MagicDNS name + bare hostname), rather than
# leaning on the fleet `programs.ssh.knownHosts` (sourced from a secrets dir
# mid-migration).
#
# Auth: each initiating host authenticates with its own SSH host key
# (`/etc/ssh/ssh_host_ed25519_key` — root-owned, already persisted and used
# for sops age decryption). The matching public keys live in
# `secrets/hosts/<host>.pub` and are installed into each builder's dedicated
# `nix-builder` account (already present in `trusted-users`; a non-root user
# is required because `services.openssh` sets `PermitRootLogin = "no"`).
{
  inputs,
  lib,
  den,
  ...
}:
let
  inherit (lib)
    fileContents
    listToAttrs
    concatMap
    filter
    ;

  # Tailscale MagicDNS suffix — builders are addressed as `<host>.${tailnet}`.
  tailnet = "tailcab76.ts.net";

  # Scaffolding hosts that are not real build participants.
  excluded = [ "bootstrap" ];
  keep = names: filter (n: !(builtins.elem n excluded)) names;

  # Auto-discovered from the den host registry — no hardcoded list and no
  # dependence on the still-stubbed `peers` specialArg.
  builder-names = keep (builtins.attrNames (den.hosts.x86_64-linux or { }));
  initiator-names = keep (concatMap builtins.attrNames (builtins.attrValues den.hosts));

  pub-of = host: fileContents "${inputs.self}/secrets/hosts/${host}.pub";

  # Concurrent build jobs: the host's physical core count from its facter
  # report when available, otherwise a conservative default.
  default-max-jobs = 6;
  max-jobs-for =
    host:
    let
      report = "${inputs.self}/src/modules/hosts/${host}/facter.json";
      cpus = (builtins.fromJSON (builtins.readFile report)).hardware.cpu or [ ];
    in
    if builtins.pathExists report && cpus != [ ] then
      (builtins.head cpus).cores or default-max-jobs
    else
      default-max-jobs;

  supported-features = [
    "kvm"
    "big-parallel"
    "nixos-test"
  ];

  mk-build-machine = name: {
    hostName = "${name}.${tailnet}";
    sshUser = "nix-builder";
    sshKey = "/etc/ssh/ssh_host_ed25519_key";
    systems = [ "x86_64-linux" ];
    maxJobs = max-jobs-for name;
    speedFactor = 2;
    supportedFeatures = supported-features;
  };

  # Trust a builder's host key under its MagicDNS name and bare hostname.
  mk-known-host = name: {
    name = "nix-builder-${name}";
    value = {
      publicKey = pub-of name;
      hostNames = [
        "${name}.${tailnet}"
        name
      ];
    };
  };
in
{
  rbn.system._.nix-builders = {
    # ── Client side ──────────────────────────────────────────────────
    # Every host dispatches to all builders except itself.
    os =
      { host, ... }:
      let
        others = filter (n: n != host.hostname) builder-names;
      in
      {
        nix.distributedBuilds = true;
        nix.buildMachines = map mk-build-machine others;

        programs.ssh.knownHosts = listToAttrs (map mk-known-host others);
      };

    # ── Builder side ─────────────────────────────────────────────────
    # Only the x86_64-linux servers run the `nix-builder` account, trusting
    # every other initiator's host key.
    nixos =
      { host, lib, ... }:
      lib.mkIf (builtins.elem host.hostname builder-names) {
        users.groups.nix-builder = { };
        users.users.nix-builder = {
          isNormalUser = true;
          group = "nix-builder";
          description = "Nix remote build user";
          # Local home, off the /home tree — on the builder hosts /home is an
          # NFS mount, and a service account must not depend on the NAS (nor
          # make activation mkdir a managed home over NFS). SSH keys land in
          # /etc/ssh/authorized_keys.d, so this home only needs to be writable.
          home = "/var/lib/nix-builder";
          createHome = true;
          openssh.authorizedKeys.keys = map pub-of (filter (h: h != host.hostname) initiator-names);
        };
      };
  };
}
