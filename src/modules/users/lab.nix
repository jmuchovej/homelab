{ __findFile, den, ... }:
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

    nixos.users.users.lab = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
      ];
    };
  };

  den.hosts.x86_64-linux.da-vcx-1.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-2.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-3.users.lab = { };
  den.hosts.x86_64-linux.da-gr75.users.lab = { };

  den.hosts.x86_64-linux.en-t65-1.users.lab = { };
}
