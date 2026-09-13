{
  rbn.programs._.development._.nix.hm =
    { pkgs, lib, ... }:
    let
      inherit (import ./_lsp.nix { inherit lib; }) mk-lsp;

      nix-lsp = mk-lsp {
        pkg = pkgs.nixd;
        extensions.".nix" = "nix";
        # nixd execs the formatter itself and inherits the harness's bare
        # `$PATH`, so this must stay an absolute store path too.
        init.formatting.command = [
          (lib.getExe pkgs.nixfmt)
          "--quiet"
          "--"
        ];
      };
    in
    {
      home.packages = with pkgs; [
        alejandra
        graphviz
        hydra-check
        nil
        nix-du
        nix-init
        nix-melt
        nix-output-monitor
        nix-prefetch-git
        nix-tree
        nix-update
        nix-update
        nixd
        nixfmt
        nixpkgs-fmt
        nixpkgs-hammering
        nixpkgs-lint-community
        nixpkgs-review
        nurl
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
          nix-lsp.pkg
          nixfmt
          nix-output-monitor
        ];
        userSettings = {
          languages.Nix = {
            tab_size = 2;
            formatter = "language_server";
            language_servers = [
              "nixd"
              "!nil"
            ];
          };
          lsp.nixd = nix-lsp.zed;
        };
      };

      programs.claude-code.lspServers = {
        nix = nix-lsp.claude;
      };

      mcp-servers.programs.nixos.enable = true;

      home.shellAliases =
        let
          nr-bin = lib.getExe pkgs.nixpkgs-review;
        in
        {
          # Aliases take no parameters in any shell (bash/zsh/nu all append the
          # trailing args); a literal `$1` is empty in bash/zsh and a parse error in nu.
          prefetch-sri = "nix store prefetch-file";
          nrh = "${nr-bin} rev HEAD";
          nra = ''${nr-bin} pr --systems "all"'';
          nrap = ''${nr-bin} pr --systems "all" --post-result --num-parallel-evals 4'';
          nrd = ''${nr-bin} pr --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2'';
          nrdp = ''${nr-bin} pr --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2 --post-result'';
          nrl = ''${nr-bin} pr --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2'';
          nrlp = ''${nr-bin} pr --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2 --post-result'';
          nrmp = ''${nr-bin} pr --systems "x86_64-darwin aarch64-darwin aarch64-linux" --num-parallel-evals 3 --post-result'';
        };
    };
}
