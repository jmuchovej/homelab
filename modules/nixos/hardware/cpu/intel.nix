{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.hardware.cpu.intel;
in
{
  options.rebellion.hardware.cpu.intel = {
    enable = mkEnableOption "Intel CPUs";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.intel-gpu-tools ];

    hardware.cpu.intel.updateMicrocode = true;

    boot = {
      kernelModules = [ "kvm-intel" ];

      kernelParams = [
        "i915.fastboot=1"
        "enable_gvt=1"
      ];
    };
  };
}
