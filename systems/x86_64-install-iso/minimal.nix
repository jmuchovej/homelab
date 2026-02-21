{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkForce;
  inherit (lib.rebellion) enabled;
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  disko.devices = { };

  networking.wireless.enable = mkForce false;

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    pciutils
    file
  ];

  rebellion = {
    programs.editors.neovim = enabled;
    programs.tools = {
      tmux = enabled;
      starship = enabled;
      bat = enabled;
      eza = enabled;
    };
    programs.shells = {
      zsh = enabled;
    };

    services.openssh = enabled;
    security.doas = enabled;

    system.networking = enabled;
  };

  system.stateVersion = "24.11";
}
