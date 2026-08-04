{
  rbn.programs._.baseline = {
    hm-linux = { pkgs, ... }: {
      home.packages = with pkgs; [ iproute2 ];
    };

    hm-macos = { pkgs, ... }: {
      home.packages = with pkgs; [ iproute2mac ];
    };

    hm = { pkgs, ... }: {
      home.packages = with pkgs; [
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
      ];

      programs.nh.enable = true;
      programs.topgrade.settings.misc.nix_handler = "nh";
      programs.nix-your-shell.enable = true;
      programs.command-not-found.enable = false;
      programs.nix-index-database.comma.enable = true;

      programs.nix-index = {
        enable = true;
        symlinkToCacheHome = true;
      };

      home.sessionVariables = {
      };
    };

    macos = { pkgs, ... }: {
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
