import type { AgentToolContext } from "@getpaseo/plugin/server";
import type { AgentPermissionRequest } from "@getpaseo/protocol/agent-types";
import { kebabCase, splitByCase } from "scule";

export { type Change, createJJClient, JJClient, type JJClientOptions } from "./jj";
export { workspacePath, WORKTREES_ROOT } from "./paths";

// scule does not split on spaces by default and keeps punctuation; bookmark
// names must be plain, so parts are scrubbed before joining.
export function slugify(value: string): string {
  const parts = splitByCase(value, [" ", "-", "_", "/", "."])
    .map((part) => part.replace(/[^a-z0-9]/gi, ""))
    .filter((part) => part !== "");
  return kebabCase(parts);
}

export function unwrapShell(request: AgentPermissionRequest): string | undefined | null {
  if (!request.input) return;
  if (typeof request.input.command === "string") return request.input.command;
  if (typeof request.input.cmd === "string") return request.input.cmd;
  return null;
}

// Paseo knows which harness and model are running, so the trailer is derived
// from its records instead of a per-harness hook that parses shell commands.
export async function getHarnessModel({ agent, paseo }: AgentToolContext) {
  const [snapshot, refreshed] = await Promise.all([
    paseo.providers.snapshot().catch(() => null),
    paseo.agents
      .ref(agent.id)
      .refresh()
      .catch(() => null),
  ]);
  const provider = snapshot?.entries.find((entry) => entry.provider === agent.provider);
  const providerName = provider?.label ?? agent.provider;

  // Early in a session the record may still hold the alias the agent was
  // created with (`haiku`), which the model list does not carry; the list is
  // newest first, so the first id containing the alias is the current release.
  const modelId = refreshed?.agent.model ?? null;
  let modelName = modelId ?? agent.provider;
  if (modelId) {
    const listed = await paseo.providers.listModels(agent.provider).catch(() => null);
    const models = listed?.models ?? [];
    const definition =
      models.find((candidate) => candidate.id === modelId) ??
      models.find((candidate) => candidate.aliases?.includes(modelId)) ??
      models.find((candidate) => candidate.id.includes(modelId.toLowerCase()));
    modelName = definition?.label ?? modelId;
  }

  return {
    provider: providerName,
    model: modelName,
  };
}
