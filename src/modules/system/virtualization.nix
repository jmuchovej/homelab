_: {
  rbn.system._.virtualization = {
    _.apptainer.nixos =
      { config, pkgs, ... }:
      {
        # Apptainer is configured through the shared `programs.singularity`
        # module. The package default is SingularityCE, so we hand-provide
        # apptainer explicitly — which also gives a single knob to version-pin
        # (HPC clusters track toolchains at their own pace; override this).
        # Apptainer stays non-suid (the module default for it), which is
        # required for `--nv`: nvidia-container-cli is not allowed in suid mode.
        programs.singularity = {
          enable = true;
          package = pkgs.apptainer;
        };

        # GPU support via CDI: this module runs a boot service that writes an
        # Nvidia CDI spec to /var/run/cdi, which apptainer reads from its default
        # CDI dirs — so `apptainer run --device nvidia.com/gpu=all …` works with
        # no apptainer.conf changes. Gated on (and the module also asserts) the
        # nvidia driver, set by <rbn/system/hardware/gpu/nvidia>.
        hardware.nvidia-container-toolkit.enable = builtins.elem "nvidia" (
          config.services.xserver.videoDrivers or [ ]
        );
      };
  };
}
