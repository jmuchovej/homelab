_: {
  rbn.system._.hardware._.cpu._.intel.nixos =
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
