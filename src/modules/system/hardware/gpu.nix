{ den, ... }: {
  rbn.system._.hardware._.gpu = {
    _.nvidia = {
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
            substituters = [ "https://cache.nixos-cuda.org" ];
            trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
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

    _.amd.nixos = { };
  };
}
