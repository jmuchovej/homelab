{
  lib,
  __findFile,
  den,
  ...
}:
{
  den.aspects.lab = {
    includes = [
      <rbn/suite/common>
      (den.batteries.user-shell "zsh")

      # Terminal programs
      <rbn/programs/vcs/gh>
      <rbn/programs/terminal/zellij>
      <rbn/programs/terminal/bacon>
      <rbn/programs/terminal/k9s>
      <rbn/programs/toolchains/development>
      <rbn/programs/terminal/topgrade>

      # Core
      <rbn/programs/vcs/lazygit>

      <rbn/programs/ai-tools/claude/code>
      <rbn/programs/ai-tools/mcp>

      # Editors
      <rbn/programs/editors/helix>
      <rbn/programs/editors/micro>
    ];

    nixos =
      { host, lib, ... }:
      lib.mkMerge [
        {
          users.users.lab = {
            home = lib.mkForce "/lab";
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
            ];
          };
        }
        (lib.optionalAttrs (host.persistence != null) {
          environment.persistence."/persist".directories = [
            {
              directory = "/lab";
              user = "lab";
              group = "users";
              mode = "0700";
            }
          ];
        })
      ];

    homeManager.home.homeDirectory = lib.mkForce "/lab";
  };

  den.hosts.x86_64-linux.da-vcx-1.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-2.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-3.users.lab = { };
  den.hosts.x86_64-linux.da-gr75.users.lab = { };

  den.hosts.x86_64-linux.en-t65-1.users.lab = { };
}
