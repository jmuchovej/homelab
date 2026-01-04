{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.home-assistant";
  config =
    {
      lib,
      pkgs,
      config,
      datacenter,
      hostname,
      ...
    }:
    let
      inherit (lib) mkMerge get-file;
      inherit (lib.rebellion.network) mk-traefik-service with-consul mk-healthcheck;
    in
    mkMerge [
      {
        environment.systemPackages = with pkgs; [
          home-assistant
          home-assistant-cli
        ];

        services.home-assistant = {
          enable = true;
          openFirewall = true;
          configWritable = true;
          lovelaceConfigWritable = true;
          config = {
            default_config = { };
            http = {
              server_port = 8123;
              # Deprecated, but it seems people are angry. (:
              #   https://github.com/home-assistant/core/issues/157961
              # server_host = [ "0.0.0.0" "::" ];
              # NOTE: disabled authentik is configured correctly
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
          };
          customComponents = (
            with pkgs.home-assistant-custom-components;
            with pkgs.rebellion.home-assistant.components;
            [
              auth_oidc
              adaptive_lighting
              hacs
            ]
          );
          # customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [ ];
          extraPackages =
            python3Packages: with python3Packages; [
              psycopg2
              numpy
              gtts
              pydantic
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
      }

      {
        sops.secrets."consul/home-assistant".sopsFile = get-file "secrets/${datacenter}.sops.yaml";
      }

      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            name = "home-assistant";
            subdomain = "home";
            port = 8123;
          };
          healthcheck = mk-healthcheck service {
            route = "/api/";
            header = {
              Authorization = [ "Bearer ${config.sops.placeholder."consul/home-assistant"}" ];
            };
          };
        in
        (with-consul config (
          service
          // {
            checks = [ healthcheck ];
            write-template = true;
            address = "127.0.0.1";
          }
        ))
      )
    ];
}
