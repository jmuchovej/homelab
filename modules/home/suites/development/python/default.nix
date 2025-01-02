{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.suites.development.python;
  default-vscode = config.programs.vscode.profiles.default or {};

  python = cfg.package;
  default-packages = python.withPackages (ps: with ps; [
    # Dev Dependencies
    jupyter ipython python-lsp-server mypy ruff jedi ipdb

    # General-Purpose Scientific Computing
    polars
    pandas numpy scipy scikit-learn

    # PyTorch
    # pytorch pytorch-lightning torchvision torchaudio

    # HuggingFace
    tokenizers transformers # trl accelerate

    # Other useful things
    fastapi typer pydantic rich hydra-core omegaconf srsly

    # Visualization
    altair
  ]);

  vsc-extensions = (with pkgs.open-vsx; [
    # Regular-ole Python
    ms-python.python
    charliermarsh.ruff

    # Jupyter
    ms-toolsai.jupyter
    ms-toolsai.jupyter-renderers
    ms-toolsai.vscode-jupyter-powertoys
    ms-toolsai.vscode-jupyter-cell-tags
    ms-toolsai.jupyter-keymap
  ]);
  vsc-user-settings = { };

  zed-extensions    = [ "ruff" "pylsp" "python-refactoring" ];
  zed-user-settings = { };
in {
  options.${namespace}.suites.development.python = {
    enable  = mkEnableOption "python";
    package = mkPackageOption pkgs "python3" { };
    vscode  = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = [ default-packages ];

    programs.vscode = mkIf config.programs.vscode.enable {
      extensions    = vsc-extensions;
      userSettings  = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.programs.zed-editor.enable {
      extensions    = zed-extensions;
      userSettings  = zed-user-settings;
    };
  };
}
