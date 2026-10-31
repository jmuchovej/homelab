import { randomBytes } from "node:crypto";

import type { PaseoProject } from "@getpaseo/client";
import type { PluginBeforeRequests, PluginHookContext } from "@getpaseo/plugin/server";
import { ensureDir, pathExists } from "fs-extra/esm";
import { dirname } from "pathe";

import { createJJClient, slugify, workspacePath } from "../../utils";

type CreateRequest = PluginBeforeRequests["workspace.create"];

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
    console.log("jj-workspaces: change-request checkout requested; leaving it to git");
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
      throw new Error(`jj-workspaces: ${worktree} exists and is not a jj workspace`);
    }
    console.log(`jj-workspaces: reusing ${worktree}`);
  } else {
    let target = ((source) => {
      switch (source.action) {
        case "branch-off": return source.refName!;
        case "checkout": return source.baseBranch!;
      }
      throw new Error(`hooks/jj: neither \`refName\` nor \`baseBranch\` are filled for ${source.action}`)
    })(request.source);

    target = target.replace("refs/heads/", "git/").replace("refs/remotes/", "")
    const refs = await repo.bookmark.list(target);
    if (target && refs.length === 0)
      throw new Error(`jj-workspaces: ${refs} does not resolve to a jj revision in ${repo.cwd}`);

    const revision = await repo.log.resolve(refs.at(0)!);
    if (!revision)
      throw new Error(`jj-workspaces: ${refs} found, but could not resolve to a revision`);

    await ensureDir(dirname(worktree.cwd));
    await repo.workspace.add({ name, path: worktree.cwd, revision });

    // On `@` so the first `jj commit` lands on it; jj-hooks advances it from there.
    if (!(await worktree.bookmark.create(name, "@"))) {
      console.log(`jj-workspaces: bookmark ${name} already exists; not created`);
    }
    console.log(`jj-workspaces: created ${worktree} from ${revision ?? "@-"}`);
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
