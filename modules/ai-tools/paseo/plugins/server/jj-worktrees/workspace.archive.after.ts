import type { PluginHookContext, PluginHookWorkspace } from "@getpaseo/plugin/server";
import { remove } from "fs-extra/esm";
import { resolve } from "pathe";

import { isManagedPath, jj } from "../utils";

export async function forgetWorkspace(
  { workspace }: { workspace: PluginHookWorkspace },
  context: PluginHookContext,
): Promise<void> {
  const cwd = resolve(workspace.cwd);
  if (!isManagedPath(cwd) || !(await jj.workspace.is(cwd))) return;

  const { entries } = await context.paseo.workspaces.list();
  const shared = entries.some(
    (other) =>
      other.id !== workspace.id &&
      other.workspaceDirectory !== undefined &&
      resolve(other.workspaceDirectory) === cwd,
  );
  if (shared) {
    console.log(`jj-workspaces: ${cwd} still backs another workspace; keeping it`);
    return;
  }

  // A bookmark that never left the base, or sits on an empty change, is a leftover.
  const name = await jj.workspace.name(cwd);
  const stale = await jj.log.revision(cwd, `bookmarks(exact:"${name}") & (trunk() | empty())`);
  if (stale) {
    await jj.bookmark.delete(cwd, name);
    console.log(`jj-workspaces: deleted unused bookmark ${name}`);
  }

  // `forget` snapshots the working copy first, so unfinished edits survive as a
  // commit in the main repo; only the directory and the git worktree go away.
  await jj.workspace.forget(cwd);
  await remove(cwd);
  console.log(`jj-workspaces: forgot and removed ${cwd}`);
}
