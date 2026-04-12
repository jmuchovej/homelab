_: {
  rbn.programs._.development._.rust.homeManager =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;

      vsc-extensions = with pkgs.open-vsx; [
        rust-lang.rust-analyzer
        vadimcn.vscode-lldb
      ];
      vsc-user-settings = { };

      # https://zed.dev/docs/languages/rust
      zed = {
        extensions = [ ];
        extraPackages = with pkgs; [
          rust-analyzer
        ];
        userSettings = {
          languages.Rust = {
            tab_size = 2;
          };
          lsp.rust-analyzer = {
            initialization_options = {
              checkOnSave = true;
              check = {
                workspace = false;
              };
            };
            settings = {
              enable_lsp_tasks = true;
            };
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        cargo
        rustc
        cargo-binstall
        # cargo-xtask — not in nixpkgs
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
