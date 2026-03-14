{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "virtualization.containers";
  description = "[OCI] Containers";
  config =
    { config, pkgs, ... }:
    {
      virtualisation = {
        containers.enable = true;
        oci-containers.backend = "podman";
        podman = {
          enable = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };
      };

      environment.systemPackages = with pkgs; [
        apptainer
        dive
        podman-tui
        podman-compose
      ];

      hardware.nvidia-container-toolkit = {
        inherit (config.rebellion.hardware.gpu.nvidia) enable;
      };
    };
}
