{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.python";
  options = {
    package = lib.mkPackageOption pkgs "python3" { };
  };
  config =
    {
      cfg,
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mk-zed-settings;

      python = cfg.package;
      default-python-packages = python.withPackages (
        ps: with ps; [
          # Dev Dependencies
          jupyter
          ipython
          python-lsp-server
          mypy
          jedi
          ipdb

          # General-Purpose Scientific Computing
          polars
          pandas
          numpy
          scipy
          scikit-learn

          # PyTorch
          # pytorch pytorch-lightning torchvision torchaudio

          # HuggingFace
          tokenizers
          transformers # trl accelerate

          # Other useful things
          fastapi
          typer
          pydantic
          rich
          hydra-core
          omegaconf
          srsly

          # Visualization
          altair
        ]
      );

      vsc-extensions = with pkgs.open-vsx; [
        # Regular-ole Python
        ms-python.python
        # charliermarsh.ruff

        # Jupyter
        ms-toolsai.jupyter
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-powertoys
        ms-toolsai.vscode-jupyter-cell-tags
        ms-toolsai.jupyter-keymap
      ];
      vsc-user-settings = {
        "python.locator" = "js";
      };

      # https://zed.dev/docs/languages/python
      zed = mk-zed-settings {
        extensions = [ ];
        packages = with pkgs; [
          ruff
          ty
          basedpyright
        ];
        settings = {
          languages.Python = {
            tab_size = 4;
            formatter = "auto";
            language_servers = [
              "basedpyright"
              "ty"
            ];
          };
          lsp.basedpyright = {
            enable = true;
          };
          # TODO switch to `ty` once https://github.com/astral-sh/ty/issues/1889 closes
          lsp.ty = {
            enable = true;
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        uv
        ruff
        default-python-packages
      ];

      programs.vscode = mkIf config.rebellion.editor.vscode.enable {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
