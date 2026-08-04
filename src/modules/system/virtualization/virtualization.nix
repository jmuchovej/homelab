{
  rbn.system._.virtualization = {
    _.apptainer.nixos = { pkgs, ... }: {
      programs.singularity = {
        enable = true;
        package = pkgs.apptainer;
      };
    };

    _.apptainer._.nvidia.nixos = {
      hardware.nvidia-container-toolkit.enable = true;
    };
  };
}
