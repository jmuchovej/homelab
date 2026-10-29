import type { PluginHookContext, PluginHookWorkspace } from "@getpaseo/plugin/server";
import { execa } from "execa";
import { readJson } from "fs-extra/esm";
import { basename, join, resolve } from "pathe";

import { isManagedPath, jj, slugify } from "../utils";

export async function onWorkspaceCreated(
  { workspace }: { workspace: PluginHookWorkspace },
  context: PluginHookContext,
): Promise<void> {
  void ensureRenameSync(context);
  const cwd = resolve(workspace.cwd);
  if (!isManagedPath(cwd) || !(await jj.workspace.is(cwd))) return;
  // Fire-and-forget like paseo's own setup; the hook must not hold creation.
  void (async () => {
    const [repoRoot, name] = await Promise.all([jj.workspace.root(cwd), jj.workspace.name(cwd)]);
    await runWorkspaceSetup({ cwd, repoRoot, name });
  })().catch((error: unknown) => {
    console.error(`jj-workspaces: setup errored in ${cwd}: ${String(error)}`);
  });
}

// Mirrors paseo's own runner (`runWorktreeSetupCommands` in
// packages/server/src/utils/worktree.ts): same file, same shell, same
// PASEO_* variables minus PASEO_WORKTREE_PORT, which needs paseo's marker file.
function lifecycleCommands(value: unknown): string[] {
  if (typeof value === "string") return value.trim() ? [value] : [];
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === "string" && entry.trim() !== "");
}

async function setupCommands(cwd: string): Promise<string[]> {
  let config: { worktree?: { setup?: unknown } };
  try {
    config = await readJson(join(cwd, "paseo.json"));
  } catch {
    return [];
  }
  return lifecycleCommands(config.worktree?.setup);
}

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

  for (const [index, command] of commands.entries()) {
    console.log(`jj-workspaces: setup ${index + 1}/${commands.length}: ${command}`);
    const result = await execa("bash", ["-c", command], {
      cwd: options.cwd,
      env,
      extendEnv: false,
      reject: false,
    });
    if (result.stdout.trim()) console.log(result.stdout.trimEnd());
    if (result.stderr.trim()) console.error(result.stderr.trimEnd());
    if (result.failed) {
      console.error(`jj-workspaces: setup failed (exit ${result.exitCode}) in ${options.cwd}`);
      return;
    }
  }
  console.log(`jj-workspaces: setup completed in ${options.cwd}`);
}

let started: Promise<void> | undefined;
const inFlight = new Map<string, Promise<void>>();

async function syncName(cwd: string, displayName: string): Promise<void> {
  const desired = slugify(displayName);
  // Before auto-naming, paseo displays the directory basename; that is not a name.
  if (!desired || displayName === basename(cwd)) return;
  const current = await jj.workspace.name(cwd);
  if (current === desired) return;

  const renamed = await jj.bookmark.rename(cwd, current, desired);
  if (renamed === null) {
    console.log(`jj-workspaces: bookmark ${current} is gone; not renaming it to ${desired}`);
  }
  await jj.workspace.rename(cwd, desired);
  console.log(`jj-workspaces: renamed ${current} -> ${desired} in ${cwd}`);
}

// Listeners only fire while a subscribed list is alive, so one is kept for the
// plugin's lifetime (the API disposes it when the plugin stops).
function ensureRenameSync(context: PluginHookContext): Promise<void> {
  started ??= (async () => {
    await context.paseo.workspaces.list({ subscribe: {} });
    context.paseo.workspaces.subscribe((update) => {
      if (update.kind !== "upsert") return;
      const cwd = update.workspace.workspaceDirectory;
      if (!cwd || !isManagedPath(cwd)) return;
      const key = resolve(cwd);
      if (inFlight.has(key)) return;
      const task = jj.workspace
        .is(key)
        .then((ok) => (ok ? syncName(key, update.workspace.name) : undefined))
        .catch((error: unknown) => {
          console.error(`jj-workspaces: rename sync failed for ${key}: ${String(error)}`);
        })
        .finally(() => inFlight.delete(key));
      inFlight.set(key, task);
    });
  })();
  return started;
}
