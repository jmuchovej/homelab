{
  # <rbn/services/kubernetes/nvidia> — GPU hosts opt in. k3s auto-generates
  # the containerd nvidia runtime config only if it finds
  # `nvidia-container-runtime` in $PATH at agent start — NixOS puts it
  # nowhere k3s looks by default.
  rbn.services._.kubernetes._.nvidia.nixos = { pkgs, ... }: {
    # generates the CDI spec (/var/run/cdi) with nix-store paths at boot —
    # NOT inherited from the virtualization aspect; this sub-aspect must
    # be self-sufficient
    hardware.nvidia-container-toolkit.enable = true;

    systemd.services.k3s.path = [ pkgs.nvidia-container-toolkit.tools ];
    # the runtime's CDI generation dlopens libnvidia-ml — which NixOS
    # keeps in /run/opengl-driver, nowhere a raw binary looks
    systemd.services.k3s.environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    # ... and even then, auto-generated specs embed FHS hook paths
    # (/usr/bin/nvidia-ctk). Use the spec hardware.nvidia-container-toolkit
    # pre-generates at boot with nix-store paths instead. Read per
    # container-create — no k3s restart needed on change.
    environment.etc."nvidia-container-runtime/config.toml".text = ''
      [nvidia-container-runtime]
      mode = "cdi"

      [nvidia-container-runtime.modes.cdi]
      default-kind = "nvidia.com/gpu"
      spec-dirs = ["/var/run/cdi"]
    '';
  };
}
