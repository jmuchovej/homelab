{
  config,
  lib,
  inputs,
  pkgs,
  osConfig,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkForce;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.editor.neovim;
in
{
  options.rebellion.editor = {
    neovim = {
      enable = mkEnableOption "neovim";
      default = mkEnableOption "Neovim as the default $EDITOR";
    };
  };

  config = mkIf cfg.enable {
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
