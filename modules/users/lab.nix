{ __findFile, ... }:
{
  den.aspects.lab = {
    includes = [
      # Terminal programs
      <rbn/programs/terminal/eza>
      <rbn/programs/terminal/ripgrep>
      <rbn/programs/terminal/starship>
      <rbn/programs/terminal/zoxide>
      <rbn/programs/vcs/gh>
      <rbn/programs/terminal/fzf>
      <rbn/programs/terminal/readline>
      <rbn/programs/terminal/tmux>
      <rbn/programs/terminal/bottom>
      <rbn/programs/terminal/bacon>
      <rbn/programs/toolchains/development>
      <rbn/programs/terminal/rclone>
      <rbn/programs/terminal/topgrade>

      # Core
      <rbn/programs/vcs/git>
      <rbn/programs/terminal/ssh>
      <rbn/security/sops>

      # Editors
      <rbn/programs/editors/neovim>

      # Shells
      <rbn/shells/zsh>
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

  den.hosts.x86_64-linux.en-t65-1.users.lab = { };
}
