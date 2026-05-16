{ rbn, den, ... }:
{
  rbn.system._.hardware._.gpu._.nvidia = {
    includes = [
      (den.batteries.unfree [
        "nvidia-x11"
        "nvidia-settings"
        "nvidia-kernel-modules"
      ])
    ];

    nixos =
      {
        lib,
        pkgs,
        config,
        ...
      }:
      let
        # use the latest possible nvidia package
        nvStable = config.boot.kernelPackages.nvidiaPackages.stable.version;
        nvBeta = config.boot.kernelPackages.nvidiaPackages.beta.version;

        nvidiaPackage =
          if (lib.versionOlder nvBeta nvStable) then
            config.boot.kernelPackages.nvidiaPackages.stable
          else
            config.boot.kernelPackages.nvidiaPackages.beta;
      in
      {
        boot.blacklistedKernelModules = [
          "nouveau"
          "nvidiafb"
        ];

        environment = {
          variables = {
            CUDA_CACHE_PATH = "$XDG_CACHE_HOME/nv";
          };

          shellAliases = {
            nvidia-settings = "nvidia-settings --config=$XDG_CONFIG_HOME/nvidia/settings";
          };

          systemPackages = with pkgs; [
            nvfancontrol
          ];
        };

        nixpkgs.config.nvidia.acceptLicense = true;

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
          graphics.enable = true;

          nvidia = {
            open = false;
            package = lib.mkDefault nvidiaPackage;
            nvidiaSettings = false;
          };
        };
      };
  };
}
