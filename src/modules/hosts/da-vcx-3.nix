{ __findFile, ... }:
{
  den.aspects.da-vcx-3 = {
    includes = [
      <rbn/suite/server>
      <rbn/programs/security/sops>
    ];

    nixos = {
      imports = [
        ./_da-vcx-3/hardware.nix
      ];
      system.stateVersion = "24.05";
    };
  };
}
