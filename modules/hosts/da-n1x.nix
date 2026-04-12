{ __findFile, ... }:
{
  den.hosts.aarch64-darwin.da-n1x = {
    user = {
      name = "john";
      email = "john@jm0.io";
      full-name = "John Muchovej";
      uid = 501;
    };
    homebrew = {
      enable = true;
      mas.enable = true;
    };
    notunes.enable = true;
  };

  den.aspects.da-n1x = {
    includes = [
      <rbn/suite/desktop>
      <rbn/suite/development>
      <rbn/programs/media/spotify>
    ];
  };
}
