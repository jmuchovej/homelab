import type {
  PluginHookContext,
  PluginServerContext,
  PluginSessionOpenRequest,
} from "@getpaseo/plugin/server";

import { createWorkspace, forgetWorkspace, setupWorkspace } from "./server/hooks";
import { createJJClient } from "./server/utils";

// STAGED: the released 0.14.0 SDK still has only `before`/`on`; `addHook` with
// `workspace.create.before` / `workspace.create.after` / `workspace.archive.after`
// landed on main after the tag (paseo #8081). Switch once a release ships it.
export default function contribute(server: PluginServerContext) {
  const disposers = [
    server.before("workspace.create", createWorkspace),
    server.on("workspace.created", setupWorkspace),
    server.on("workspace.archived", forgetWorkspace),
  ];
  return () => {
    for (const dispose of disposers) dispose();
  };
}
