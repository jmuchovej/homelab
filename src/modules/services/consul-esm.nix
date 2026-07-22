# Consul External Service Monitor.
#
# Runs the health checks for agentless external nodes registered in the Consul
# catalog (relay01/02, hubitat — see src/terraform/consul/service-node). Those
# devices can't run a Consul agent, so nothing executes their checks; ESM
# claims any node tagged `external-node = "true"` in its meta and runs the
# http/tcp checks on its behalf, plus an ICMP node-health probe.
#
# Runs on every Consul server. Instances coordinate through a leader lock under
# the `consul-esm/` KV prefix, so exactly one is active and the rest are warm
# standbys — no per-host configuration needed.
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

        # Token is injected via CONSUL_HTTP_TOKEN (sops env file) rather than
        # the `token` config field, so it never lands in the Nix store. ESM's
        # ClientConfig() starts from api.DefaultConfig(), which reads that env
        # var, and only overrides when the config field is non-empty.
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
