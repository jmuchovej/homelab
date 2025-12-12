{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    versionOlder
    mkEnableOption
    ;
  cfg = config.rebellion.hardware.gpu.nvidia;

  # use the latest possible nvidia package
  nvStable = config.boot.kernelPackages.nvidiaPackages.stable.version;
  nvBeta = config.boot.kernelPackages.nvidiaPackages.beta.version;

  nvidiaPackage =
    if (versionOlder nvBeta nvStable) then
      config.boot.kernelPackages.nvidiaPackages.stable
    else
      config.boot.kernelPackages.nvidiaPackages.beta;
in
{
  options.rebellion.hardware.gpu.nvidia = {
    enable = mkEnableOption "NVIDIA GPUs";
  };

  config = mkIf cfg.enable {
    boot.blacklistedKernelModules = [
      "nouveau"
      "nvidiafb"
    ];

    environment = {
      variables = {
        CUDA_CACHE_PATH = "$XDG_CACHE_HOME/nv";
      };

      shellAliases = {
        nvidia-settings = "nvidia-settings --config='$XDG_CONFIG_HOME'/nvidia/settings";
      };

      systemPackages = with pkgs; [
        nvfancontrol

        # nvtopPackages.nvidia
      ];
    };

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

    services.xserver.videoDrivers = mkDefault [ "nvidia" ];

    hardware = {
      graphics.enable = true;

      nvidia = {
        # Use the Nvidia open source kernel module (not to be confused with the
        # independent third-party "nouveau" open source driver).
        # Support is limited to the Turing and later architectures. Full list of
        # supported GPUs is at:
        # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
        # Only available from driver 515.43.04+
        # Currently alpha-quality/buggy, so false is currently the recommended setting.
        open = false;

        package = mkDefault nvidiaPackage;
        # modesetting.enable = mkDefault true;

        # powerManagement = {
        #   enable = mkDefault true;
        #   finegrained = mkDefault false;
        # };

        nvidiaSettings = false;
        # nvidiaPersistenced = true;
        # forceFullCompositionPipeline = true;
      };
    };
  };
}
