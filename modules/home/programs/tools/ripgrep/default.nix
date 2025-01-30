{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.ripgrep;
in
{
  options.${namespace}.programs.tools.ripgrep = {
    enable = mkEnableOption "ripgrep";
  };

  config = mkIf cfg.enable {
    programs.ripgrep = {
      enable = true;
      arguments = [
        # Avoid dumping long lines to shell
        # "--max-columns=80"
        "--max-columns-preview"
        # Search hidden files
        "--hidden"
        # Ignore casing
        "--smart-case"
        # Follow symlinks while searching
        "--follow"
      ];
    };
  };
}
