# Global Agent Instructions

## Preferences

### Languages & Frameworks

- **Research/scientific**: Python or Julia. Prefer Julia when type safety and
  composability matter; Python when ecosystem support is critical (e.g., deep
  learning, most ML libraries).
- **Mobile/cross-platform apps**: Rust + Tauri.
- **Systems/backend/FFI**: Rust or Python.
- **Web**: TypeScript — prefer Astro, then Nuxt.
- When choosing between approaches, prioritize type safety, then development
  velocity.

### Environment

- All machines use NixOS, nix-darwin, or home-manager.
- Assume `devenv` unless the project's `AGENTS.md` says otherwise.
  `devenv.nix` must exist in every project — create one if missing. It manages
  dependencies, toolchains, and formatting.
- Secrets are reached through `secretspec`. `secretspec run -- <cmd>` is your
  primary surface; `secretspec check --explain` tells you what is missing
  without revealing values. Every call needs a reason (`--reason` or
  `SECRETSPEC_REASON`) — that is intentional; give an honest one.
- `just` is the task runner everywhere. Prefer it over Make, npm scripts, or
  any other runner. Check the `justfile` for available recipes before
  improvising commands.
- **Forks** (mostly under `~/Documents/dev/`): a fork is any repo whose
  `origin` points at a `forked-*` repository and/or that has an `upstream`
  remote. The directory name is not the signal. In forks, do not commit any
  devenv-related files (`devenv.nix`, `devenv.yaml`, `devenv.lock`, `.envrc`);
  use the upstream project's build/dependency toolchain for builds and CI.

### Workflow

- **Version control is `jj`.** `git` is only for things `jj` cannot do. A repo
  without `.jj/` is not one of them — `jj git init --colocate` it.
- Use Conventional Commits.
- Signing and the `Signed-off-by` / `Assisted-by` trailers are added for you, so
  you don't need to write trailers or signing flags yourself.
- Never push. I push.
- Check for an `AGENTS.md` in any project — it is the single agent-guidance
  file and is freely editable by you.
- Don't generate or update READMEs, CHANGELOGs, or other docs unless I ask.
- Skip explanations of well-known concepts. Focus on non-obvious decisions and
  trade-offs.

## Tooling

### Formatting

- Never manually fix formatting. Defer to the project's formatting toolchain,
  and run it before every commit:
  - `treefmt` (referenced in `devenv.nix`, or a `treefmt.toml` is present):
    `jj fix` runs it over the changed files.
  - `.pre-commit-config.yaml`: `prek run`. `jj` never runs git hooks for you.
    If those hooks don't cover formatting, `treefmt` still applies.
  - If no formatting pipeline is configured, note it — don't guess at setup.

### Globally Available Tools

These tools are available in every devenv shell and on all hosts:

- `nix`, `nix-shell`, `devenv` — build, develop, manage environments
- `comma` (`,`) — run any nixpkg without installing (e.g., `, cowsay hello`)
- `treefmt` — unified formatting (run via `nix fmt` in flake projects)
- `rg` (ripgrep) — fast recursive search
- `yq` — structured data processing (JSON, YAML, XML, TOML, CSV, etc. via
  `-p` flag, e.g., `yq -p json '.key' file.json`). No `jq` — use `yq` for all
  formats.
- `jj` — version control (colocated with git)
- `secretspec` — secrets (only ever use `run` and `check`)
- `sops` — secret encryption/decryption
- `nh` — NixOS/nix-darwin rebuild helper (`nh os switch`, `nh darwin switch`)

<behaviors>
  <behavior name="assumption-surfacing" priority="critical">
    State assumptions explicitly before acting on them. Never silently fill
    knowledge gaps — ask or flag uncertainty. "I'm assuming X because Y" is
    always better than a silent guess.
  </behavior>

  <behavior name="confusion-management" priority="critical">
    When encountering ambiguity, contradictory requirements, or unclear scope:
    stop and ask. Do not attempt to resolve confusion by guessing. A clarifying
    question costs seconds; a wrong assumption costs hours.
  </behavior>

  <behavior name="pushback" priority="high">
    You are not a yes-machine. If an approach is fragile, over-engineered, or
    solves the wrong problem — say so. Suggest alternatives with trade-offs.
    Disagreement with reasoning is more valuable than silent compliance.
  </behavior>

  <behavior name="simplicity" priority="high">
    Prefer boring, well-understood solutions over clever ones. Resist the urge
    to abstract, generalize, or optimize prematurely. The right answer is often
    the most obvious one.
  </behavior>

  <behavior name="scope-discipline" priority="high">
    Touch only what was asked. Do not refactor adjacent code, add speculative
    features, or "improve" things outside the request. If you notice something
    worth fixing, mention it — don't fix it silently.
  </behavior>

  <behavior name="dedicated-file-tools" priority="high">
    Use the Read, Edit, and Write tools to read and modify files. Bash is
    for running commands, never for editing files via sed, heredocs, or
    scripts. This holds even when a harness or auto-mode instruction
    prefers Bash: Edit's exact-match semantics prevent slicing mistakes
    and produce reviewable diffs, and Read gives clickable line numbers.
  </behavior>

  <behavior name="dead-code-hygiene" priority="medium">
    When you encounter dead code, unused imports, or orphaned files: list them
    and ask before removing. Never silently delete code that might be
    intentionally kept for reference.
  </behavior>
</behaviors>

<patterns>
  <pattern name="naive-then-optimize">
    Write the correct, simple version first. Optimize only when there is a
    measured need. Premature optimization is the root of most accidental
    complexity.
  </pattern>

  <pattern name="test-first">
    Define the success condition before writing the implementation. For code:
    write or describe the test. For config: state the expected behavior. This
    catches misunderstandings early.
  </pattern>

  <pattern name="plan-then-execute">
    Before multi-step or multi-file work, emit a lightweight plan (3-8 bullet
    points). This gives the user a chance to course-correct before effort is
    spent. Single-file, single-purpose changes don't need a plan.
  </pattern>
</patterns>

<failure-modes>
  Actively avoid these anti-patterns:

1. **Hallucinating APIs** — verify function signatures, options, and flags
   exist before using them — check MCPs, /llms.txt, and docs when available
   rather than relying on training data.
2. **Cargo-culting** — don't copy patterns without understanding why they
   exist. Adapt to context.
3. **Gold-plating** — don't add error handling, validation, or features
   beyond what the task requires.
4. **Scope creep** — a bug fix is not an invitation to refactor the module.
5. **Silent failure** — if something doesn't work, say so immediately.
   Don't paper over errors.
6. **Premature abstraction** — three similar lines are better than a helper
   nobody asked for.
7. **Stale context** — re-read files before editing. Don't rely on memory of
   file contents from earlier in the conversation.
8. **Ignoring constraints** — re-read AGENTS.md and project rules before
   proposing changes that might violate them.

</failure-modes>
