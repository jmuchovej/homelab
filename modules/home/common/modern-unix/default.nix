{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib)
    mkForce
    mkDefault
    types
    optionals
    ;
  inherit (lib.${namespace}) enabled;
  inherit (pkgs.stdenv) isLinux isDarwin;

  cfg = config.${namespace}.modern-unix;
in
{
  # Since there _isn't_ a machine I use where the CLI isn't also configured,
  #   these are "sane defaults" I expect on any of my machines.
  options.${namespace}.modern-unix = with types; {
  };

  config = {
    home.shellAliases = {
      nixcfg = "$EDITOR ~/Syncthing/${namespace}/flake.nix";
    };

    home.sessionVariables.EDITOR = "nvim";

    home.packages =
      with pkgs;
      [
        # Useful packages that aren't tied to specific workflows
        optinix # search nix options!
        gnupg # GPG
        age # A more modern encryption tool
        httpie # ez HTTP querying
        hyperfine # benchmarking
        erdtree # `ls`, but with directory sizes
        rust-motd # Fancy MOTD

        # Interact with JSON, YAML, and TOML data structures
        jaq
        yq-go # JQ (rust), YQ (go), and TQ (go, from YQ)
        jqp
        jnv # Do jq things, interactively

        # Generic Linux tool replacements
        parallel
        # rust-parallel   # replaces: parallel
        # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/tr/trashy/package.nix#L39
        #! TODO not supported on macOS ;(
        # broot           # replaces: ls??, tree
        choose # replaces: cut, awk
        curlie # replaces: curl
        doggo # replaces: dig
        duf # replaces: df
        dust # replaces: du
        dua # replaces: du
        gping # replaces: `ping`
        fd # replaces: find
        procs # replaces: ps
        # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/tr/trashy/package.nix#L39
        #! TODO not supported on macOS ;(
        # trashy          # replaces: rm
        ov # replaces: less, tail, more, tail
        sd # replaces: sed
        # xcp             # replaces: cp
        viddy # replaces: watch
        just # replaces: make
        ouch # replaces: unzip, tar, zip, etc.

        devenv

        nmap
        speedtest-cli
      ]
      ++ optionals isLinux [ iproute2 ]
      ++ optionals isDarwin [ iproute2mac ];

    programs.nix-index = enabled;
    programs.nix-your-shell = enabled;

    # region bat #############################################################
    programs.bat = {
      enable = true;

      config = {
      };

      extraPackages = with pkgs.bat-extras; [
        batdiff
        batgrep
        batman
        batpipe
        batwatch
        prettybat
      ];
    };

    home.shellAliases = {
      cat = "bat";
    };
    # endregion ##############################################################

    # region eza #############################################################
    programs.eza = {
      enable = true;
      package = pkgs.eza;

      extraOptions = [
        "--group"
        "--group-directories-first"
        "--header"
        "--hyperlink"
        "--git-ignore"
      ];

      # TODO does this work on linux-arm64 yet?
      git = true;
      icons = "auto";
      colors = "auto";
    };

    home.shellAliases = {
      # home-manager already configures `ls`, `ll`, `la`, `lt`, and `lla`
      tree = mkForce "lt";
    };
    # endregion ##############################################################

    # region ripgrep #########################################################
    programs.ripgrep = {
      enable = true;
      arguments = [
        # Avoid dumping long lines to shell
        # "--max-columns=80"
        "--max-columns-preview"
        # Search hidden files
        "--hidden"
        # Ignore casing
        "--smart-case"
        # Follow symlinks while searching
        "--follow"
      ];
    };
    # endregion ##############################################################

    # region starship ########################################################
    programs.starship = {
      enable = true;
      package = pkgs.starship;
      # Note: The preset option was removed. Use `starship preset pure-preset` to generate
      # a config and add it to programs.starship.settings if needed.
    };
    # endregion ##############################################################

    # region zoxide ##########################################################
    programs.zoxide = {
      enable = true;
      package = pkgs.zoxide;
      options = [
        "--cmd z" # Replaces `z` and `zi`
      ];
    };
    # endregion ##############################################################

    # region gh ##############################################################
    programs.gh = {
      enable = true;
      package = pkgs.gh;
      settings = {
        protocol = "ssh";
        prompt = "enabled";
        aliases = { };
      };
    };

    programs.gh-dash = {
      enable = true;
      package = pkgs.gh-dash;
      # settings = { };
    };
    # endregion ##############################################################

    # region fzf #############################################################
    programs.fzf = {
      enable = true;

      defaultCommand = "fd --type=f --hidden --exclude=.git";
      defaultOptions = [
        "--layout=reverse" # Top-first.
        "--exact" # Substring matching by default, `'`-quote for subsequence matching.
        "--bind=alt-p:toggle-preview,alt-a:select-all"
        "--multi"
        "--no-mouse"
        "--info=inline"

        # Style and widget layout
        "--ansi"
        "--with-nth=1.."
        "--pointer=' '"
        "--pointer=' '"
        "--header-first"
        "--border=rounded"
      ];

      tmux = {
        enableShellIntegration = true;
      };
    };
    # endregion ##############################################################

    # region readline ########################################################
    programs.readline = {
      enable = mkDefault true;

      extraConfig = ''
        set completion-ignore-case on
      '';
    };
    # endregion ##############################################################

    # region tmux ############################################################
    programs.tmux = {
      enable = true;
      aggressiveResize = true;
      baseIndex = 1;
      clock24 = true;
      escapeTime = 0;
      historyLimit = 2000;
      keyMode = "vi";
      mouse = true;
      newSession = true;
      prefix = "`";
      sensibleOnTop = true;
      terminal = "xterm-256color";
    };
    # endregion ##############################################################

    # region bottom ##########################################################
    programs.bottom = {
      enable = true;
      package = pkgs.bottom;

      settings = {
        flags = {
          # https://clementtsang.github.io/bottom/nightly/configuration/config-file/flags/
          tree = true;
          group_processes = true;
          show_table_scroll_position = true;
        };

        row = [
          {
            ratio = 3;
            child = [
              { type = "cpu"; }
              { type = "mem"; }
              { type = "net"; }
            ];
          }
          {
            ratio = 3;
            child = [
              {
                type = "proc";
                ratio = 1;
                default = true;
              }
            ];
          }
        ];
      };
    };
    # endregion ##############################################################

    # region bacon ############################################################
    # https://github.com/Canop/bacon/issues/65
    # https://dystroy.org/blog/bacon-everything-roadmap/
    programs.bacon = {
      enable = true;
      # package = pkgs.bacon;
    };
    # endregion ###############################################################

    # region devenv ###########################################################
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    # endregion ###############################################################

    # region rclone ##########################################################
    programs.rclone = {
      enable = true;
      # remotes = {
      #   Drive = {
      #     config = {
      #       type = "drive";
      #     };
      #     secrets = {
      #         account = config.sops.secrets."rclone/drive/account".path;
      #         key     = config.sops.secrets."rclone/drive/key".path;
      #     };
      #   };
      #   Dropbox = {
      #     config = {
      #       type = "dropbox";
      #     };
      #     secrets = {
      #         account = config.sops.secrets."rclone/dropbox/account".path;
      #         key     = config.sops.secrets."rclone/dropbox/key".path;
      #     };
      #   };
      #   Proton = {
      #     config = {
      #       type = "protondrive";
      #     };
      #     secrets = {
      #         account = config.sops.secrets."rclone/proton/account".path;
      #         key     = config.sops.secrets."rclone/proton/key".path;
      #     };
      #   };
      #   MinIO = {
      #     config = {
      #       type = "s3";
      #       provider = "minio";
      #     };
      #     secrets = {
      #         account = config.sops.secrets."rclone/minio/account".path;
      #         key     = config.sops.secrets."rclone/minio/key".path;
      #     };
      #   };
      #   iCloud = {
      #     config = {
      #       type = "iclouddrive";
      #     };
      #     secrets = {
      #         apple_id    = config.sops.secrets."rclone/icloud/account".path;
      #         password    = config.sops.secrets."rclone/icloud/password".path;
      #       config_2fa  = config.sops.secrets."rclone/icloud/2fa".path;
      #     };
      #   };
      # };
    };
    # endregion ##############################################################

    # region Topgrade ########################################################
    programs.topgrade = {
      enable = true;

      settings = {
        misc = {
          no_retry = true;
          display_time = true;
          skip_notify = true;
        };
        git = {
          repos = [
            "~/Documents/github/*/"
            "~/Documents/gitlab/*/"
            "~/.config/.dotfiles/"
            "~/.config/nvim/"
          ];
        };
      };
    };
    # endregion ##############################################################
  };
}
