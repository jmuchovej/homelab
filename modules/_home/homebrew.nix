{ lib, ... }@args:
lib.rebellion.mk-module args {
  namespace = "homebrew";
  options =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types)
        attrsOf
        int
        listOf
        str
        ;
    in
    {
      casks = mkOption {
        type = listOf str;
        default = [ ];
        description = "Homebrew casks to install, collected from all modules.";
      };
      brews = mkOption {
        type = listOf str;
        default = [ ];
        description = "Homebrew formulae to install, collected from all modules.";
      };
      mas-apps = mkOption {
        type = attrsOf int;
        default = { };
        description = "Mac App Store apps to install, collected from all modules.";
      };
    };
}
