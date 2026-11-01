import type { AgentToolContext, AgentToolResult } from "@getpaseo/plugin/server";
import { defineAgentTool } from "@getpaseo/plugin/server";
import { defu } from "defu";
import { z } from "zod";

import { getAttribution, createJJClient, formatChanges } from "../utils";

const schema = z.object({
  message: z
    .string()
    .min(1)
    .describe(
      "The full commit message: a Conventional Commits subject line, optionally followed by a blank line and a body.",
    ),
  paths: z
    .array(z.string().min(1))
    .optional()
    .describe(
      "filesets to commit (paths or patterns). Omit to commit _every_ change in the working copy.",
    ),
});

export default defineAgentTool({
  name: "jj_commit",
  title: "Make a JJ Commit",
  description:
    "Commit the working copy, or only given paths, with a Conventional Commits message. " +
    "The `Assisted-by` trailer is automatically added for this agent. " +
    "Use this instead of running `jj commit` in a shell.",
  input: schema,
  async execute({ message, paths }, context: AgentToolContext): Promise<AgentToolResult> {
    const attribution = await getAttribution(context);
    const jj = createJJClient(context.agent.cwd, { config: defu({}, attribution) });
    const change = await jj.commit(message, paths);
    if (jj.workspace.isManaged()) await jj.workspace.align();

    return { text: formatChanges(change), structuredContent: change };
  },
});
