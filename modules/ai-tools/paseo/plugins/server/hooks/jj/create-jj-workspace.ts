import { randomBytes } from "node:crypto";

import type { PaseoProject } from "@getpaseo/client";
import type { PluginBeforeRequests, PluginHookContext } from "@getpaseo/plugin/server";
import { ensureDir, pathExists } from "fs-extra/esm";
import { dirname } from "pathe";

import { createJJClient, type JJClient, slugify, useLogger, workspacePath } from "../../utils";

type CreateRequest = PluginBeforeRequests["workspace.create"];

const log = useLogger("jj-hooks::create");

// Paseo sends git ref names: the app's picker emits `refs/heads/<name>` for a
// local branch and `refs/remotes/<remote>/<name>` for a remote one, the CLI's
// `--base` passes whatever it was given (`origin/main`, `main`). jj spells the
// colocated git branch `<name>@git` and a remote one `<name>@<remote>`.
// Remote refs are never split here: git allows slashes in both remote and
// branch names, so jj is asked which tracked `<remote>/<name>` the ref is.
async function asJJRevsets(repo: JJClient, ref: string): Promise<string[]> {
  if (ref.startsWith("refs/heads/")) {
    const name = ref.slice("refs/heads/".length);
    return [`${name}@git`, name];
  }
  const isRemoteRef = ref.startsWith("refs/remotes/");
  const tracked = await repo.bookmark.list(isRemoteRef ? ref.slice("refs/remotes/".length) : ref);
  if (tracked.length > 0) return tracked;
  // A bare name may still be a local bookmark or any other revset.
  return isRemoteRef ? [] : [ref];
}

// No ref means the app's quick-create dialog or a bare CLI call: start from the
// remote trunk, then the local one, then let jj default to `@-`.
const DEFAULT_BASES = ["main@origin", "main@git", "main"];

async function resolveBase(repo: JJClient, ref: string | undefined): Promise<string | undefined> {
  const candidates = ref ? await asJJRevsets(repo, ref) : DEFAULT_BASES;
  for (const candidate of candidates) {
    if (await repo.log.resolve(candidate)) return candidate;
  }
  if (ref) {
    const msg = `${ref} does not resolve to a jj revision in ${repo.cwd}`;
    log.error(msg);
    throw new Error(msg);
  }
  return undefined;
}

async function findProject(
  context: PluginHookContext,
  key: keyof PaseoProject,
  value: string | undefined,
): Promise<PaseoProject | undefined> {
  if (!value) return undefined;
  const { projects } = await context.paseo.projects.list();
  return projects.find((project) => project[key] === value);
}

export async function createWorkspace(
  { request }: { request: CreateRequest },
  context: PluginHookContext,
): Promise<CreateRequest | undefined> {
  if (request.source.kind !== "worktree") return;
  const source = request.source;
  if (source.checkoutSource) {
    log.info("change-request checkout requested; leaving it to git");
    return;
  }

  const cwd =
    source.cwd ?? (await findProject(context, "projectId", source.projectId))?.projectRootPath;
  if (!cwd) return;
  const repo = createJJClient(cwd);
  if (!(await repo.workspace.root())) return;

  const name = slugify(
    request.title?.trim() ||
      source.branchName ||
      source.worktreeSlug ||
      `ws-${randomBytes(3).toString("hex")}`,
  );
  const worktree = createJJClient(workspacePath(repo.cwd, name));

  if (await pathExists(worktree.cwd)) {
    if (!(await worktree.workspace.is())) {
      const msg = `${worktree.cwd} exists and is not a jj workspace`;
      log.error(msg);
      throw new Error(msg);
    }
    log.info(`reusing ${worktree.cwd}`);
  } else {
    // `refName` is the base for branch-off and the branch for checkout; either
    // way it is the commit the new workspace starts on.
    const revision = await resolveBase(repo, source.refName ?? source.baseBranch);
    await ensureDir(dirname(worktree.cwd));
    await repo.workspace.add({ name, path: worktree.cwd, revision });

    // On `@` so the first `jj commit` lands on it; jj-hooks advances it from there.
    if (!(await worktree.bookmark.create(name, "@"))) {
      log.info(`bookmark ${name} already exists; not created`);
    }
    log.info(`created ${worktree.cwd} from ${revision ?? "@-"}`);
  }

  const projectId =
    source.projectId ?? (await findProject(context, "projectRootPath", repo.cwd))?.projectId;
  return {
    ...request,
    source: {
      kind: "directory",
      path: worktree.cwd,
      ...(projectId ? { projectId } : {}),
    },
  };
}
