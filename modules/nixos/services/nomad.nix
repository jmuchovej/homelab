{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.nomad";
  description = "Nomad job scheduler";

  options =
    { lib, ... }:
    with lib.types;
    let
      inherit (lib.rebellion.options) mk mk-enable;
    in
    {
      datacenter = mk str "da" "Nomad datacenter name";
      region = mk str "da" "Nomad region name";
      server = mk-enable "Nomad Server mode" false;
      client = mk-enable "Nomad Client mode" true;
      bootstrap-expect = mk int 3 "Number of servers to wait for before bootstrapping";
      ui = mk-enable "Nomad WebUI" true;
      interface = mk str "enp1s0" "Network interface to bind Nomad";

      consul = (mk-enable "Consul integration" true) // {
        address = mk str "127.0.0.1:8500" "Consul HTTP address";
      };

      volumes = mk (listOf str) [ ] "List of host volume paths to expose";

      ports = {
        http = mk port 4646 "HTTP API port";
        rpc = mk port 4647 "RPC port";
        serf = mk port 4648 "Serf port";
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
      peers,
      ...
    }:
    let
      inherit (lib.strings) concatMapStringsSep;
      inherit (lib.rebellion.network)
        with-consul
        mk-traefik-service
        mk-healthcheck
        ;

      # Generate retry-join list from datacenter peers
      retry-join-peers = map (p: "${p.hostname}.node.consul") peers;

      # Generate host_volume blocks for each volume
      host-volumes = concatMapStringsSep "\n" (vol: ''
        host_volume "${baseNameOf vol}" {
          path = "${vol}"
          read_only = false
        }
      '') cfg.volumes;
    in
    lib.mkMerge [
      {
        environment.systemPackages = [ pkgs.nomad ];

        # Enable Podman for Nomad client
        rebellion.virtualization.containers = lib.mkIf cfg.client.enable {
          enable = true;
        };

        # Use NixOS's native Nomad service
        services.nomad = {
          enable = true;
          package = pkgs.nomad;
          dropPrivileges = false; # Podman driver needs privileges
          enableDocker = false;

          extraPackages = with pkgs; [
            cni-plugins
            consul
            nomad-driver-podman
          ];

          settings = {
            inherit (cfg) datacenter;
            inherit (cfg) region;
            data_dir = "/var/lib/nomad";
            log_level = "INFO";

            # Listen on all interfaces (advertise uses specific interface)
            # TODO: once networking is sorted, lock down to specific iface
            # bind_addr = "{{ GetInterfaceIP \"${cfg.interface}\" }}";
            bind_addr = "0.0.0.0";

            advertise = {
              http = "{{ GetInterfaceIP \"${cfg.interface}\" }}";
              rpc = "{{ GetInterfaceIP \"${cfg.interface}\" }}";
              serf = "{{ GetInterfaceIP \"${cfg.interface}\" }}";
            };

            ports = {
              inherit (cfg.ports) http;
              inherit (cfg.ports) rpc;
              inherit (cfg.ports) serf;
            };

            # Server configuration
            server = lib.mkIf cfg.server.enable {
              enabled = true;
              bootstrap_expect = cfg.bootstrap-expect;

              server_join = lib.mkIf (retry-join-peers != [ ]) {
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

            # Client configuration
            client = lib.mkIf cfg.client.enable {
              enabled = true;
              network_interface = cfg.interface;
              node_class = "compute";

              reserved = {
                cpu = 500;
                memory = 1024;
              };

              cni_path = "${pkgs.cni-plugins}/bin";
            };

            # Consul integration
            consul = lib.mkIf cfg.consul.enable {
              inherit (cfg.consul) address;
              server_service_name = "nomad";
              client_service_name = "nomad-client";
              auto_advertise = true;
              server_auto_join = true;
              client_auto_join = true;

              # Service mesh integration (Consul Connect)
              service_identity = {
                aud = [ "consul.io" ];
                ttl = "1h";
              };
            };

            # UI
            ui = {
              enabled = cfg.ui.enable;
              consul = lib.mkIf cfg.consul.enable {
                ui_url = "https://consul.${datacenter}.jm0.io";
              };
            };

            # Plugin configuration
            plugin = {
              nomad-driver-podman = {
                config = {
                  # Use rootful Podman socket
                  socket_path = "unix:///run/podman/podman.sock";

                  volumes = {
                    enabled = true;
                  };

                  gc = {
                    container = true;
                  };

                  recover_stopped = true;
                };
              };

              raw_exec = {
                config = {
                  enabled = false;
                };
              };
            };

            # Telemetry
            telemetry = {
              collection_interval = "10s";
              disable_hostname = false;
              prometheus_metrics = true;
              publish_allocation_metrics = true;
              publish_node_metrics = true;
            };
          };

          # Extra HCL for host volumes (can't be expressed in settings)
          extraSettingsPlugins = lib.mkIf (cfg.volumes != [ ]) [
            (pkgs.writeText "volumes.hcl" ''
              client {
                ${host-volumes}
              }
            '')
          ];
        };

        # Enable Podman socket for Nomad
        systemd.sockets.podman.enable = lib.mkIf cfg.client.enable true;

        # Firewall configuration
        networking.firewall = {
          allowedTCPPorts = with cfg.ports; [
            http
            rpc
            serf
          ];
          allowedUDPPorts = [ cfg.ports.serf ];

          # Dynamic port allocation for jobs
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

        # Ensure Nomad starts after Consul and Podman
        systemd.services.nomad = {
          after = lib.optional cfg.consul.enable "consul.service" ++ lib.optional cfg.client "podman.socket";
          wants = lib.optional cfg.consul.enable "consul.service" ++ lib.optional cfg.client "podman.socket";
        };
      }

      # Consul Connect integration (requires CNI plugins)
      (lib.mkIf (cfg.consul.enable && cfg.client.enable) {
        # CNI configuration for Consul Connect
        environment.etc."cni/net.d/10-consul-connect.conflist".text = builtins.toJSON {
          cniVersion = "0.4.0";
          name = "consul-connect";
          plugins = [
            {
              type = "loopback";
            }
            {
              type = "bridge";
              bridge = "nomad";
              isGateway = true;
              ipMasq = true;
              ipam = {
                type = "host-local";
                ranges = [
                  [
                    {
                      subnet = "172.26.64.0/20";
                    }
                  ]
                ];
                routes = [
                  {
                    dst = "0.0.0.0/0";
                  }
                ];
              };
            }
            {
              type = "portmap";
              capabilities = {
                portMappings = true;
              };
            }
            {
              type = "firewall";
            }
          ];
        };
      })

      # Nomad UI service registration
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
    ];
}
