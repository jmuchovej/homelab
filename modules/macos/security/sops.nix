{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.security.sops;
in
{
  imports = [ (get-file "modules/shared/security/sops.nix") ];

  config = mkIf cfg.enable {
    # sops.secrets = {
    #   "khanelimac_khaneliman_ssh_key" = {
    #     sopsFile = lib.snowfall.fs.get-file "secrets/khanelimac/khaneliman.yaml";
    #   };
    # };
  };
}
