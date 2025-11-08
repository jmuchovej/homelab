{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.${namespace}.homelab.home-assistant;
  containers = config.${namespace}.virtualization.containers;
in
{
  options.${namespace}.homelab.home-assistant = {
    enable = mkEnableOption "home-assistant";
  };

  config = mkIf cfg.enable {
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
        http = {
          server_port = 8123;
          server_host = [ "0.0.0.0" "::" ];
        };
        homeassistant = {
          name = "Home";
          unit_system = "us_customary";
          time_zone = "America/New_York";
          temperature_unit = "F";
        };
      };
      customComponents = with pkgs.home-assistant-custom-components; [
        auth_oidc
        adaptive_lighting
      ] ++ [
        pkgs.${namespace}.hacs
      ];
      customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [];
      extraPackages = python3Packages: with python3Packages; [ psycopg2 ];
      extraComponents = [
        "default_config" "met" "esphome"
        "apple_tv" "androidtv_remote"
        "plex" "tts" "group" "script" "scene" "automation" "recorder" "zone"
        "trend" "proximity" "otp" "bayesian"
        "mobile_app"
      ];
      extraArgs = [];
    };
  };
}
