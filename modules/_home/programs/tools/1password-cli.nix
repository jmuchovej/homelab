{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.onepassword-cli";
  options =
    let
      inherit (lib.rebellion.options) mk-enable';
    in
    {
      ssh-socket = mk-enable' "1password's ssh-agent socket";
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs._1password-cli ];

      programs = {
        ssh.extraConfig = lib.optionalString cfg.ssh-socket.enable ''
          Host *
            AddKeysToAgent yes
            IdentityAgent ~/.1password/agent.sock
        '';
      };
    };
}
