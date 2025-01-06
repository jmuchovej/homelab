{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) types mkIf mkOption;
  inherit (lib.types) nullOr str int;

  cfg = config.${namespace}.user;
in {
  options.${namespace}.user = {
    name = mkOption {
      type = str;
      default = "john";
      description = "The user account.";
    };
    email = mkOption {
      type = str;
      default = "jmuchovej@pm.me";
      description = "The user's email.";
    };
    fullName = mkOption {
      type = str;
      default = "John Muchovej";
      description = "The user's full name";
    };
    uid = mkOption {
      type = nullOr int;
      default = 501; # 'cause apple's weird >.>
      description = "The user's account UID.";
    };
  };

  config = {
    users.users.${cfg.name} = {
      uid = mkIf (cfg.uid != null) cfg.uid;
      shell = pkgs.zsh;
    };
  };
}
