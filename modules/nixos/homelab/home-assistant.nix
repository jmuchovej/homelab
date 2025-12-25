{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.home-assistant";
  config =
    {
      lib,
      pkgs,
      config,
      hostname,
      ...
    }:
    let
      inherit (lib) mkMerge;
      inherit (lib.rebellion.traefik) mk-service with-consul;
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
              # use_x_forwarded_for = true;
              # trusted_proxies = [
              #   "10.42.0.0/16"
              #   "10.69.0.0/16"
              #   "10.94.0.0/16"
              #   "10.99.0.0/16"
              #   "192.168.1.0/24"
              # ];
            };
            homeassistant = {
              name = "Home";
              unit_system = "us_customary";
              time_zone = "America/New_York";
              temperature_unit = "F";
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

      (with-consul config (mk-service {
        inherit hostname;
        name = "hass";
        port = 8123;
        subdomain = "home-assistant";
        checks = [
          {
            http = "http://localhost:8123/api/";
            interval = "10s";
            timeout = "2s";
          }
        ];
      }))
    ];
}
