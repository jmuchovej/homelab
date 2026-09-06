## Render openspec's workflow skills at build time for the shared
## `.agents/skills` root every harness is pointed at.
##
## openspec ships one SKILL.md per workflow, named `openspec-<workflow>-change`
## and similar. They are renamed to `openspec-<workflow-id>`, the same id
## openspec uses for its `/opsx:<id>` slash commands (which this repo does not
## install), and every cross-reference is rewritten to match. Generated with
## `--tools agents`, so references are the harness-neutral `/openspec-<id>`.
##
## NB: `skill-renames`, not `rename` — `callPackage` would fill `rename` from
## nixpkgs (a perl utility) and silently replace the attrset.
{
  lib,
  runCommand,
  openspec,
  workflows ? [
    "explore"
    "new"
    "continue"
    "apply"
    "update"
    "ff"
    "sync"
    "archive"
    "bulk-archive"
    "verify"
    "onboard"
    "propose"
  ],
  skill-renames ? {
    openspec-new-change = "openspec-new";
    openspec-continue-change = "openspec-continue";
    openspec-apply-change = "openspec-apply";
    openspec-update-change = "openspec-update";
    openspec-ff-change = "openspec-ff";
    openspec-sync-specs = "openspec-sync";
    openspec-archive-change = "openspec-archive";
    openspec-bulk-archive-change = "openspec-bulk-archive";
    openspec-verify-change = "openspec-verify";
  },
}:
let
  inherit (lib) concatStringsSep escapeShellArg mapAttrsToList;

  # openspec's default "core" profile emits six workflows; a custom profile in a
  # scratch HOME yields all of them.
  global-config = builtins.toJSON {
    profile = "custom";
    inherit workflows;
    delivery = "skills";
    telemetry.enabled = false;
  };

  # Rewrites frontmatter `name:` and `/openspec-x` / `$openspec-x` references.
  rename-script = concatStringsSep "\n" (
    mapAttrsToList (old: new: "s#\\b${old}\\b#${new}#g") skill-renames
  );

  mv-skills = concatStringsSep "\n" (
    mapAttrsToList (old: new: ''
      if [ -d "$out/${old}" ]; then mv "$out/${old}" "$out/${new}"; fi
    '') skill-renames
  );
in
runCommand "openspec-skills-${openspec.version}"
  {
    nativeBuildInputs = [ openspec ];
    passthru = {
      inherit workflows skill-renames;
    };
  }
  ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export OPENSPEC_TELEMETRY=0
    mkdir -p "$XDG_CONFIG_HOME/openspec"
    printf '%s\n' ${escapeShellArg global-config} > "$XDG_CONFIG_HOME/openspec/config.json"

    project="$TMPDIR/project"
    mkdir -p "$project" && cd "$project"
    openspec init --tools agents --no-animation --force . > "$TMPDIR/init.log" 2>&1 \
      || { cat "$TMPDIR/init.log" >&2; exit 1; }

    # The glob skips `.openspec-target`, openspec's ownership marker for a
    # skills root, so `openspec update` never tries to manage this tree.
    mkdir -p "$out"
    cp -r .agents/skills/openspec-* "$out/"
    ${mv-skills}

    cat > "$TMPDIR/rename.sed" <<'EOF'
    ${rename-script}
    EOF
    find "$out" -type f -exec sed -i -E -f "$TMPDIR/rename.sed" {} +
  ''
