{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.local-llms";
  options =
    { lib, pkgs, ... }:
    with lib.types;
    let
      inherit (lib.rebellion.options) mk mk-package;
    in
    {
      ollama = {
        package = mk-package pkgs.ollama-cpu "Which version of Ollama should be installed? `pkgs.ollama-[,-vulkan,-rocm,-cuda,-cpu]`";
        models = mk (listOf str) [ ] ''
          List of models to download using `ollama pull` once `ollama.service` starts. It generally follows <option>services.ollama.loadModels</option>.

          Search for models on [ollama's library](https://ollama.com/library).
        '';
      };
    };

  config =
    { lib, ... }@module-args:
    lib.mkMerge [
      (import ./ollama.part.nix module-args)
      (import ./open-webui.part.nix module-args)
    ];
}
