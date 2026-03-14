{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion.options) mk-bool;

  cfg = config.rebellion.services.consul;
in
{
  options.rebellion.services.consul.connect = {
    policies = {
      homelab-allow-all = mk-bool true "Allow all homelab services to communicate";
      default-deny = mk-bool true "Deny all other communications by default";
    };
  };

  config = mkIf (cfg.enable && cfg.connect.enable) {
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
}
