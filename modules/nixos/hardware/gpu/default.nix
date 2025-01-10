{
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption;
in
{
  options.${namespace}.hardware.gpu = {
    enable = mkEnableOption "gpu" // {
      description = "No-op for setting up hierarchy.";
    };
  };
}
