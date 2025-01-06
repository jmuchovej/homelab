{
  projectRootFile = ".git/config";

  programs.biome = {
    enable = true;
    settings.formatter.formatWithErrors = true;
  };

  programs.deadnix.enable = true;

  # Go-related
  programs.gofmt.enable = true;

  # Python-related
  programs.isort.enable = true;
  programs.ruff-check.enable = true;
  programs.ruff-format.enable = true;

  # Rust-related
  programs.rustfmt.enable = true;

  # Nix related
  programs.nixfmt.enable = true;
  programs.statix.enable = true;

  # Lua-related
  programs.stylua.enable = true;

  # YAML/TOML-related
  programs.taplo.enable = true;
  programs.yamlfmt.enable = true;

  # Shell-related
  programs.shfmt = {
    enable = true;
    indent_size = 2; # Fight me ;p
  };

  settings.global.excludes = [
    "*.editorconfig"
    "*.envrc"
    "*.gitconfig"
    "*.git-blame-ignore-revs"
    "*.gitignore"
    "*.gitattributes"
    "*CODEOWNERS"
    "*LICENSE"
    "*flake.lock"
    "*.svg"
    "*.png"
    "*.gif"
    "*.ico"
    "*.jpg"
    "*.jpeg"
    "*Makefile"
    "*makefile"
    "*justfile"
    "*.xml"
    "*.zsh"
    "*.kdl"
  ];

  settings.formatter.ruff-format.options = [ "--isolated" ];
}
