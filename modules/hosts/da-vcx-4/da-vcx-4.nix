{ __findFile, den, ... }:
{
  den.aspects.da-vcx-4 = {
    includes = [
      <rbn/suite/server>
      <rbn/programs/security/sops>

      <rbn/services/zerotier>
    ];

    provides.to-users = {
      includes = with den.aspects; [
        (facter ./facter.json)
      ];
    };

    nixos = {
      system.stateVersion = "24.05";
    };
  };
}
