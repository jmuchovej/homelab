{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.terminal.tools.jujutsu";
  options =
    { config, lib, ... }:
    let
      inherit (lib) types mkOption;
      inherit (lib.rebellion.options) mk;
      inherit (config.rebellion) user;
    in
    {
      signing-key = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.ssh/signing-key";
        description = "Which SSH key should be used to sign commmits?";
      };
      user = {
        name = mk types.str user.real-name "The name to configure `jujutsu` with.";
        email = mk types.str user.email "The email to configure `jujutsu` with.";
      };
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.rebellion) enabled;
    in
    {
      home.packages = with pkgs; [ lazyjj ];
      programs.jujutsu = enabled // {
        enable = true;
        package = pkgs.jujutsu;

        settings = {
          inherit (cfg) user;
          init.default_branch = "main";
          lfs = enabled;

          signing.backend = "ssh";
          signing.key = cfg.signing-key;
          git.fetch.prune = true;
          git.sign-on-push = true;
          git.private-commits = "description('wip:*') | description('private:*')";

          push.autoSetupRemote = true;
          push.default = "current";

          rebase.auto_stash = true;

          ui.color = "always";
          ui.default-command = "log";
        };
      };
    };
}
