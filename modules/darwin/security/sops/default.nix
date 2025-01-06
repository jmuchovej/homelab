{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) get-shared;

  cfg = config.${namespace}.security.sops;
in {
  imports = [(get-shared "security/sops")];

  config = mkIf cfg.enable {
    # sops.secrets = {
    #   "khanelimac_khaneliman_ssh_key" = {
    #     sopsFile = lib.snowfall.fs.get-file "secrets/khanelimac/khaneliman/default.yaml";
    #   };
    # };
  };
}
