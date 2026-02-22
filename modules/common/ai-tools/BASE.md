# Global Agent Instructions

## Language & Framework Preferences

- **Research/scientific**: Python or Julia. Prefer Julia when type safety and
  composability matter; Python when ecosystem support is critical (e.g., deep
  learning, most ML libraries).
- **Mobile/cross-platform apps**: Dart + Flutter with a Rust FFI core.
- **Systems/backend/FFI**: Rust.
- **Web**: TypeScript — prefer Astro, then Nuxt.
- When choosing between approaches, prioritize type safety, then development
  velocity.

## Environment & Dependencies

- All machines use NixOS, nix-darwin, or home-manager.
- `devenv.nix` must always exist in every project. Create one if missing. It
  manages dependencies, toolchains, and formatting.
- **`forked-*` repos**: do not commit any devenv-related files. Use the upstream
  project's build/dependency toolchain for builds and CI.

## Workflow

- Use Conventional Commits. Always `git commit --sign`.
- Check for an `AGENTS.md` in any project — these are freely editable by you.
  Project-level `CLAUDE.md` files reference `AGENTS.md` for cross-tool
  compatibility.
- Don't generate or update READMEs, CHANGELOGs, or other docs unless I ask.
- Skip explanations of well-known concepts. Focus on non-obvious decisions and
  trade-offs.

## Tooling

- Never manually fix formatting. Defer to the project's formatting toolchain:
  - Use `treefmt` if referenced in `devenv.nix` or a `treefmt.toml` is present.
  - If a `.pre-commit-config.yaml` exists, check whether it includes formatter
    hooks before assuming formatting is handled.
  - If no formatting pipeline is configured, note it — don't guess at setup.
