_: {
  rbn.programs._.desktop._.openconnect.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.openconnect_openssl ];
    };
}
