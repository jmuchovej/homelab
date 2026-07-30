{
  rbn.system._.hardware._.cpu = {
    _.intel.nixos =
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

    _.amd.nixos =
      { config, pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.amdctl ];

        hardware.cpu.amd.updateMicrocode = true;

        boot = {
          extraModulePackages = [ config.boot.kernelPackages.zenpower ];

          kernelModules = [
            "kvm-amd" # amd virtualization
            "amd-pstate" # load pstate module in case the device has a newer gpu
            "zenpower" # zenpower is for reading cpu info, i.e voltage
            "msr" # x86 CPU MSR access device
          ];

          kernelParams = [ "amd_pstate=active" ];
        };
      };
  };
}
