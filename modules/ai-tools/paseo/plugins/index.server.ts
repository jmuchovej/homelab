import type {
  PluginHookContext,
  PluginServerContext,
  PluginSessionOpenRequest,
} from "@getpaseo/plugin/server";

import { jjCommit, jjDescribe } from "./server/agent-tools";
import { alignWorkspace, createWorkspace, forgetWorkspace, setupWorkspace } from "./server/hooks";
import { createJJClient } from "./server/utils";

// STAGED: the released 0.14.0 SDK still has only `before`/`on`; `addHook` with
// `workspace.create.before` / `workspace.create.after` / `workspace.archive.after`
// landed on main after the tag (paseo #8081). Switch once a release ships it.
export default function contribute(server: PluginServerContext) {
  const disposers = [
    server.before("workspace.create", createWorkspace),
    server.on("workspace.created", setupWorkspace),
    server.on("workspace.archived", forgetWorkspace),
    server.before("agent.session_open", attachCommitTools),
    server.on("agent.turn_ended", alignWorkspace),
  ];
  return () => {
    for (const dispose of disposers) dispose();
  };
}

// Agents in a jj checkout get structured commit tools, so shell `jj commit`
// and `jj describe` can sit behind a deny or ask permission rule instead.
async function attachCommitTools(
  { request }: { request: PluginSessionOpenRequest },
  _context: PluginHookContext,
): Promise<PluginSessionOpenRequest | undefined> {
  if (request.purpose !== "interactive") return;
  if (!(await createJJClient(request.cwd).workspace.root())) return;
  return {
    ...request,
    tools: [...request.tools, jjCommit, jjDescribe],
  };
}
