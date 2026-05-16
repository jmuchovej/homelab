{ __findFile, ... }:
{
  rbn.suite._.common = {
    includes = [
      # Cross-platform system
      <rbn/system/nix>
      <rbn/system/nix-builders>
      <rbn/system/environment>
      <rbn/services/openssh>
      <rbn/programs/security/sops>
      <rbn/services/tailscale>
      <rbn/system/fonts>
      <rbn/system/security/certificates>
      <rbn/system/networking>
      <rbn/system/home-manager>
      <rbn/system/dock>

      # NixOS (no-ops on darwin)
      <rbn/system/boot>
      <rbn/system/hardware/storage/ssd>

      # Security (GPG, age, sops — cross-platform)
      <rbn/programs/security>

      # macOS infrastructure (no-ops on NixOS)
      <rbn/system/homebrew>

      # CLI tools
      <rbn/programs/baseline>
      <rbn/programs/terminal/bat>
      <rbn/programs/terminal/bottom>
      <rbn/programs/terminal/carapace>
      <rbn/programs/terminal/eza>
      <rbn/programs/terminal/fzf>
      <rbn/programs/terminal/ripgrep>
      <rbn/programs/terminal/ssh>
      <rbn/programs/terminal/starship>
      <rbn/programs/terminal/rclone>
      <rbn/programs/terminal/readline>
      <rbn/programs/terminal/tmux>
      <rbn/programs/terminal/zoxide>
      <rbn/programs/security/onepassword>
      <rbn/programs/vcs/git>
      <rbn/programs/vcs/jujutsu>
      <rbn/programs/editors/neovim>
      <rbn/shells/bash>
      <rbn/shells/zsh>
    ];

    # Shared across NixOS and darwin
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          coreutils
          curl
          fd
          file
          git
          findutils
          lsof
          pciutils
          tldr
          unzip
          wget
          xclip
        ];
      };

    # NixOS-only extras
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.usbutils ];
      };
  };
}
