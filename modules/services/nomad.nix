_: {
  # ── Host schema: nomad options ─────────────────────────────────────
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkEnableOption mkOption;
      inherit (lib.types)
        str
        int
        port
        listOf
        bool
        ;
    in
    {
      options.nomad = {
        enable = mkEnableOption "Nomad job scheduler";
        datacenter = mkOption {
          type = str;
          default = "da";
        };
        region = mkOption {
          type = str;
          default = "da";
        };
        server = mkOption {
          type = bool;
          default = false;
        };
        client = mkOption {
          type = bool;
          default = true;
        };
        bootstrap-expect = mkOption {
          type = int;
          default = 3;
        };
        ui = mkOption {
          type = bool;
          default = true;
        };
        interface = mkOption {
          type = str;
          default = "enp1s0";
        };
        consul = {
          enable = mkOption {
            type = bool;
            default = true;
          };
          address = mkOption {
            type = str;
            default = "127.0.0.1:8500";
          };
        };
        volumes = mkOption {
          type = listOf str;
          default = [ ];
        };
        ports = {
          http = mkOption {
            type = port;
            default = 4646;
          };
          rpc = mkOption {
            type = port;
            default = 4647;
          };
          serf = mkOption {
            type = port;
            default = 4648;
          };
        };
      };
    };

  # ── Aspect ─────────────────────────────────────────────────────────
  rbn.services._.nomad.nixos =
    {
      host,
      config,
      lib,
      pkgs,
      peers,
      ...
    }:
    let
      inherit (lib) mkIf optional;
      inherit (lib.strings) concatMapStringsSep;
      inherit (lib.rebellion.network)
        with-consul
        mk-traefik-service
        mk-healthcheck
        ;
      inherit (host) hostname datacenter;

      cfg = host.nomad;

      retry-join-peers = map (p: "${p.hostname}.node.consul") peers;

      host-volumes = concatMapStringsSep "\n" (vol: ''
        host_volume "${baseNameOf vol}" {
          path = "${vol}"
          read_only = false
        }
      '') cfg.volumes;
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          environment.systemPackages = [ pkgs.nomad ];

          # containers included via host aspect (<rbn/containers>)

          services.nomad = {
            enable = true;
            package = pkgs.nomad;
            dropPrivileges = false;
            enableDocker = false;

            extraPackages = with pkgs; [
              cni-plugins
              consul
              nomad-driver-podman
            ];

            settings = {
              inherit (cfg) datacenter region;
              data_dir = "/var/lib/nomad";
              log_level = "INFO";

              bind_addr = "0.0.0.0";

              advertise = {
                http = "{{ GetInterfaceIP \"${cfg.interface}\" }}";
                rpc = "{{ GetInterfaceIP \"${cfg.interface}\" }}";
                serf = "{{ GetInterfaceIP \"${cfg.interface}\" }}";
              };

              ports = {
                inherit (cfg.ports) http rpc serf;
              };

              server = mkIf cfg.server {
                enabled = true;
                bootstrap_expect = cfg.bootstrap-expect;

                server_join = mkIf (retry-join-peers != [ ]) {
                  retry_join = retry-join-peers;
                  retry_interval = "15s";
                  retry_max = 0;
                };

                default_scheduler_config = {
                  scheduler_algorithm = "binpack";
                  memory_oversubscription_enabled = true;
                  preemption_config = {
                    batch_scheduler_enabled = true;
                    system_scheduler_enabled = true;
                    service_scheduler_enabled = false;
                  };
                };
              };

              client = mkIf cfg.client {
                enabled = true;
                network_interface = cfg.interface;
                node_class = "compute";

                reserved = {
                  cpu = 500;
                  memory = 1024;
                };

                cni_path = "${pkgs.cni-plugins}/bin";
              };

              consul = mkIf cfg.consul.enable {
                inherit (cfg.consul) address;
                server_service_name = "nomad";
                client_service_name = "nomad-client";
                auto_advertise = true;
                server_auto_join = true;
                client_auto_join = true;

                service_identity = {
                  aud = [ "consul.io" ];
                  ttl = "1h";
                };
              };

              ui = {
                enabled = cfg.ui;
                consul = mkIf cfg.consul.enable {
                  ui_url = "https://consul.${datacenter}.jm0.io";
                };
              };

              plugin = {
                nomad-driver-podman.config = {
                  socket_path = "unix:///run/podman/podman.sock";
                  volumes.enabled = true;
                  gc.container = true;
                  recover_stopped = true;
                };

                raw_exec.config.enabled = false;
              };

              telemetry = {
                collection_interval = "10s";
                disable_hostname = false;
                prometheus_metrics = true;
                publish_allocation_metrics = true;
                publish_node_metrics = true;
              };
            };

            extraSettingsPlugins = mkIf (cfg.volumes != [ ]) [
              (pkgs.writeText "volumes.hcl" ''
                client {
                  ${host-volumes}
                }
              '')
            ];
          };

          systemd.sockets.podman.enable = mkIf cfg.client true;

          networking.firewall = {
            allowedTCPPorts = with cfg.ports; [
              http
              rpc
              serf
            ];
            allowedUDPPorts = [ cfg.ports.serf ];
            allowedTCPPortRanges = [
              {
                from = 20000;
                to = 32000;
              }
            ];
            allowedUDPPortRanges = [
              {
                from = 20000;
                to = 32000;
              }
            ];
          };

          systemd.services.nomad = {
            after = optional cfg.consul.enable "consul.service" ++ optional cfg.client "podman.socket";
            wants = optional cfg.consul.enable "consul.service" ++ optional cfg.client "podman.socket";
          };
        }

        # CNI for Consul Connect
        (mkIf (cfg.consul.enable && cfg.client) {
          environment.etc."cni/net.d/10-consul-connect.conflist".text = builtins.toJSON {
            cniVersion = "0.4.0";
            name = "consul-connect";
            plugins = [
              { type = "loopback"; }
              {
                type = "bridge";
                bridge = "nomad";
                isGateway = true;
                ipMasq = true;
                ipam = {
                  type = "host-local";
                  ranges = [ [ { subnet = "172.26.64.0/20"; } ] ];
                  routes = [ { dst = "0.0.0.0/0"; } ];
                };
              }
              {
                type = "portmap";
                capabilities.portMappings = true;
              }
              { type = "firewall"; }
            ];
          };
        })

        # Consul service registration
        (
          let
            service = mk-traefik-service {
              inherit hostname datacenter;
              port = cfg.ports.http;
              name = "nomad-ui";
              subdomain = "nomad";
            };
            healthcheck = mk-healthcheck service {
              route = "/v1/agent/health";
            };
          in
          with-consul config (
            service
            // {
              checks = [ healthcheck ];
              address = "127.0.0.1";
            }
          )
        )
      ]
    );
}
