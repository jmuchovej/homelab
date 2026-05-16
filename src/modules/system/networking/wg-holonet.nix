# wg-holonet — WireGuard client config for the homelab cross-DC mesh.
# See plans/003-wg-holonet.md for the design and address scheme.
#
# Host opt-in: just import <rbn/system/networking/wg-holonet>. Everything
# else (this host's IP, the router's pubkey/endpoint, the private key) is
# derived from src/topology/holonet.yaml + secrets/holonet.sops.yaml.
#
#   imports = [ <rbn/system/networking/wg-holonet> ];
#
# The host must have an entry in `topology.clients.<hostname>` AND a private
# key in `secrets/holonet.sops.yaml` at `clients.<hostname>`.
#
# Both NixOS and nix-darwin use networking.wg-quick.interfaces — same shape,
# cross-platform.
{ lib, ... }:
{
  # ── Aspect ─────────────────────────────────────────────────────────
  rbn.system._.networking._.wg-holonet =
    let
      # YAML → JSON conversion via IFD. Yj is small; runs once per build and
      # caches in the store. Avoids forcing the catalog into JSON form.
      read-topology = _pkgs: lib.rbn.fs.from-yaml ../../../topology.yaml;

      # Build the wg-quick interface config — identical shape between NixOS
      # and nix-darwin since both expose `networking.wg-quick.interfaces`.
      #
      # Multi-peer: clients peer with EVERY publicly-routable relay
      # (*-relay01 by naming convention). Allowed-ips are partitioned —
      # each peer carries its own DC subnet, and the client's HOME relay
      # additionally carries the clients subnet (so client↔client
      # traffic transits through home, not through whichever direct
      # peer happens to have a fresher handshake).
      #
      # Today only da-relay01 is actually reachable; en-relay01 peer's
      # handshakes silently fail (CGNAT). When ISP delivers, the en peer
      # entry "just works" with zero edits here.
      #
      # Subnets come from topology.yaml (`subnets` top-level map) — same
      # source the tofu catalog reads. Mgmt is intentionally absent
      # (LAN-LOCAL per DC, not part of the mesh).
      mk-interface =
        {
          topology,
          host,
          privateKeyFile,
          lib,
        }:
        let
          inherit (lib)
            filterAttrs
            hasSuffix
            mapAttrsToList
            optional
            ;
          inherit (lib.strings) splitString;

          me = topology.clients.${host.hostname};

          # Convention: *-relay01 = publicly routable. Filter to just
          # those entries — the ones a client can actually peer with.
          publicRoutable = filterAttrs (k: _: hasSuffix "-relay01" k) topology.network;

          # Client's home DC = hostname prefix ("da-n1x" → "da").
          homeDc = builtins.head (splitString "-" host.hostname);

          mk-peer =
            relayName: relay:
            let
              relayDc = builtins.head (splitString "-" relayName);
              isHomeRelay = relayDc == homeDc;
            in
            {
              publicKey = relay.public;
              endpoint = "${relay.ddns}:51820";
              allowedIPs = [ topology.subnets.${relayDc} ] ++ optional isHomeRelay topology.subnets.clients;
              persistentKeepalive = 25;
            };
        in
        {
          address = [ "${me.ip}/32" ];
          inherit privateKeyFile;
          peers = mapAttrsToList mk-peer publicRoutable;
        };

      sops-key-for = host: "clients/${host.hostname}";
    in
    {
      nixos =
        {
          host,
          config,
          lib,
          pkgs,
          ...
        }:
        let
          inherit (lib) mkMerge;
          inherit (lib.rbn) get-secret;
          sops-key = sops-key-for host;
        in
        mkMerge [
          (get-secret config sops-key "holonet")
          {
            sops.secrets.${sops-key} = {
              owner = "root";
              mode = "0400";
              restartUnits = [ "wg-quick-wg-holonet.service" ];
            };

            networking.wg-quick.interfaces.wg-holonet = mk-interface {
              inherit host lib;
              topology = read-topology pkgs;
              privateKeyFile = config.sops.secrets.${sops-key}.path;
            };
          }
        ];

      darwin =
        {
          host,
          config,
          lib,
          pkgs,
          ...
        }:
        let
          inherit (lib) mkMerge;
          inherit (lib.rbn) get-secret;
          sops-key = sops-key-for host;
        in
        mkMerge [
          (get-secret config sops-key "holonet")
          {
            sops.secrets.${sops-key} = {
              owner = "root";
              mode = "0400";
              # No restartUnits — darwin wg-quick is launchd-driven and
              # sops-nix-darwin doesn't surface a reload hook for it. If
              # you rotate the key, manually: `sudo wg-quick down
              # wg-holonet && sudo wg-quick up wg-holonet`.
            };

            networking.wg-quick.interfaces.wg-holonet = mk-interface {
              inherit host lib;
              topology = read-topology pkgs;
              privateKeyFile = config.sops.secrets.${sops-key}.path;
            };
          }
        ];
    };
}
