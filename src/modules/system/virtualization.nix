_: {
  rbn.system._.virtualization = {
    provides.containers.nixos =
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
          enable = builtins.elem "nvidia" (config.services.xserver.videoDrivers or [ ]);
        };
      };
  };
}
