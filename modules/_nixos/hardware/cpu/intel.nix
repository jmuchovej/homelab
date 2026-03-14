{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "hardware.cpu.intel";
  description = "Intel CPUs";
  config =
    { pkgs, ... }:
    {
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
