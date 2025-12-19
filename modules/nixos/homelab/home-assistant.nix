{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.home-assistant";
  config =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkMerge;
      inherit (lib.rebellion.traefik) mk-service;
    in
    mkMerge [
      {
        environment.systemPackages = with pkgs; [
          home-assistant
          home-assistant-cli
        ];

        services.home-assistant = {
          enable = true;
          configDir = "/warp/apps/home-assistant";
          openFirewall = true;
          configWritable = true;
          lovelaceConfigWritable = true;
          config = {
            default_config = { };
            http = {
              server_port = 8123;
              use_x_forwarded_for = true;
              server_host = [
                "0.0.0.0"
                "::"
              ];
            };
            homeassistant = {
              name = "Home";
              unit_system = "us_customary";
              time_zone = "America/New_York";
              temperature_unit = "F";
            };
          };
          customComponents =
            with pkgs.home-assistant-custom-components;
            with pkgs.rebellion.home-assistant.components;
            [
              auth_oidc
              adaptive_lighting
              hacs
            ];
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
      {
        services.traefik.dynamicConfigOptions.http = mk-service {
          name = "hass";
          port = 8123;
          subdomain = "home-assistant";
        };
      }
    ];
}
