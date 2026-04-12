{ __findFile, ... }:
{
  rbn.suite._.common = {
    includes = [
      # Cross-platform system
      <rbn/system/nix>
      <rbn/system/environment>
      <rbn/services/openssh>
      <rbn/security/sops>
      <rbn/services/tailscale>
      <rbn/system/fonts>
      <rbn/security/certificates>
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
