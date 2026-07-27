{
  rbn.programs._.development._.nix.homeManager = { pkgs, ... }: {
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

    programs.vscode = {
      profiles.default.extensions = with pkgs.open-vsx; [
        jnoortheen.nix-ide
        # arrterian.nix-env-selector
      ];
      profiles.default.userSettings = { };
    };

    programs.zed-editor = {
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
  };
}
