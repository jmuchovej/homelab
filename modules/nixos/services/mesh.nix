{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.mesh";
  description = "Service mesh with Consul, Traefik load balancing, and VIP failover";

  options =
    { cfg, lib, ... }:
    with lib.types;
    let
      inherit (lib.rebellion) mkopt mkopt-bool;
    in
    {
      # Consul cluster configuration (extends nixos services.consul)
      consul = {
        server = mkopt-bool false "Run as Consul server (vs client)";
        bootstrap-expect = mkopt int 3 "Number of servers to wait for before bootstrapping cluster";
        acl-enabled = mkopt-bool false "Enable ACLs";
        interface = mkopt str "enp1s0" "Network interface to bind VIP to";
      };

      # VIP failover configuration (extends nixos services.keepalived)
      vip = {
        address = mkopt str "10.69.1.1" "Virtual IP address for ingress";
        prefix = mkopt int 16 "Network prefix length (e.g., 16 for /16)";
        router-id = mkopt int 51 "VRRP router ID (must be same across all nodes)";
        priority = mkopt int 100 "VRRP priority (higher = preferred master)";
        preempt = mkopt-bool false "Whether higher priority node should reclaim VIP";
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      datacenter,
      hostname,
      nodename,
      peers,
      ...
    }:
    let

      # Generate retry-join list from datacenter peers
      # Append .${datacenter} domain suffix to each peer
      # retry-join-peers = map (p: "${p.nodename}.${datacenter}") peers;
      retry-join-peers = map (p: "${p.hostname}.lab") peers;
    in
    lib.mkMerge [
      {
        services.consul = {
          enable = true;
          webUi = true;

          # Use interface-based address detection
          # Consul will auto-detect IP from the specified interface
          interface = {
            bind = cfg.consul.interface; # Primary network interface
            advertise = cfg.consul.interface;
          };

          # Force IPv4 (since we're using 10.69.0.0/16)
          forceAddrFamily = "ipv4";

          extraConfig = {
            # Datacenter and node configuration
            datacenter = datacenter;
            node_name = hostname;

            # Server/Client configuration
            server = cfg.consul.server;
          }
          // (lib.optionalAttrs cfg.consul.server {
            bootstrap_expect = cfg.consul.bootstrap-expect;
          })
          // (lib.optionalAttrs (retry-join-peers != [ ]) {
            retry_join = retry-join-peers;
            retry_interval = "15s";
            retry_max = 0;
          })
          // {
            # Service Mesh (Consul Connect)
            connect = {
              enabled = true;
              ca_config = {
                rotation_period = "2160h"; # 90 days
              };
            };

            # Performance tuning
            performance = {
              raft_multiplier = 1;
              leave_drain_time = "5s";
            };

            # ACL configuration
            acl = {
              enabled = cfg.consul.acl-enabled;
              default_policy = if cfg.consul.acl-enabled then "deny" else "allow";
              enable_token_persistence = true;
            };

            # Service defaults
            enable_central_service_config = true;
          };
        };

        # DNS integration - use dnsmasq for Consul DNS forwarding
        # dnsmasq configuration is in modules/nixos/system/networking/dnsmasq.nix
        rebellion.system.networking.dns = "dnsmasq";

        rebellion.homelab.traefik = {
          enable = true;
          consul-integration = true;
        };

        services.keepalived =
          let
            inherit (lib) getExe getExe';
            curl = getExe pkgs.curl;
            bash = getExe pkgs.bash;
            systemd-cat = getExe' pkgs.systemd "systemd-cat";
          in
          {
            enable = true;
            openFirewall = true;
            enableScriptSecurity = true;

            vrrpScripts = {
              check_consul = {
                script = "${curl} -sf http://127.0.0.1:8500/v1/status/leader";
                interval = 2;
                timeout = 2;
                weight = 2;
                fall = 3;
                rise = 2;
              };

              check_traefik = {
                script = "${curl} -sf http://127.0.0.1:8080/ping";
                interval = 2;
                timeout = 2;
                weight = 2;
                fall = 3;
                rise = 2;
              };
            };

            vrrpInstances.mesh_ingress = {
              state = "BACKUP";
              interface = cfg.consul.interface;
              virtualRouterId = cfg.vip.router-id;
              priority = cfg.vip.priority;
              noPreempt = !cfg.vip.preempt;

              virtualIps = [
                {
                  addr = "${cfg.vip.address}/${toString cfg.vip.prefix}";
                  dev = cfg.consul.interface;
                }
              ];

              trackScripts = [
                "check_consul"
                "check_traefik"
              ];

              extraConfig = ''
                advert_int 1

                # Notify scripts for logging
                notify_master "${bash} -c 'echo \"[$(date)] ${hostname} became MASTER for VIP ${cfg.vip.address}\" | ${systemd-cat} -t keepalived -p info'"
                notify_backup "${bash} -c 'echo \"[$(date)] ${hostname} became BACKUP for VIP ${cfg.vip.address}\" | ${systemd-cat} -t keepalived -p info'"
                notify_fault  "${bash} -c 'echo \"[$(date)] ${hostname} entered FAULT state for VIP ${cfg.vip.address}\" | ${systemd-cat} -t keepalived -p err'"
              '';
            };

            extraGlobalDefs = ''
              router_id ${hostname}
              vrrp_version 3
              vrrp_garp_master_delay 1
              vrrp_garp_master_refresh 60
            '';
          };

        # Ensure keepalived starts after Traefik
        systemd.services.keepalived = {
          after = [ "traefik.service" ];
          wants = [ "traefik.service" ];
        };
      }
      (
        let
          inherit (lib.rebellion.network) with-consul mk-traefik-service mk-healthcheck;
          service = mk-traefik-service {
            inherit hostname datacenter;
            port = 8500;
            name = "consul";
            public = false;
          };
          healthcheck = mk-healthcheck service {
            route = "/v1/health/node/${hostname}";
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
          }
        )
      )
    ];
}
