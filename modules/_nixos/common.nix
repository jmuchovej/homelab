{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "user";
  options =
    with lib.rebellion.options;
    let
      inherit (lib.types) str listOf attrs;
    in
    {
      name = mk str "lab" "The user account";
      full-name = mk str "lab" "The user's account";
      email = mk str "homelab@jm0.io" "The user's email.";
      extra = {
        groups = mk (listOf str) [ ] "Extra groups to assign";
        options = mk attrs { } "Extra options to pass to <option>users.users.<name></option>.";
      };
    };
  config =
    {
      cfg,
      pkgs,
      ...
    }:
    {
      environment.pathsToLink = [ "/share/zsh" ];

      programs.zsh = {
        enable = true;
        autosuggestions.enable = true;
        histFile = "$XDG_CACHE_HOME/zsh.history";
      };

      home-manager = {
        backupFileExtension = "hm.bak";

        useUserPackages = true;
        useGlobalPkgs = true;

        verbose = true;
      };

      users.users.${cfg.name} = {
        inherit (cfg) name;
        shell = pkgs.zsh;

        extraGroups = [
          "users"
          "wheel"
          "systemd-journal"
          "audio"
          "video"
          "nix"
        ]
        ++ cfg.extra.groups;

        group = cfg.name;
        home = "/home/${cfg.name}";
        isNormalUser = true;
      }
      // cfg.extra.options;
    };
}
