{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.sops";
  options =
    { config, lib, ... }:
    let
      inherit (lib.types) path listOf;
      inherit (lib.rebellion) options;
      inherit (lib.rebellion.fs) get-file;

      username = config.rebellion.user.name;
      default-sops-file =
        if username != null then get-file "secrets/homes/${username}.sops.yaml"
        else get-file "secrets/homes/default.sops.yaml";
    in
    {
      default-sops-file = options.mk path default-sops-file "Default sops file.";
      ssh-key-paths = options.mk (listOf path) [
        "/etc/ssh/ssh_host_ed25519_key"
      ] "SSH Key paths to use.";
    };
  config =
    {
      cfg,
      config,
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
        defaultSopsFile = cfg.default-sops-file;
        defaultSopsFormat = "yaml";

        age = {
          # TODO(jmuchovej): re-enable once `lab` has an SSH key to write
          # generateKey = true;
          keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
          sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ] ++ cfg.ssh-key-paths;
        };

        secrets."nix".path = "${config.home.homeDirectory}/.config/nix/nix.conf";
      };
    };
}
