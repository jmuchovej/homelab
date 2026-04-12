{ __findFile, inputs, ... }:
{
  rbn.services._.home-assistant = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib.rebellion.network) mk-openid-url;
        inherit (host) datacenter;
        sops-file = kind: "${inputs.self}/secrets/${kind}.sops.yaml";
      in
      {
        sops.secrets."home-assistant/client-id".sopsFile = sops-file "authentik";
        sops.secrets."home-assistant/client-secret".sopsFile = sops-file "authentik";
        sops.secrets."consul/home-assistant".sopsFile = sops-file datacenter;

        environment.systemPackages = with pkgs; [
          home-assistant
          home-assistant-cli
        ];

        sops.templates."secrets.yaml" =
          let
            client-id = config.sops.placeholder."home-assistant/client-id";
            ha-service = config.systemd.services.home-assistant.serviceConfig;
          in
          {
            content = ''
              logger: debug
              ak-client-id: ${client-id}
              ak-client-secret: ${config.sops.placeholder."home-assistant/client-secret"}
              ak-provider-url: ${mk-openid-url client-id datacenter}
            '';
            path = config.services.home-assistant.configDir + "/secrets.yaml";
            owner = ha-service.User;
            group = ha-service.Group;
          };

        services.home-assistant = {
          enable = true;
          openFirewall = true;
          configWritable = true;
          lovelaceConfigWritable = true;
          config = {
            default_config = { };
            http = {
              server_port = 8123;
              use_x_forwarded_for = true;
              trusted_proxies = [
                "127.0.0.1"
                "10.42.0.0/16"
                "10.69.0.0/16"
                "10.94.0.0/16"
                "10.99.0.0/16"
                "192.168.1.0/24"
                "::1"
              ];
            };
            homeassistant = {
              name = "Home";
              unit_system = "us_customary";
              time_zone = "America/New_York";
              temperature_unit = "F";
              internal_url = "https://home.${datacenter}.jm0.io";
              external_url = "https://home.${datacenter}.jm0.io";
            };
            auth_oidc = {
              client_id = "!secret ak-client-id";
              client_secret = "!secret ak-client-secret";
              discovery_url = "!secret ak-provider-url";
            };
          };
          customComponents =
            (with pkgs.home-assistant-custom-components; [
              auth_oidc
              adaptive_lighting
            ])
            ++ [
              (pkgs.home-assistant.python.pkgs.callPackage ./_packages/hacs.nix { })
            ];
          extraPackages =
            python3Packages: with python3Packages; [
              psycopg2
              numpy
              gtts
              pydantic
              python-otbr-api
            ];
          extraComponents = [
            "default_config"
            "network"
            "zeroconf"
            "isal"
            "met"
            "esphome"
            "apple_tv"
            "androidtv_remote"
            "plex"
            "tts"
            "http"
            "group"
            "script"
            "scene"
            "automation"
            "recorder"
            "zone"
            "trend"
            "proximity"
            "otp"
            "bayesian"
            "mobile_app"
          ];
          extraArgs = [ ];
        };

        services.postgresql.ensureDatabases = [ "hass" ];
        services.postgresql.ensureUsers = [
          {
            name = "hass";
            ensureDBOwnership = true;
          }
        ];

        networking.firewall.allowedTCPPorts = [ 39501 ];
      };

    includes = [
      (<rbn/mesh/register> {
        name = "home-assistant";
        subdomain = "home";
        port = 8123;
        address = "127.0.0.1";
        write-template = true;
        healthchecks =
          {
            config,
            service,
            mk-healthcheck,
            ...
          }:
          [
            (mk-healthcheck service {
              route = "/api/";
              header = {
                Authorization = [ "Bearer ${config.sops.placeholder."consul/home-assistant"}" ];
              };
            })
          ];
        authentik = {
          name = "Home Assistant";
          type = "oauth";
          group = "Home";
          access = [ "home" ];
          skip-paths = "/api/*";
        };
      })
    ];
  };
}
