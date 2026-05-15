{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        flakeCheck = true;
        flakeFormatter = true;
        projectRootFile = "flake.nix";

        settings.global.excludes = [
          "assets/**"
          # Build artifacts
          ".devenv/**"
          ".direnv/**"
          # Binary / image files
          "*.png"
          "*.gif"
          "*.ico"
          "*.svg"
          "*.jpg"
          "*.jpeg"
          # Config / dotfiles
          "*.editorconfig"
          "*.envrc"
          "*.gitconfig"
          "*.git-blame-ignore-revs"
          "*.gitignore"
          "*.gitattributes"
          "*CODEOWNERS"
          "*LICENSE"
          "*flake.lock"
          "*Makefile"
          "*makefile"
          "*justfile"
          "*.xml"
          "*.zsh"
          "*.kdl"
        ];

        settings.global.on-unmatched = "info";
        settings.formatter.ruff-format.options = [ "--isolated" ];

        programs = {
          # Nix
          statix.enable = true;
          deadnix = {
            enable = true;
            no-lambda-pattern-names = true;
          };
          nixfmt.enable = true;

          # C/C++
          clang-format.enable = true;

          # Go
          gofmt.enable = true;

          # JS/TS/YAML/TOML/etc.
          # oxfmt.enable = true;

          # Lua
          stylua.enable = true;

          # Python
          isort.enable = true;
          ruff-check.enable = true;
          ruff-format.enable = true;

          # Rust
          rustfmt.enable = true;

          # Shell
          shfmt = {
            enable = true;
            indent_size = 2;
          };

          # HCL/Terraform
          terraform = {
            enable = true;
            package = pkgs.opentofu;
            includes = [
              "*.tf"
              "*.tofu"
            ];
          };

          # Misc
          just.enable = true;
          xmllint.enable = true;
        };
      };
    };
}
