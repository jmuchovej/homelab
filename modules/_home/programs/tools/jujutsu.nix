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
        default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";
        description = "Which SSH key should be used to sign commmits?";
      };
      user = {
        name = mk types.str user.real-name "The name to configure `jujutsu` with.";
        email = mk types.str (config.rebellion.git.email or "jmuchovej@users.noreply.github.com"
        ) "The email to configure `jujutsu` with.";
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
          signing.sign-all = true;
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
