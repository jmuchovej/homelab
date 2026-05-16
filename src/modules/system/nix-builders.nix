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
          openssh.authorizedKeys.keys = map pub-of (filter (h: h != host.hostname) initiator-names);
        };
      };
  };
}
