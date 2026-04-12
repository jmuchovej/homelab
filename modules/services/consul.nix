{ den, ... }: {
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkEnableOption mkOption mkBool;
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
        connect = {
          policies = {
            policies = {
              homelab-allow-all = mkBool true "Allow all homelab services to communicate";
              default-deny = mkBool true "Deny all other communications by default";
            };
          };
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
    includes = [ (den.provides.unfree [ "consul" ]) ];
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
        inherit (lib.rebellion.network)
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

    provides.connect.nixos =
      {
        host,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = host.consul;
      in
      {
        # Create service intentions via systemd oneshot service
        systemd.services.consul-connect-policies = {
          description = "Configure Consul Connect service intentions";
          after = [ "consul.service" ];
          wants = [ "consul.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "consul";
            RemainAfterExit = true;
          };

          script =
            let
              consulCmd = "${pkgs.consul}/bin/consul";
              waitForConsul = ''
                echo "Waiting for Consul to be ready..."
                until ${consulCmd} members >/dev/null 2>&1; do
                  echo "Waiting for Consul..."
                  sleep 2
                done
                echo "Consul is ready"
              '';

              homelab-allow-policy = pkgs.writeText "homelab-allow.json" (
                builtins.toJSON {
                  Kind = "service-intentions";
                  Name = "homelab-*";
                  Sources = [
                    {
                      Name = "homelab-*";
                      Action = "allow";
                    }
                  ];
                }
              );

              default-deny-policy = pkgs.writeText "default-deny.json" (
                builtins.toJSON {
                  Kind = "service-intentions";
                  Name = "*";
                  Sources = [
                    {
                      Name = "*";
                      Action = "deny";
                    }
                  ];
                }
              );
            in
            ''
              ${waitForConsul}

              ${lib.optionalString cfg.connect.policies.homelab-allow-all ''
                echo "Applying homelab allow-all policy..."
                ${consulCmd} config write ${homelab-allow-policy} || echo "Failed to apply homelab policy (may already exist)"
              ''}

              ${lib.optionalString cfg.connect.policies.default-deny ''
                echo "Applying default deny policy..."
                ${consulCmd} config write ${default-deny-policy} || echo "Failed to apply default deny policy (may already exist)"
              ''}

              echo "Consul Connect policies applied successfully"
            '';
        };

        # Helper script to manage intentions
        environment.systemPackages = [
          (pkgs.writeShellScriptBin "consul-intentions" ''
            #!/usr/bin/env bash
            set -euo pipefail

            case "''${1:-}" in
              "list")
                echo "=== Current Service Intentions ==="
                consul config list -kind service-intentions
                ;;
              "show")
                if [ -z "''${2:-}" ]; then
                  echo "Usage: consul-intentions show <service-name>"
                  exit 1
                fi
                consul config read -kind service-intentions -name "$2"
                ;;
              "allow")
                if [ -z "''${2:-}" ] || [ -z "''${3:-}" ]; then
                  echo "Usage: consul-intentions allow <source-service> <destination-service>"
                  exit 1
                fi

                cat > /tmp/allow-intention.json <<EOF
            {
              "Kind": "service-intentions",
              "Name": "$3",
              "Sources": [
                {
                  "Name": "$2",
                  "Action": "allow"
                }
              ]
            }
            EOF
                consul config write /tmp/allow-intention.json
                rm /tmp/allow-intention.json
                echo "Allowed $2 -> $3"
                ;;
              "deny")
                if [ -z "''${2:-}" ] || [ -z "''${3:-}" ]; then
                  echo "Usage: consul-intentions deny <source-service> <destination-service>"
                  exit 1
                fi

                cat > /tmp/deny-intention.json <<EOF
            {
              "Kind": "service-intentions",
              "Name": "$3",
              "Sources": [
                {
                  "Name": "$2",
                  "Action": "deny"
                }
              ]
            }
            EOF
                consul config write /tmp/deny-intention.json
                rm /tmp/deny-intention.json
                echo "Denied $2 -> $3"
                ;;
              "delete")
                if [ -z "''${2:-}" ]; then
                  echo "Usage: consul-intentions delete <service-name>"
                  exit 1
                fi
                consul config delete -kind service-intentions -name "$2"
                echo "Deleted intentions for $2"
                ;;
              *)
                cat <<EOF
            Usage: consul-intentions <command> [args...]

            Commands:
              list                                  List all service intentions
              show <service>                        Show intentions for a service
              allow <source> <destination>          Allow source to destination
              deny <source> <destination>           Deny source to destination
              delete <service>                      Delete intentions for service

            Examples:
              consul-intentions list
              consul-intentions show plex
              consul-intentions allow homelab-nginx homelab-plex
              consul-intentions deny external-* homelab-*
            EOF
                ;;
            esac
          '')
        ];
      };
  };
}
