# Builds each scripts/*.nu file into a runnable, checked binary.
#
# `writers.writeNuBin` has no shellcheck equivalent built in, so `check` runs
# `nu-check` at build time; `--debug` makes a parse failure throw, failing the
# derivation with the diagnostic. Scripts run on the nixpkgs-pinned nushell,
# independent of the interactive shell's nu.
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  inherit (lib) getExe;
  inherit (pkgs) writeShellScript;
  notify = import ./notify.nix { inherit pkgs; };

  # `bins` end up on the script's wrapped PATH; nu built-ins cover the rest
  # (mkdir/rm/date), so scripts list only their external commands.
  mk-script =
    name:
    {
      bins ? [ ],
      plugins ? [ ],
    }:
    let
      # Assembled from a list so the no-plugin case has no trailing space —
      # Linux passes the shebang tail as ONE argument, spaces included.
      nu = lib.concatStringsSep " " (
        [
          (getExe pkgs.nushell)
          "--no-config-file"
        ]
        ++ lib.optionals (plugins != [ ]) [
          "--plugins"
          "'[${lib.concatMapStringsSep " " getExe plugins}]'"
        ]
      );
      interpreter =
        if plugins == [ ] then nu else toString (writeShellScript "nu-plugged" ''exec ${nu} "$@"'');
      nu-check = writeShellScript "nu-check" ''
        ${nu} --commands "if not (nu-check --debug '$1') { exit 1 }"
      '';
    in
    pkgs.writers.makeScriptWriter {
      inherit interpreter;
      check = nu-check;
      makeWrapperArgs = lib.optionals (bins != [ ]) [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath bins)
      ];
    } "/bin/${name}" (builtins.readFile (./scripts + "/${name}.nu"));

  vcs = [
    pkgs.jujutsu
    pkgs.git
  ];
in
{
  pre-tool-use = mk-script "pre-tool-use" { };
  pre-tool-audit = mk-script "pre-tool-audit" { };
  post-tool-audit = mk-script "post-tool-audit" { };
  post-tool-validate = mk-script "post-tool-validate" { };
  pre-compact = mk-script "pre-compact" { bins = [ pkgs.git ]; };
  session-start = mk-script "session-start" { bins = vcs; };
  session-end = mk-script "session-end" { bins = [ pkgs.git ]; };
  status-line = mk-script "status-line" { bins = [ pkgs.git ]; };
  subagent-stop = mk-script "subagent-stop" { bins = [ notify ]; };
  worktree-create = mk-script "worktree-create" { bins = vcs; };
  worktree-remove = mk-script "worktree-remove" { bins = vcs; };
}
