{ lib, ... }:
let
  inherit (lib.rebellion) enabled;
in
{
  rebellion = {
    user = {
      name = "lab";
      real-name = "Homelab";
    };

    ssh = {
      authorized-keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
      ];
    };

    editor.neovim = enabled // {
      default = true;
    };
    shell.zsh = enabled;
    services.sops = enabled;

    # development = enabled;
  };

  # ======================== DO NOT CHANGE THIS ========================
  home.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
