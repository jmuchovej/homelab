{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "editor.neovim";
  options = with lib.rebellion; {
    default = mkopt-enable "neovim as the default $EDITOR";
  };
  config =
    {
      cfg,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf mkForce;
      inherit (lib.rebellion) enabled;
    in
    {

      # home.file = mkIf pkgs.stdenv.isDarwin { "Library/Preferences/glow/glow.yml".text = config; };

      home.sessionVariables.EDITOR = mkIf cfg.default (mkForce "nvim");

      programs.neovim = enabled;

      home.packages = with pkgs; [
        # (khanelivim.packages.${system}.default.extend {
        #   plugins.lsp.servers.nixd.settings =
        #     let
        #       flake = ''(builtins.getFlake "${inputs.self}")'';
        #     in
        #     {
        #       options = rec {
        #         nix-darwin.expr = ''${flake}.darwinConfigurations.khanelimac.options'';
        #         nixos.expr = ''${flake}.nixosConfigurations.khanelinix.options'';
        #         home-manager.expr = ''${nixos.expr}.home-manager.users.type.getSubOptions [ ]'';
        #       };
        #     };
        # })
        nvrh
      ];

      # sops.secrets = lib.mkIf osConfig.rebellion.security.sops.enable {
      #   wakatime = {
      #     sopsFile = lib.snowfall.fs.get-file "secrets/khaneliman/default.yaml";
      #     path = "${config.home.homeDirectory}/.wakatime.cfg";
      #   };
      # };

      # xdg.configFile = mkIf pkgs.stdenv.isLinux { "glow/glow.yml".text = config; };
    };
}
