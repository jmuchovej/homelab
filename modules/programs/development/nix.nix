_: {
  rbn.programs._.development._.nix.homeManager =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;

      vsc-extensions = with pkgs.open-vsx; [
        jnoortheen.nix-ide
        # arrterian.nix-env-selector
      ];
      vsc-user-settings = { };

      zed = {
        # https://github.com/zed-extensions/nix
        extensions = [ "nix" ];
        extraPackages = with pkgs; [
          nixd
          nixfmt
          nix-output-monitor
        ];
        userSettings = {
          languages.Nix = {
            tab_size = 2;
            language_servers = [
              "nixd"
              "!nil"
            ];
          };
          lsp.nixd = {
            initialization_options = {
              formatting.command = [
                "nixfmt"
                "--quiet"
                "--"
              ];
            };
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        nixd
        nil
        nixfmt
        nix-prefetch-git
        hydra-check
        nixpkgs-hammering
        nixpkgs-lint-community
        nixpkgs-review
        nix-update
        nix-output-monitor
        alejandra
      ];

      programs.vscode = mkIf (config.programs.vscode.enable or false) {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf (config.programs.zed-editor.enable or false) {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
