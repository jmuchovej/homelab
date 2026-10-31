import type { AgentToolContext, AgentToolResult } from "@getpaseo/plugin/server";
import { defineAgentTool } from "@getpaseo/plugin/server";
import { z } from "zod";

import { createJJClient, getHarnessModel } from "../utils";

const schema = z.object({
  message: z
    .string()
    .min(1)
    .describe(
      "The full description: a Conventional Commits subject line, optionally followed by a blank line and a body.",
    ),
  revision: z.string().min(1).default("@").describe("Revset of the single revision to describe."),
});

export default defineAgentTool({
  name: "jj_describe",
  title: "Describe a revision in JJ",
  description:
    "Set the description of a revision (default: the working-copy change `@`) with a Conventional Commits message. " +
    "The `Assisted-by` trailer is automatically added for this agent. " +
    "Use this instead of running `jj describe` in a shell.",
  input: schema,
  async execute({ message, revision }, context: AgentToolContext): Promise<AgentToolResult> {
    const assisted_by = await getHarnessModel(context);
    const config = {
      "rbn.assisted-by.tool": assisted_by.provider,
      "rbn.assisted-by.model": assisted_by.model,
    };
    const jj = createJJClient(context.agent.cwd, { config });
    const change = await jj.describe(message, revision);
    if (jj.workspace.isManaged()) await jj.workspace.align();

    return {
      text: `${change.changeId} ${change.commitId}\n${change.description}`,
      structuredContent: change,
    };
  },
});
