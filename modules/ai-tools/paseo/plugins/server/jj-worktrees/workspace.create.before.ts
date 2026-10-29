import { randomBytes } from "node:crypto";

import type { PluginBeforeRequests, PluginHookContext } from "@getpaseo/plugin/server";
import { copy, ensureDir, pathExists } from "fs-extra/esm";
import { dirname, join, resolve } from "pathe";

import { jj, slugify, workspacePath } from "../utils";

type CreateRequest = PluginBeforeRequests["workspace.create"];

async function projectRoot(
  context: PluginHookContext,
  projectId: string | undefined,
): Promise<string | undefined> {
  if (!projectId) return undefined;
  const { projects } = await context.paseo.projects.list();
  return projects.find((project) => project.projectId === projectId)?.projectRootPath;
}

async function projectIdForRoot(
  context: PluginHookContext,
  root: string,
): Promise<string | undefined> {
  const { projects } = await context.paseo.projects.list();
  return projects.find((project) => resolve(project.projectRootPath) === resolve(root))?.projectId;
}

// Paseo hands over git ref names; jj spells a remote-tracking ref as `name@remote`.
const DEFAULT_BASES = ["main@origin", "main"];

async function resolveRevision(root: string, ref: string | undefined): Promise<string | undefined> {
  const remote = ref ? /^([^/]+)\/(.+)$/.exec(ref) : null;
  const candidates = !ref ? DEFAULT_BASES : remote ? [ref, `${remote[2]}@${remote[1]}`] : [ref];
  for (const candidate of candidates) {
    const probe = await jj.log.latestRevision(root, candidate);
    if (probe) return candidate;
  }
  if (ref) throw new Error(`jj-workspaces: ${ref} does not resolve to a jj revision in ${root}`);
  return undefined;
}

async function copyLocalOverrides(source: string, target: string): Promise<void> {
  if (!(await pathExists(join(source, "devenv.nix")))) return;
  for (const name of ["devenv.local.nix"]) {
    if (await pathExists(join(source, name))) await copy(join(source, name), join(target, name));
  }
}

export async function createWorkspace(
  { request }: { request: CreateRequest },
  context: PluginHookContext,
): Promise<CreateRequest | undefined> {
  if (request.source.kind !== "worktree") return;
  const source = request.source;
  if (source.checkoutSource || source.githubPrNumber) {
    console.log("jj-workspaces: change-request checkout requested; leaving it to git");
    return;
  }

  const cwd = source.cwd ?? (await projectRoot(context, source.projectId));
  if (!cwd) return;
  const root = await jj.workspace.try(cwd)`root --ignore-working-copy`;
  if (!root) return;

  const name = slugify(
    request.title?.trim() ||
      source.branchName ||
      source.worktreeSlug ||
      `ws-${randomBytes(3).toString("hex")}`,
  );
  const target = workspacePath(root, name);

  if (await pathExists(target)) {
    if (!(await jj.workspace.is(target))) {
      throw new Error(`jj-workspaces: ${target} exists and is not a jj workspace`);
    }
    console.log(`jj-workspaces: reusing ${target}`);
  } else {
    const revision = await resolveRevision(root, source.refName ?? source.baseBranch);
    const base = revision ? ["-r", revision] : [];
    await ensureDir(dirname(target));
    await jj.workspace(root)`add --colocate --name ${name} ${base} ${target}`;
    await copyLocalOverrides(cwd, target);
    // On `@` so the first `jj commit` lands on it; jj-hooks advances it from there.
    const bookmark = await jj.bookmark.try(target)`create ${name} -r @`;
    if (bookmark === null)
      console.log(`jj-workspaces: bookmark ${name} already exists; not created`);
    console.log(`jj-workspaces: created ${target} from ${revision ?? "@-"}`);
  }

  const projectId = source.projectId ?? (await projectIdForRoot(context, root));
  return {
    ...request,
    source: {
      kind: "directory",
      path: target,
      ...(projectId ? { projectId } : {}),
    },
  };
}
