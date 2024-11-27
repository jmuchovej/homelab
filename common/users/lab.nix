{ config, pkgs, ... }: {
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lab = {
    uid           = 1000;
    isNormalUser  = true;
    description   = "Homelab";
    extraGroups   = [ "wheel" "video" "docker" ];
    shell         = pkgs.zsh;
    packages      = with pkgs; [ ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
    ];
  };
}
