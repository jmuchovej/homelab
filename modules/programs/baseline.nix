_: {
  rbn.programs._.baseline = {
    homeManager =
      {
        lib,
        pkgs,
        config,
        ...
      }:
      let
        inherit (lib) optionals;
        inherit (lib.rebellion) enabled;
        inherit (pkgs.stdenv) isLinux isDarwin;
      in
      {
        home.packages =
          with pkgs;
          [
            optinix
            gnupg
            age
            httpie
            hyperfine
            erdtree
            rust-motd

            jaq
            yq-go
            jqp
            jnv

            parallel
            choose
            curlie
            doggo
            duf
            dust
            dua
            gping
            fd
            procs
            ov
            sd
            viddy
            just
            ouch

            nmap
            speedtest-cli
          ]
          ++ optionals isLinux [ iproute2 ]
          ++ optionals isDarwin [ iproute2mac ];

        programs.nh = enabled;
        programs.nix-your-shell = enabled;

        programs.nix-index-database.comma.enable = true;

        programs.nix-index = {
          enable = true;
          package = pkgs.nix-index;

          enableBashIntegration = config.programs.bash.enable or false;
          enableZshIntegration = config.programs.zsh.enable or false;

          symlinkToCacheHome = true;
        };
      };

    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          gawk
          gnugrep
          gnupg
          gnused
          gnutls
          terminal-notifier
          trash-cli
        ];
      };
  };
}
