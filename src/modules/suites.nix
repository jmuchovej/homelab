{ __findFile, ... }: {
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

      # NixOS (no-ops on darwin)
      <rbn/system/boot>
      <rbn/system/hardware/storage/ssd>

      # Security (GPG, age, sops — cross-platform)
      <rbn/programs/security>

      # macOS infrastructure (no-ops on NixOS)
      <rbn/system/input>

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
      <rbn/programs/security/proton>
      <rbn/programs/editors/neovim>
      <rbn/shells/bash>
      <rbn/shells/zsh>
    ];

    # Shared across NixOS and darwin
    os = { pkgs, ... }: {
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
        usbutils
      ];
    };
  };

  rbn.suite._.desktop = {
    includes = [
      <rbn/system/fonts>
      <rbn/programs/security/onepassword>
      <rbn/programs/security/proton>
    ];
  };

  rbn.suite._.development = {
    includes = [
      <rbn/programs/development>
    ];
  };

  rbn.suite._.server = {
    includes = [
      <rbn/programs/emulators/ghostty>
    ];

    nixos =
      { config, lib, ... }:
      let
        inherit (lib.rbn) get-secret';
      in
      lib.mkMerge [
        (get-secret' config "lab/password")
        {
          documentation = {
            enable = lib.mkForce false;
            info.enable = lib.mkForce false;
            man.enable = lib.mkForce true;
            nixos.enable = lib.mkForce true;
          };

          users.mutableUsers = false;

          sops.secrets."lab/password".neededForUsers = true;

          users.users.lab = {
            hashedPasswordFile = config.sops.secrets."lab/password".path;
            isNormalUser = true;
            extraGroups = [
              "wheel"
              "video"
              "games"
            ];
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO lab@home.jm0.io"
            ];
          };

          systemd = {
            network.wait-online.enable = false;
            enableEmergencyMode = false;
          };
        }
      ];
  };
}
