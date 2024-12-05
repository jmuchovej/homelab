{ config, lib, pkgs, ... }:
{
  boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];

  nixpkgs.config.nvidia.acceptLicense = true;

  # https://discourse.nixos.org/t/for-all-you-cuda-users-out-there/45383
  # https://discourse.nixos.org/t/for-all-you-cuda-users-out-there/45383/2
  nix.settings = {
    substituters = [
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];

  hardware = {
    # graphics.enable = true;
    opengl = {
      enable = true;
      driSupport = true;
    };

    nvidia = {
      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      # Currently alpha-quality/buggy, so false is currently the recommended setting.
      open = false;

      # Enable the Nvidia settings menu,
	   # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    nvidia-container-toolkit = {
      enable = true;
    };
  };
}
