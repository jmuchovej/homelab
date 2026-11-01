import type { PaseoWorkspaceUpdate } from "@getpaseo/client";
import type { PluginHookContext, PluginHookWorkspace } from "@getpaseo/plugin/server";
import { execa } from "execa";
import { readJson } from "fs-extra/esm";
import { basename, join, resolve } from "pathe";

import { createJJClient, type JJClient, slugify, useLogger } from "../../utils";

const log = useLogger("jj-hooks::forget");

let started: Promise<void> | undefined;
const inFlight = new Map<string, Promise<void>>();

export async function setupWorkspace(
  { workspace }: { workspace: PluginHookWorkspace },
  context: PluginHookContext,
): Promise<void> {
  const repo = createJJClient(workspace.cwd);

  // Listeners only fire while a subscribed list is alive, so one is kept for the
  // plugin's lifetime (the API disposes it when the plugin stops).
  started ??= (async () => {
    await context.paseo.workspaces.list({ subscribe: {} });
    context.paseo.workspaces.subscribe(workspaceRenameSubscriber);
  })();
  void started.catch((error: unknown) => {
    log.error(`rename sync could not start: ${String(error)}`);
  });

  if (!repo.workspace.isManaged() || !(await repo.workspace.is())) return;
  // Fire-and-forget like paseo's own setup; the hook must not hold creation.
  void (async () => {
    const [repoRoot, name] = await Promise.all([repo.root, repo.workspace.name()]);
    await runWorkspaceSetup({ cwd: repo.cwd, repoRoot, name });
  })().catch((error: unknown) => {
    log.error(`setup errored in ${repo.cwd}: ${String(error)}`);
  });
}

async function setupCommands(cwd: string): Promise<string[]> {
  let config: { worktree?: { setup?: unknown } };
  try {
    config = await readJson(join(cwd, "paseo.json"));
  } catch {
    return [];
  }

  const setup = config.worktree?.setup;

  const isCommandString = (value: unknown): value is string =>
    typeof value === "string" && value.trim() !== "";
  if (isCommandString(setup)) return [setup];
  if (!Array.isArray(setup)) return [];
  return setup.filter(isCommandString);
}

// Mirrors paseo's own runner (`runWorktreeSetupCommands` in
// packages/server/src/utils/worktree.ts): same file, same shell, same
// PASEO_* variables minus PASEO_WORKTREE_PORT, which needs paseo's marker file.
async function runWorkspaceSetup(options: {
  cwd: string;
  repoRoot: string;
  name: string;
}): Promise<void> {
  const commands = await setupCommands(options.cwd);
  if (commands.length === 0) return;

  const { BASH_ENV: _ignored, ...base } = process.env;
  const env: NodeJS.ProcessEnv = {
    ...base,
    PASEO_SOURCE_CHECKOUT_PATH: options.repoRoot,
    PASEO_ROOT_PATH: options.repoRoot,
    PASEO_WORKTREE_PATH: options.cwd,
    PASEO_BRANCH_NAME: options.name,
  };

  const fill = (step: number) => step.toString().padStart(commands.length.toString().length, " ");
  for (const [index, command] of commands.entries()) {
    log.info(`[${fill(index + 1)}/${commands.length}] ${command}`);
    const result = await execa("bash", ["-c", command], {
      cwd: options.cwd,
      env,
      extendEnv: false,
      reject: false,
    });
    if (result.stdout.trim()) console.log(result.stdout.trimEnd());
    if (result.stderr.trim()) console.error(result.stderr.trimEnd());
    if (result.failed) {
      log.error(`setup failed (exit ${result.exitCode}) in ${options.cwd}`);
      return;
    }
  }
  log.success(`setup completed in ${options.cwd}`);
}

async function syncName(repo: JJClient, displayName: string): Promise<void> {
  const desired = slugify(displayName);
  // Before auto-naming, paseo displays the directory basename; that is not a name.
  if (!desired || displayName === basename(repo.cwd)) return;
  const current = await repo.workspace.name();
  if (current === desired) return;

  if (!(await repo.bookmark.rename(current, desired))) {
    log.warn(`bookmark ${current} is gone; not renaming it to ${desired}`);
  }
  await repo.workspace.rename(desired);
  // A renamed branch leaves a symbolic HEAD on a ref that no longer exists.
  await repo.workspace.align();
  log.success(`renamed ${current} -> ${desired} in ${repo.cwd}`);
}

async function workspaceRenameSubscriber(update: PaseoWorkspaceUpdate): Promise<void> {
  if (update.kind !== "upsert" || !update.workspace.workspaceDirectory) return;
  const repo = createJJClient(resolve(update.workspace.workspaceDirectory));
  if (!repo.workspace.isManaged()) return;
  if (inFlight.has(repo.cwd)) return;
  const task = repo.workspace
    .is()
    .then((ok) => (ok ? syncName(repo, update.workspace.name) : undefined))
    .catch((error: unknown) => {
      log.error(`rename sync failed for ${repo.cwd}: ${String(error)}`);
    })
    .finally(() => inFlight.delete(repo.cwd));
  inFlight.set(repo.cwd, task);
}
