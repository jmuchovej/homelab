{ lib, host ? null, namespace, ...  }: let
  inherit (lib) types mkOption;
in
{
  options.${namespace}.host = with types; {
    name = mkOption {
      type = nullOr str;
      default = host;
      description = "The host name.";
    };
  };
}
