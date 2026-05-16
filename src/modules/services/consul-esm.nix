{ inputs, ... }:
{
  rbn.services._.consul-esm = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib) mkIf;
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";

        cfg = host.consul;

        config-file = pkgs.writeText "consul-esm.hcl" ''
          log_level      = "INFO"
          consul_service = "consul-esm"
          consul_kv_path = "consul-esm/"
          datacenter     = "${datacenter}"
          http_addr      = "127.0.0.1:${toString cfg.ports.http}"

          # ICMP probe for node liveness — requires CAP_NET_RAW (below).
          ping_type = "udp"

          # Only manage nodes Terraform tagged as agentless externals.
          external_node_meta {
            external-node = "true"
          }

          node_probe_interval    = "10s"
          node_reconnect_timeout = "72h"
        '';
      in
      mkIf cfg.server {
        sops.secrets."consul/esm-token".sopsFile = sops-file datacenter;

        sops.templates."consul-esm.env" = {
          content = ''
            CONSUL_HTTP_TOKEN=${config.sops.placeholder."consul/esm-token"}
          '';
          owner = "consul";
        };

        systemd.services.consul-esm = {
          description = "Consul External Service Monitor";
          after = [ "consul.service" ];
          wants = [ "consul.service" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.contrib.consul-esm} agent -config-file=${config-file}";
            EnvironmentFile = config.sops.templates."consul-esm.env".path;
            User = "consul";
            Group = "consul";
            # ESM's node-health probe opens an ICMP socket.
            AmbientCapabilities = [ "CAP_NET_RAW" ];
            CapabilityBoundingSet = [ "CAP_NET_RAW" ];
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      };
  };
}
