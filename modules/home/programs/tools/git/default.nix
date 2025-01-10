{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit
    (lib)
    types
    mkIf
    mkEnableOption
    mkOption
    concatStringsSep
    getExe'
    mapAttrs'
    ;

  cfg = config.${namespace}.programs.tools.git;

  # rewriteURL =
  #   mapAttrs' (key: value: {
  #     name = "url.${key}";
  #     value = {insteadOf = value;};
  #   })
  #   cfg.urlRewrites;

  ov-bin = getExe' pkgs.ov "ov";
  delta-bin = getExe' pkgs.delta "delta";

  ov-diff = concatStringsSep " " [
    "${ov-bin}"
    "-F"
    "--section-delimiter"
    "'^(commit|added:|removed:|renamed:|Δ)'"
    "--section-header"
    "--pattern"
    "'•'"
  ];
  ov-log = concatStringsSep " " [
    "${ov-bin}"
    "-F"
    "--section-delimiter"
    "'^commit'"
    "--section-header-num"
    "3"
  ];
in {
  options.${namespace}.programs.tools.git = with types; {
    enable = mkEnableOption "git";
    email = mkOption {
      type = nullOr str;
      default = "jmuchovej@users.noreply.github.com";
      description = "The email to use with git.";
    };
    urlRewrites = mkOption {
      type = attrsOf str;
      default = {};
      description = "url we need to rewrite i.e. ssh to http";
    };
    allowedSigners = mkOption {
      type = str;
      default = "";
      description = "The public key used for signing commits";
    };
  };

  config = mkIf cfg.enable {
    home.file.".ssh/allowed_signers".text = "* ${cfg.allowedSigners}";

    xdg.configFile."git/ignore" = {
      enable = true;
      text = ''
        _research
      '';
    };

    home.packages = with pkgs; [
      delta
      difftastic
    ];

    programs.git-credential-oauth = {
      enable = true;
    };
    programs.git = {
      enable = true;
      userName = "John Muchovej";
      userEmail = cfg.email;

      extraConfig = {
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        # TODO migrate to platform-independent and don't do for remote hosts
        gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        commit.gpgsign = true;
        # user.signingkey = "~/.ssh/1p-github.pub";
        user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";

        core = {
          pager = "${delta-bin} --pager='${ov-bin} -F'";
        };

        color = {
          ui = true;
        };

        # https://noborus.github.io/ov-bin/delta-bin/index.html
        pager = {
          show = "${delta-bin} --pager='${ov-bin} -F -H3'";
          diff = "${delta-bin} --features ov-diff";
          log = "${delta-bin} --features ov-log";
        };

        # difftastic = {
        #   enable      = true;
        #   background  = "dark";
        #   color       = "always";
        #   display     = "side-by-side";
        # };

        delta = {
          enable = true;
          options = {
            navigate = true;
            side-by-side = true;
            light = false;
            syntax-theme = "catppuccin";
            # features      = "ov-diff ov-log";
            # ov-diff.pager = "${ov-diff}";
            # ov-log.pager  = "${ov-log}";
          };
        };

        pull = {
          ff = "only";
        };

        push = {
          default = "current";
          autoSetupRemote = true;
        };

        init = {
          defaultBranch = "init";
        };

        filter.lfs = {
          required = true;
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
          process = "git-lfs filter-process -- %f";
        };
      };
      # // rewriteURL;
    };
  };
}
