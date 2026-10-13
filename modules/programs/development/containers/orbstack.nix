{ den, ... }: {
  rbn.programs._.development._.containers._.orbstack = {
    includes = [ (den.batteries.unfree [ "orbstack" ]) ];

    # `$out/bin` also carries `docker`, `docker-compose`, and `kubectl`.
    #   since `k9s` provides `kubectl`, `lib.lowPrio` on orbstack makes it lose
    #   every name clash.
    hm-macos = { lib, pkgs, ... }: {
      home.packages = [ (lib.lowPrio pkgs.orbstack) ];
    };
  };
}
