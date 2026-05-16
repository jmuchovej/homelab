{
  inputs,
  den,
  lib,
  ...
}:
{
  flake-file.inputs = {
    den.url = "github:denful/den";
    flake-file.url = "github:denful/flake-file";
  };

  imports = [
    (inputs.den.flakeModules.dendritic or { })
    (inputs.flake-file.flakeModules.dendritic or { })
    (inputs.den.namespace "rbn" true)
  ];

  _module.args.__findFile = den.lib.__findFile;

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
}
