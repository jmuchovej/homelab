import type { PluginHookContext, PluginHookWorkspace } from "@getpaseo/plugin/server";
import { remove } from "fs-extra/esm";
import { resolve } from "pathe";

import { createJJClient } from "../../utils";

export async function forgetWorkspace(
  { workspace }: { workspace: PluginHookWorkspace },
  context: PluginHookContext,
): Promise<void> {
  const repo = createJJClient(workspace.cwd);
  if (!repo.workspace.isManaged() || !(await repo.workspace.is())) return;

  const { entries } = await context.paseo.workspaces.list();
  const shared = entries.some(
    (other) =>
      other.id !== workspace.id &&
      other.workspaceDirectory !== undefined &&
      resolve(other.workspaceDirectory) === repo.cwd,
  );
  if (shared) {
    console.log(`jj-workspaces: ${repo.cwd} still backs another workspace; keeping it`);
    return;
  }

  // A bookmark that never left the base, or sits on an empty change, is a leftover.
  const name = await repo.workspace.name();
  const unused = await repo.log.resolve(`bookmarks(exact:"${name}") & (trunk() | empty())`);
  if (unused) {
    await repo.bookmark.delete(name);
    console.log(`jj-workspaces: deleted unused bookmark ${name}`);
  }

  await repo.workspace.forget();
  await remove(repo.cwd);
  console.log(`jj-workspaces: forgot and removed ${repo.cwd}`);
}
