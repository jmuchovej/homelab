# zerotier — control-plane overlay membership for real nodes.
#
# Companion to the tofu side (src/terraform/zerotier.tofu + mikrotik/zt-holonet):
# the network + relay members are managed in tofu; this aspect onboards
# NixOS/darwin NODES. Opt in by including `<rbn/services/zerotier>` in a host —
# there is no `host.zerotier.enable` flag (aspect inclusion IS the opt-in).
#
# NixOS uses nixpkgs `services.zerotierone`. darwin uses the official `zerotier-one`
# HOMEBREW cask (nixpkgs' darwin zerotierone lacks MacEthernetTapAgent, so its
# daemon can't bring up an interface); we still seed the sops identity + join via
# an activation script so the node id matches the tofu-authorized member.
#
# Declarative pre-authorization loop (mirrors the wg-holonet sops pattern):
#   1. Pre-generate the node identity OUT OF BAND, once:
#        zerotier-idtool generate identity.secret identity.public
#      The 10-hex address printed by `zerotier-idtool getpublic identity.secret`
#      is the node's stable ZeroTier address.
#   2. Store identity.secret in sops at key `zerotier.secret-key` in the host's
#      own file secrets/hosts/<hostname>.sops.yaml. Record the address in
#      src/topology.yaml (clients.<host>.zerotier).
#   3. Authorize it in tofu via a `zerotier_member` (member_id = that address,
#      ip_assignments = its holonet IP) so `nh os switch` joins it
#      already-approved with a pinned IP — no manual click in ZT Central.
#
# Prerequisites before a host includes this: `zerotier.network` set in
# src/topology.yaml (non-secret), and the sops key `zerotier.secret-key` (the
# node identity.secret) in secrets/hosts/<hostname>.sops.yaml.
{ inputs, ... }: {
  rbn.services._.zerotier = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        # Network id is a non-secret IDENTIFIER (topology.yaml), so it's usable
        # at build time for joinNetworks. Only the node identity is secret.
        topology = lib.rbn.from-yaml "${inputs.self}/src/topology.yaml" { inherit pkgs; };
        network = topology.zerotier.network;

        identity-key = "zerotier/secret-key";

        state-dir = "/var/lib/zerotier-one";
        identity = "${state-dir}/identity.secret";
        identity-id = config.sops.secrets.${identity-key}.path;
      in
      lib.mkMerge [
        # Only the node identity.secret comes from sops — key `zerotier.secret-key`
        # in the host's own secrets/hosts/<host>.sops.yaml.
        (lib.rbn.get-secret config identity-key "hosts/${host.hostname}")
        {
          sops.secrets.${identity-key} = {
            owner = "root";
            mode = "0400";
            restartUnits = [ "zerotierone.service" ];
          };

          services.zerotierone = {
            enable = true;
            joinNetworks = [ network ];
          };

          # Overlay interfaces are dynamically named (zt<8hex>); trust the
          # whole class so control-plane traffic to this node is accepted —
          # same posture as the tailscale0 interface.
          networking.firewall.trustedInterfaces = [ "zt+" ];

          # Seed the pre-generated identity BEFORE the daemon initialises, so
          # the node's address is deterministic (== what tofu pre-authorized).
          # Idempotent: only writes when the secret has no identity yet.
          systemd.services.zerotierone.preStart = ''
            install -d -m 0700 ${state-dir}
            if [ ! -f ${identity} ]; then
              install -m 0400 ${identity-id} ${identity}
              ${pkgs.zerotierone}/bin/zerotier-idtool getpublic ${identity} \
                > ${state-dir}/identity.public
              chmod 0644 ${state-dir}/identity.public
            fi
          '';
        }
      ];

    # darwin — the nixpkgs `zerotierone` package ships only the 3 bins, NOT the
    # `MacEthernetTapAgent` helper the macOS daemon needs to bring up a virtual
    # interface ("MacEthernetTapAgent not present in ZeroTier home"). So a pure
    # launchd + pkgs.zerotierone daemon can join but never route. Use the
    # official build via the `zerotier-one` homebrew cask (ships the tap agent +
    # its own `com.zerotier.one` launchd daemon). We still own the IDENTITY: an
    # activation script seeds the pre-generated key from sops (so the node id ==
    # the tofu-authorized member) and drops the network-join file, both before
    # the cask's daemon would otherwise generate a random identity.
    macos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        topology = lib.rbn.from-yaml (inputs.self + "/src/topology.yaml") { inherit pkgs; };
        network = topology.zerotier.network;

        identity-key = "zerotier/secret-key";
        identity-src = config.sops.secrets.${identity-key}.path;

        # ZeroTier's macOS home — where the official daemon reads identity/joins.
        home = "/Library/Application Support/ZeroTier/One";
      in
      lib.mkMerge [
        (lib.rbn.get-secret config identity-key "hosts/${host.hostname}")
        {
          sops.secrets.${identity-key} = {
            owner = "root";
            mode = "0400";
          };

          homebrew.casks = [ "zerotier-one" ];

          environment.systemPackages = [ pkgs.zerotierone ]; # zerotier-cli on PATH

          # Seed identity + join declaratively. Idempotent and guarded: only
          # writes the identity when absent (never clobbers a live one), and the
          # join file is a no-op once joined. Runs as root during activation.
          system.activationScripts.zerotier-identity.text = ''
            home="${home}"
            mkdir -p "$home/networks.d"
            if [ ! -f "$home/identity.secret" ] && [ -f "${identity-src}" ]; then
              install -m 0600 "${identity-src}" "$home/identity.secret"
              ${pkgs.zerotierone}/bin/zerotier-idtool getpublic "$home/identity.secret" \
                > "$home/identity.public"
            fi
            : > "$home/networks.d/${network}.conf"
          '';
        }
      ];
  };
}
