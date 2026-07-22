{
  # Per-user default editor: sets EDITOR/VISUAL/SUDO_EDITOR for the including
  # user. A parametric provider on the editors aspect — include it (with the
  # chosen command) alongside the editor aspect it points at. This is the
  # den-forward analog of the old per-editor `default = true`.
  #
  # Scope is intentionally per-user (home-manager) — EDITOR is a user
  # preference, not a machine fact. A consumer-defined provider can only reach
  # home-manager anyway; it can't escalate to host (nixos/darwin) config. The
  # home var also covers the user's `sudo`/`sudoedit` (sudo.nix keeps EDITOR in
  # env_keep), so a host-wide fallback isn't needed in practice.
  #
  # Usage:
  #   den.aspects.john.includes = [
  #     <rbn/programs/editors/helix>
  #     (<rbn/programs/editors/default-editor> "hx")
  #   ];
  rbn.programs._.editors._.default-editor = command: {
    includes = [
      {
        homeManager.home.sessionVariables = {
          EDITOR = command;
          VISUAL = command;
          SUDO_EDITOR = command;
        };
      }
    ];
  };
}
