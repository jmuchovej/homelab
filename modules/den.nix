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

    inputs.den.flakeModules.denTest
    inputs.den.flakeOutputs.tests
  ];

  _module.args.__findFile = den.lib.__findFile;

  denTest = {
    imports = [
      inputs.den.flakeOutputs.nixosConfigurations
      inputs.den.flakeOutputs.darwinConfigurations
    ];

    den.schema.host =
      { config, ... }:
      lib.mkIf (config.class == "darwin") {
        instantiate = lib.mkForce inputs.nix-darwin.lib.darwinSystem;
      };
  };

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
}
