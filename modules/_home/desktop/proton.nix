{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.proton";
  options =
    let
      inherit (lib.rebellion.options) mk-enable';
    in
    {
      mail = {
        desktop = mk-enable' "ProtonMail Desktop";
        bridge = mk-enable' "ProtonMail Bridge";
      };

      vpn = mk-enable' "Proton VPN";
      pass = mk-enable' "Proton Pass";
    };
  conditions =
    { cfg, ... }:
    cfg.mail.desktop.enable || cfg.mail.bridge.enable || cfg.vpn.enable || cfg.pass.enable;
  config = _: {
    # TODO needs upstream support
    # home.packages = ([]
    #   ++ optionals cfg.mail.desktop.enable [ pkgs.protonmail-desktop ]
    #   ++ optionals cfg.mail.bridge.enable  [ pkgs.protonmail-bridge  ]
    #   ++ optionals cfg.vpn.enable          [ pkgs.protonvpn-cli      ]
    #   ++ optionals cfg.pass.enable         [ pkgs.proton-pass        ]
    # );
  };
}
