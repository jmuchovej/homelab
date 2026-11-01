import type { AgentToolContext, AgentToolResult } from "@getpaseo/plugin/server";
import { defineAgentTool } from "@getpaseo/plugin/server";
import { defu } from "defu";
import { z } from "zod";

import { getAttribution, formatChanges, createJJClient } from "../utils";

const schema = z.object({
  revision: z
    .string()
    .min(1)
    .default("@")
    .describe("Revset of the single revision to split. Defaults to the working copy, `@`."),
  paths: z
    .array(z.string().min(1))
    .min(1)
    .describe("filesets that go into the first commit; everything else stays in the second."),
  message: z
    .string()
    .min(1)
    .describe(
      "The first commit's full message: a Conventional Commits subject line, optionally followed by a blank line and a body.",
    ),
});

export default defineAgentTool({
  name: "jj_split",
  title: "Split a JJ revision",
  description:
    "Split a revision (default: the working copy `@`) in two by paths. " +
    "The given paths become the first commit, with this Conventional Commits message; " +
    "the rest becomes its child and keeps the original description. " +
    "The `Assisted-by` trailer is automatically added for this agent. " +
    "Use this instead of running `jj split` in a shell.",
  input: schema,
  async execute(input, context: AgentToolContext): Promise<AgentToolResult> {
    const attribution = await getAttribution(context);
    const jj = createJJClient(context.agent.cwd, { config: defu({}, attribution) });
    const result = await jj.split(input);
    if (jj.workspace.isManaged()) await jj.workspace.align();

    return { text: formatChanges(result.selected, result.remainder), structuredContent: result };
  },
});
