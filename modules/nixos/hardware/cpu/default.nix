{
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption;
in
{
  options.${namespace}.hardware.cpu = {
    enable = mkEnableOption "cpu" // {
      description = "No-op for setting up hierarchy.";
    };
  };
}
