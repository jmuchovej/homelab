{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.sops";
  options =
    { config, lib, ... }:
    let
      inherit (lib.types) path listOf;
      inherit (lib.rebellion) mkopt get-file;

      username = config.rebellion.user.name;
      default-sops-file = get-file "secrets/homes/${username}.sops.yaml";
    in
    {
      defaultSopsFile = mkopt path default-sops-file "Default sops file.";
      sshKeyPaths = mkopt (listOf path) [ "/etc/ssh/ssh_host_ed25519_key" ] "SSH Key paths to use.";
    };
  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        age
        sops
        ssh-to-age
      ];

      sops = {
        inherit (cfg) defaultSopsFile;
        defaultSopsFormat = "yaml";

        age = {
          generateKey = true;
          keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
          sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ] ++ cfg.sshKeyPaths;
        };

        secrets."nix".path = "${config.home.homeDirectory}/.config/nix/nix.conf";
      };
    };
}
