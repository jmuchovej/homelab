{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.onepassword-cli";
  options = {
    enableSshSocket = lib.rebellion.mkopt-enable "1password's ssh-agent socket";
  };
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) optionalString;
    in
    {
      home.packages = [ pkgs._1password-cli ];

      programs = {
        ssh.extraConfig = optionalString cfg.enableSshSocket ''
          Host *
            AddKeysToAgent yes
            IdentityAgent ~/.1password/agent.sock
        '';
      };
    };
}
