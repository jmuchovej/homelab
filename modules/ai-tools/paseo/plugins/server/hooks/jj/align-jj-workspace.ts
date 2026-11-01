import type { PluginHookContext, PluginLifecycleEvents } from "@getpaseo/plugin/server";

import { useLogger, createJJClient } from "../../utils";

const log = useLogger("jj-hooks::align");

// Catch-all for commits the tools did not make (shell `jj commit`, `jj new`,
// rebases): after each turn, bring the workspace bookmark and git's HEAD back
// in line with `@-`.
export async function alignWorkspace(
  { agent }: PluginLifecycleEvents["agent.turn_ended"],
  _context: PluginHookContext,
): Promise<void> {
  const repo = createJJClient(agent.cwd);
  if (!repo.workspace.isManaged() || !(await repo.workspace.is())) return;
  try {
    await repo.workspace.align();
  } catch (error) {
    log.error(`failed in ${repo.cwd}: ${String(error)}`);
  }
}
