{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.

  # Additional metadata is provided by Snowfall Lib. # The namespace used for your flake, defaulting to "internal" if not set. # The system architecture for this host (eg. `x86_64-linux`). # The Snowfall Lib target for this system (eg. `x86_64-iso`). # A normalized name for the system target (eg. `iso`). # A boolean to determine whether this system is a virtual target using nixos-generators. # An attribute map of your defined hosts.

  # All other arguments come from the system system.
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;
  cfg = config.rebellion.services.local-llms;
in
{
  options.rebellion.services.local-llms = with types; {
    enable = mkEnableOption "Local LLMs";
    vllm = {
      model = mkOption {
        type = str;
        description = "model to deploy, from HuggingFace";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ollama
      ollama-cuda
    ];

    sops.secrets."vllm" = { };

    virtualisation.oci-containers.containers.vllm = {
      pull = "always";
      image = "docker.io/vllm/vllm-openai:latest";
      hostname = "vllm";
      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];
      volumes = [
        "/warp/models/huggingface:/root/.cache/huggingface"
      ];
      ports = [ "8556:8000" ];
      environmentFiles = [
        config.sops.secrets."vllm".path
      ];
      cmd = [ "--model=${cfg.vllm.model}" ];
    };
  };
}
