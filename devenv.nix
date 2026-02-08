{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
  # https://devenv.sh/basics/
  env.PROJECT_ROOT = config.git.root;

  # Bundle system CA certs with homelab CA for SSL trust
  env.NIX_SSL_CERT_FILE =
    let
      homelabCA = ./secrets/certificates/da/ca.crt;
      systemCerts = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      caBundle = pkgs.runCommand "ca-bundle-with-homelab" { } ''
        cat ${systemCerts} > $out
        echo "" >> $out
        cat ${homelabCA} >> $out
      '';
    in
    "${caBundle}";

  # OpenTofu/Terraform and other tools check SSL_CERT_FILE
  env.SSL_CERT_FILE = config.env.NIX_SSL_CERT_FILE;

  # https://devenv.sh/packages/
  packages = with pkgs; [
    nixos-render-docs
    d2
    git
    sops
    tmux
    ssh-to-age
    ssh-to-pgp
    age
    consul
    nomad
    openbao
  ];

  # https://devenv.sh/languages/
  languages.python.enable = true;
  languages.opentofu.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/

  enterShell = '''';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = '''';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  env.TREEFMT_ALLOW_MISSING_FORMATTER = true;
  env.TREEFMT_VERBOSE = 1; # 0 = warn, 1 = info, 2 = debug
  treefmt = {
    enable = true;
    # Exclude generated/vendored code
    config.settings.global.excludes = [
      "app/rust_builder/cargokit/**"
      "**/macos/Runner/*"
      "**/macos/Flutter/*"
      "**/windows/runner/*"
      "**/windows/flutter/*"
      "*/frb_generated*"
      "*/node_modules/*"
      "*.png"
      "*.gif"
      "*.ico"
      ".gitignore"
      ".devenv/**"
      ".direnv/**"
    ];
    config.settings.global.on-unmatched = "info";
    config.programs = {
      statix.enable = true;
      clang-format.enable = true;
      rustfmt.enable = true;
      just.enable = true;
      ruff-check.enable = true;
      ruff-format.enable = true;
      # biome.enable = true;
      deno.enable = true;
      taplo.enable = true;
      xmllint.enable = true;
      terraform = {
        enable = true;
        package = pkgs.opentofu;
        includes = [
          "*.tf"
          "*.tofu"
        ];
      };
    };
  };
}
