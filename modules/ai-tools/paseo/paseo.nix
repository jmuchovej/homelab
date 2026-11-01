{ __findFile, lib, ... }:
let
  # The jj spellings that write a description; under paseo the plugin's agent
  # tools replace them. `new` writes one only when given a message.
  jj-describing = [
    "commit"
    "ci"
    "describe"
    "desc"
    "split"
    "squash"
  ];
  jj-message-flags = [
    "-m"
    "--message"
  ];
  jj-wrappers = [
    ""
    "direnv exec . "
  ];
  jj-denied-prefixes = lib.concatMap (
    wrap:
    map (sub: "${wrap}jj ${sub}") jj-describing ++ map (flag: "${wrap}jj new ${flag}") jj-message-flags
  ) jj-wrappers;
  jj-tools-hint = "Use the jj_commit, jj_describe, jj_split and jj_squash tools; for `jj new -m`, run `jj new` and then jj_describe.";
in
{
  rbn.programs._.ai-tools._.paseo = {
    dock.key = "Paseo";
    dock.source = "brew";

    # `llm-agents` doesn't mark it as supported on macOS 🥲
    hm-linux = { pkgs, ... }: {
      home.packages = [ pkgs.llm-agents.paseo-desktop ];
    };

    macos = _: {
      homebrew.casks = [ "paseo" ];
    };

    # Every harness paseo runs denies the shell spellings, in its own syntax.
    hm = _: {
      programs.claude-code.settings.permissions.deny = lib.concatMap (prefix: [
        "Bash(${prefix})"
        "Bash(${prefix} *)"
      ]) jj-denied-prefixes;

      programs.codex.rules.jj-tools = lib.concatMapStrings (prefix: ''
        prefix_rule(
            pattern = ${builtins.toJSON (lib.splitString " " prefix)},
            decision = "forbidden",
            justification = ${builtins.toJSON jj-tools-hint},
        )
      '') jj-denied-prefixes;

      programs.opencode.settings.permission.bash = lib.genAttrs (map (
        prefix: "${prefix}*"
      ) jj-denied-prefixes) (_: "deny");

      programs.antigravity-cli.permissions.deny = map (prefix: "command(${prefix})") jj-denied-prefixes;
    };
  };
}
