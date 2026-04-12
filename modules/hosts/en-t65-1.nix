{ __findFile, ... }:
{
  den.aspects.en-t65-1 = {
    includes = [
      <rbn/suite/server>
      <rbn/security/sops>
    ];

    nixos = {
      imports = [
        ./_en-t65-1/hardware.nix
      ];
      system.stateVersion = "24.05";
    };
  };
}
