{ inputs, ... }:
let
  sops-file = kind: name: "${inputs.self}/secrets/${kind}/${name}.sops.yaml";
in
{
  rbn.programs._.security._.sops = {
    nixos =
      { host, pkgs, ... }:
      let
        inherit (host) hostname;
      in
      {
        environment.systemPackages = with pkgs; [
          age
          sops
          ssh-to-age
        ];

        sops = {
          defaultSopsFile = sops-file "hosts" hostname;

          age = {
            sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
            generateKey = false;
          };
        };
      };

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        home = config.home.homeDirectory;
      in
      {
        home.packages = with pkgs; [
          age
          sops
          ssh-to-age
        ];

        sops = {
          defaultSopsFile = sops-file "users" config.home.username;
          defaultSopsFormat = "yaml";

          age = {
            keyFile = lib.mkDefault "${home}/.config/sops/age/keys.txt";
            sshKeyPaths = [
              "${home}/.ssh/id_ed25519"
              "/etc/ssh/ssh_host_ed25519_key"
            ];
          };

          # Tokens-only payload (e.g. `access-tokens = github.com=...`).
          # HM owns ~/.config/nix/nix.conf and pulls this in via `!include`.
          secrets."nix-access-tokens" = { };
        };
      };
  };
}
