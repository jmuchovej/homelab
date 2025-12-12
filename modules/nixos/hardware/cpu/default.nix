{
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption;
in
{
  options.rebellion.hardware.cpu = {
    enable = mkEnableOption "cpu" // {
      description = "No-op for setting up hierarchy.";
    };
  };
}
