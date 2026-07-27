{
  rbn.programs._.development._.rust.homeManager = { pkgs, ... }: {
    home.packages = with pkgs; [
      cargo
      rustc
      cargo-binstall
      tombi
      # cargo-xtask — not in nixpkgs
    ];

    programs.vscode = {
      profiles.default.extensions = with pkgs.open-vsx; [
        rust-lang.rust-analyzer
        vadimcn.vscode-lldb
      ];
      profiles.default.userSettings = { };
    };

    # https://zed.dev/docs/languages/rust
    programs.zed-editor = {
      extensions = [ "tombi" ];
      extraPackages = with pkgs; [
        rust-analyzer
        tombi
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
  };
}
