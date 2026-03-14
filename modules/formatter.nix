{
  inputs,
  self,
  lib,
  ...
}:
{
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];

  imports =
    lib.optional (inputs ? treefmt-nix) inputs.treefmt-nix.flakeModule
    ++ lib.optional (inputs ? git-hooks-nix) inputs.git-hooks-nix.flakeModule;

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      # Bundle system CA certs with homelab CA for SSL trust
      caBundle =
        let
          homelabCA = "${self}/secrets/certificates/da/ca.crt";
          systemCerts = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        in
        pkgs.runCommand "ca-bundle-with-homelab" { } ''
          cat ${systemCerts} > $out
          echo "" >> $out
          cat ${homelabCA} >> $out
        '';
    in
    {
      _module.args.pkgs = lib.mkDefault (
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );

      # ── treefmt ──────────────────────────────────────────────────────
      treefmt = lib.mkIf (inputs ? treefmt-nix) {
        flakeCheck = true;
        flakeFormatter = true;
        projectRootFile = "flake.nix";

        settings.global.excludes = [
          "assets/**"
          ".devenv/**"
          ".direnv/**"
          "*.png"
          "*.gif"
          "*.ico"
          "*.svg"
          "*.jpg"
          "*.jpeg"
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
          statix.enable = true;
          deadnix = {
            enable = true;
            no-lambda-pattern-names = true;
          };
          nixfmt.enable = true;
          clang-format.enable = true;
          gofmt.enable = true;
          stylua.enable = true;
          isort.enable = true;
          ruff-check.enable = true;
          ruff-format.enable = true;
          rustfmt.enable = true;
          shfmt = {
            enable = true;
            indent_size = 2;
          };
          terraform = {
            enable = true;
            package = pkgs.opentofu;
            includes = [
              "*.tf"
              "*.tofu"
            ];
          };
          just.enable = true;
          xmllint.enable = true;
        };
      };

      # ── pre-commit hooks ─────────────────────────────────────────────
      pre-commit = lib.mkIf (inputs ? git-hooks-nix) {
        check.enable = false;
        settings.hooks = {
          pre-commit-hook-ensure-sops.enable = true;
          treefmt = {
            enable = true;
            settings.no-cache = false;
          };
        };
      };

      # ── deploy-rs checks ─────────────────────────────────────────────
      checks = lib.optionalAttrs pkgs.stdenv.isLinux (
        lib.optionalAttrs (inputs ? deploy) (
          inputs.deploy.lib.${pkgs.stdenv.hostPlatform.system}.deployChecks self.deploy
        )
      );

      # ── dev shell ────────────────────────────────────────────────────
      devShells.default = pkgs.mkShell {
        packages =
          with pkgs;
          [
            nixos-render-docs
            d2
            git
            sops
            tmux
            ssh-to-age
            ssh-to-pgp
            age
            python3
            opentofu
            consul
            nomad
            openbao
            mkpasswd
          ]
          ++ lib.optional (inputs ? treefmt-nix) config.treefmt.build.wrapper;

        env = {
          NIX_SSL_CERT_FILE = "${caBundle}";
          SSL_CERT_FILE = "${caBundle}";
          TREEFMT_ALLOW_MISSING_FORMATTER = "1";
        };

        shellHook =
          (lib.optionalString (inputs ? git-hooks-nix) config.pre-commit.installationScript)
          + ''

            # Sync project-specific skills into tool-specific locations.
            mkdir -p .claude
            rm -rf .claude/skills
            ln -snf "$(pwd)/skills" .claude/skills
          '';
      };
    };
}
