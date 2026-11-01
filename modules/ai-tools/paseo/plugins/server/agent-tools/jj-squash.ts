import type { AgentToolContext, AgentToolResult } from "@getpaseo/plugin/server";
import { defineAgentTool } from "@getpaseo/plugin/server";
import { defu } from "defu";
import { z } from "zod";

import { getAttribution, formatChanges, createJJClient } from "../utils";

const schema = z
  .object({
    from: z
      .string()
      .min(1)
      .default("@")
      .describe("Revset of the revision to take changes from. Defaults to the working copy, `@`."),
    into: z
      .string()
      .min(1)
      .optional()
      .describe("Revset of the revision to move them into. Defaults to the parent of `from`."),
    paths: z
      .array(z.string().min(1))
      .optional()
      .describe("filesets to move. Omit to move every change in `from`."),
    message: z
      .string()
      .min(1)
      .optional()
      .describe(
        "The combined revision's full message: a Conventional Commits subject line, optionally followed by a blank line and a body.",
      ),
    keepDestinationMessage: z
      .boolean()
      .optional()
      .describe("Keep the destination's description unchanged instead of giving `message`."),
  })
  .refine((input) => Boolean(input.message) !== Boolean(input.keepDestinationMessage), {
    message: "Give exactly one of `message` or `keepDestinationMessage: true`.",
  });

export default defineAgentTool({
  name: "jj_squash",
  title: "Squash changes between JJ revisions",
  description:
    "Move changes from one revision into another (default: the working copy `@` into its parent), " +
    "optionally only some paths. Either give the combined revision a Conventional Commits message, " +
    "or keep the destination's description. " +
    "The `Assisted-by` trailer is automatically added when a message is given. " +
    "Use this instead of running `jj squash` in a shell.",
  input: schema,
  async execute(
    { message, keepDestinationMessage: _keep, ...rest },
    context: AgentToolContext,
  ): Promise<AgentToolResult> {
    const attribution = await getAttribution(context);
    const jj = createJJClient(context.agent.cwd, { config: defu({}, attribution) });

    const description = message ? { message } : ({ keep: "destination" } as const);
    const change = await jj.squash({ ...rest, description });
    if (jj.workspace.isManaged()) await jj.workspace.align();

    return { text: formatChanges(change), structuredContent: change };
  },
});
