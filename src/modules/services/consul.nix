{ den, ... }:
{
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkEnableOption mkOption;
      inherit (lib.types)
        str
        int
        enum
        port
        ;
    in
    {
      options.consul = {
        server = mkEnableOption "Consul server mode";
        bootstrap-expect = mkOption {
          type = int;
          default = 3;
          description = "Number of servers to wait for before bootstrapping";
        };
        interface = mkOption {
          type = str;
          default = "enp1s0";
          description = "Network interface to bind Consul to";
        };
        ui = mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Consul WebUI";
        };
        acl = {
          enable = mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable ACLs";
          };
          default-policy = mkOption {
            type = enum [
              "allow"
              "deny"
            ];
            default = "allow";
            description = "Default ACL policy";
          };
        };
        dns = {
          enable = mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Consul DNS";
          };
          port = mkOption {
            type = port;
            default = 8600;
            description = "DNS port";
          };
        };
        ports = {
          http = mkOption {
            type = port;
            default = 8500;
          };
          https = mkOption {
            type = port;
            default = 8501;
          };
          grpc = mkOption {
            type = port;
            default = 8502;
          };
          grpc-tls = mkOption {
            type = port;
            default = 8503;
          };
          serf-lan = mkOption {
            type = port;
            default = 8301;
          };
          serf-wan = mkOption {
            type = port;
            default = 8302;
          };
          server = mkOption {
            type = port;
            default = 8300;
          };
        };
      };
    };

  rbn.services._.consul = {
    includes = [ (den.batteries.unfree [ "consul" ]) ];
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        peers,
        ...
      }:
      let
        inherit (lib) mkIf optional optionalAttrs;
        inherit (lib.rbn)
          with-consul
          mk-traefik-service
          mk-healthcheck
          ;
        inherit (host) hostname datacenter;

        cfg = host.consul;
        retry-join-peers = map (p: "${p.hostname}.lab") peers;
      in
      lib.mkMerge [
        {
          environment.systemPackages = [ pkgs.consul ];

          services.consul = {
            enable = true;
            webUi = cfg.ui;

            interface = {
              bind = cfg.interface;
              advertise = cfg.interface;
            };

            forceAddrFamily = "ipv4";

            extraConfig = {
              inherit datacenter;
              node_name = hostname;
              inherit (cfg) server;
            }
            // optionalAttrs cfg.server {
              bootstrap_expect = cfg.bootstrap-expect;
            }
            // optionalAttrs (retry-join-peers != [ ]) {
              retry_join = retry-join-peers;
              retry_interval = "15s";
              retry_max = 0;
            }
            // {
              connect = {
                enabled = true;
                ca_config.rotation_period = "2160h";
              };

              performance = {
                raft_multiplier = 1;
                leave_drain_time = "5s";
              };

              acl = {
                enabled = cfg.acl.enable;
                default_policy = cfg.acl.default-policy;
                enable_token_persistence = true;
              };

              ports = mkIf cfg.dns.enable {
                dns = cfg.dns.port;
              };

              enable_central_service_config = true;
            };
          };

          networking.firewall = {
            allowedTCPPorts =
              with cfg.ports;
              [
                http
                https
                grpc
                grpc-tls
                serf-lan
                serf-wan
                server
              ]
              ++ optional cfg.dns.enable cfg.dns.port;

            allowedUDPPorts =
              with cfg.ports;
              [
                serf-lan
                serf-wan
              ]
              ++ optional cfg.dns.enable cfg.dns.port;
          };
        }

        # Consul UI service registration
        (
          let
            service = mk-traefik-service {
              inherit hostname datacenter;
              port = cfg.ports.http;
              name = "consul-ui";
              subdomain = "consul";
            };
            healthcheck = mk-healthcheck service {
              route = "/v1/health/node/${hostname}";
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
  };
}
