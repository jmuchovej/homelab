{
  config,
  lib,
  namespace,
  system,
  inputs,
  pkgs,
  osConfig,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkBoolOpt;
  # inherit (inputs) khanelivim;

  cfg = config.${namespace}.programs.editors.neovim;
in
{
  options.${namespace}.programs.editors.neovim = {
    enable  = mkEnableOption "neovim";
    default = mkEnableOption "Neovim as the default $EDITOR";
  };

  config = mkIf cfg.enable {
    # home.file = mkIf pkgs.stdenv.isDarwin { "Library/Preferences/glow/glow.yml".text = config; };

    home.sessionVariables = {
      EDITOR = mkIf cfg.default "nvim";
    };

    home.packages = (with pkgs; [
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
    ]);

    # sops.secrets = lib.mkIf osConfig.${namespace}.security.sops.enable {
    #   wakatime = {
    #     sopsFile = lib.snowfall.fs.get-file "secrets/khaneliman/default.yaml";
    #     path = "${config.home.homeDirectory}/.wakatime.cfg";
    #   };
    # };

    # xdg.configFile = mkIf pkgs.stdenv.isLinux { "glow/glow.yml".text = config; };
  };
}
