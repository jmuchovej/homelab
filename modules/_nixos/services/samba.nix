{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.samba = lib.mkIf false {
    package = pkgs.samba.override { enableMDNS = true; };
    settings.global = {
      security = "user";

      # Performance optimizations
      "use sendfile" = "yes";
      "aio read size" = 1;
      "aio write size" = 1;
      "min receivefile size" = 16384;

      # Mac-friendly settings
      "vfs objects" = "catia fruit streams_xattr";
      "fruit:aapl" = "yes";
      "fruit:resource" = "xattr";
      "fruit:metadata" = "stream";
      "fruit:encoding" = "native";
      "fruit:wipe_intentionally_left_blank_rfork" = "yes";
    };
  };

  sops.secrets.smbpasswd.mode = "600";

  system.activationScripts.sambaUserSetup = {
    text = ''
      ${lib.getBin pkgs.samba}/bin/pdbedit \
        -i smbpasswd:/run/secrets/smbpasswd \
        -e tdbsam:/var/lib/samba/private/passdb.tdb
    '';
    deps = [ "setupSecrets" ];
  };
}
