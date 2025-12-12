{
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption;
in
{
  options.rebellion.virtualization = {
    enable = mkEnableOption "virtualization" // {
      description = "No-op for setting up hierarchy.";
    };
  };
}
