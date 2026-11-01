import { defu } from "defu";
import { execa, parseCommandString } from "execa";
import { pathExists } from "fs-extra/esm";
import { join, resolve, sep } from "pathe";

import { useLogger } from "./log";
import { Binary, getBinaryFor, WORKTREES_ROOT } from "./paths";

const log = useLogger("jj-client");

type Part = string | number | readonly string[];

// Same contract as execa's own template tag: literal text splits on spaces
// (`parseCommandString` knows no quoting), each `${}` stays one argument, and
// an array spreads into several, so an empty array contributes nothing.
function argv(strings: TemplateStringsArray, values: readonly Part[]): string[] {
  const args: string[] = [];
  strings.forEach((chunk, index) => {
    args.push(...parseCommandString(chunk));
    const value = values[index];
    if (value === undefined) return;
    if (typeof value === "string" || typeof value === "number") args.push(String(value));
    else args.push(...value);
  });
  return args;
}

type Tag<Result> = (strings: TemplateStringsArray, ...values: Part[]) => Promise<Result>;

// Not `Object.assign`: a function's own `name` and `length` are read-only, so
// assigning a member called `name` onto a callable throws at plugin load.
function callable<F extends object, M extends object>(fn: F, members: M): F & M {
  for (const [key, value] of Object.entries(members)) {
    Object.defineProperty(fn, key, { value, writable: true, configurable: true, enumerable: true });
  }
  return fn as F & M;
}

export interface JJClientOptions {
  // `--config key=value` added to every command, e.g. the Assisted-by trailer keys.
  config?: Record<string, string>;
}

export interface Change {
  changeId: string;
  commitId: string;
  description: string;
}

// One client per working directory. State is the directory and the extra
// `--config` flags, nothing else. Each subcommand namespace is callable as a
// raw tag with that subcommand as prefix (`repo.workspace\`list\``) and carries
// intent-named methods; call sites should use the methods and add one when
// a need has no name yet.
export class JJClient {
  constructor(
    readonly cwd: string,
    private readonly options: JJClientOptions = {},
  ) {
    this.cwd = resolve(cwd);
  }

  with(options: JJClientOptions): JJClient {
    return new JJClient(this.cwd, defu(this.options, options));
  }

  // Snapshots the working copy first, like any interactive `jj` invocation.
  run: Tag<string> = (strings, ...values) => this.exec(argv(strings, values));

  // Reads without snapshotting; use for anything that only inspects the repo.
  read: Tag<string> = (strings, ...values) =>
    this.exec(["--ignore-working-copy", ...argv(strings, values)]);

  try: Tag<string | null> = (strings, ...values) => this.run(strings, ...values).catch(() => null);

  // The main checkout: the `default` workspace, reachable from any workspace of the repo.
  get root(): Promise<string> {
    return this.read`workspace root --name default`;
  }

  async commit(message: string, paths: readonly string[] = []): Promise<Change> {
    await this.run`commit -m ${message} ${paths}`;
    return this.log.summary("@-");
  }

  async describe(message: string, revision = "@"): Promise<Change> {
    await this.run`describe -r ${revision} -m ${message}`;
    return this.log.summary(revision);
  }

  // Split `revision` by fileset. The selected paths keep the change id and
  // take `message`; the rest becomes its child with the original description.
  // Change ids survive the rewrite, commit ids do not, so results are read
  // back by the change id pinned beforehand.
  async split(input: {
    revision?: string;
    paths: readonly string[];
    message: string;
  }): Promise<{ selected: Change; remainder: Change }> {
    const id = await this.read`log --no-graph -r ${input.revision ?? "@"} -T change_id`;
    await this.run`split -r ${id} -m ${input.message} ${input.paths}`;
    return {
      selected: await this.log.summary(id),
      remainder: await this.log.summary(`children(${id})`),
    };
  }

  // Move `paths` (default: everything) from `from` into `into` (default: the
  // parent of `from`). The combined description must be given or taken from
  // the destination: with neither, jj opens an editor the daemon cannot drive.
  async squash(input: {
    from?: string;
    into?: string;
    paths?: readonly string[];
    description: { message: string } | { keep: "destination" };
  }): Promise<Change> {
    const from = input.from ?? "@";
    const into = await this.read`log --no-graph -r ${input.into ?? `${from}-`} -T change_id`;
    const describe =
      "message" in input.description
        ? ["-m", input.description.message]
        : ["--use-destination-message"];
    await this.run`squash --from ${from} --into ${into} ${describe} ${input.paths ?? []}`;
    return this.log.summary(into);
  }

  readonly log = callable(this.prefixed("log", "--no-graph"), {
    // Commit id of the first revision a revset names, or null when it names nothing.
    // The template is interpolated: inline quotes would be split into argv tokens.
    resolve: async (revset: string): Promise<string | null> => {
      const template = `commit_id.short() ++ "\n"`;
      const ids = await this.read`log --no-graph -r ${revset} -T ${template}`.catch(() => null);
      return ids?.split("\n")[0] || null;
    },

    summary: async (revset: string): Promise<Change> => {
      const SUMMARY = `change_id.short() ++ " " ++ commit_id.short() ++ "\n" ++ description`;
      const text = await this.read`log --no-graph -r ${revset} -T ${SUMMARY}`;
      const [ids = "", ...description] = text.split("\n");
      const [changeId = "", commitId = ""] = ids.split(" ");
      return { changeId, commitId, description: description.join("\n") };
    },
  });

  readonly workspace = callable(this.prefixed("workspace"), {
    // Under the plugin's own worktree root, so forget/setup/rename never touch
    // a checkout the plugin did not create.
    isManaged: (): boolean =>
      this.cwd !== WORKTREES_ROOT && this.cwd.startsWith(WORKTREES_ROOT + sep),

    // Is this directory the root of a jj workspace?
    is: (): Promise<boolean> => pathExists(join(this.cwd, ".jj")),

    // The name of the workspace this directory belongs to.
    name: async (): Promise<string> => {
      const names = await this.read`log --no-graph -r @ -T working_copies`;
      const name = names.split(/\s+/).find((entry) => entry.endsWith("@"));
      if (!name) throw new Error(`jj-workspaces: ${this.cwd} has no working-copy name`);
      return name.slice(0, -1);
    },

    // Root of the workspace containing this directory, or null outside any jj repo.
    root: (): Promise<string | null> => this.read`workspace root`.catch(() => null),

    // A colocated workspace of this repo at `path`, on top of `revision` (default: `@-`).
    add: async (input: { name: string; path: string; revision?: string }): Promise<void> => {
      const base = input.revision ? ["-r", input.revision] : [];
      await this.run`workspace add --colocate --name ${input.name} ${base} ${input.path}`;
    },

    rename: async (name: string): Promise<void> => {
      await this.run`workspace rename ${name}`;
    },

    // Snapshots first, so unfinished edits survive as a commit in the main repo.
    forget: async (): Promise<void> => {
      await this.run`workspace forget`;
    },

    // Move this workspace's bookmark (named after the workspace) up to the
    // newest pushable commit, then put git's HEAD on that branch. jj writes a
    // detached HEAD at `@-` whenever `@-` moves; once the branch and `@-` are
    // the same commit, a symbolic HEAD is equivalent and survives until the
    // next such move. Returns whether HEAD ended up attached.
    align: async (): Promise<boolean> => {
      const name = await this.workspace.name();
      // mimic jj-hooks' `bookmark-advance-to`: the newest described, non-empty,
      // mutable ancestor of `@`, i.e. the commit a workspace bookmark should be on.
      const pushable = `heads(::@ & mutable() & ~description(exact:"") & (~empty() | merges()))`;
      await this.bookmark.advance(name, pushable);
      const parent = await this.read`log --no-graph -r @- -T commit_id`.catch(() => null);
      const branch = await this.git.revParse(`refs/heads/${name}`);
      if (!parent || parent !== branch) return false;
      await this.git.attach(name);
      return true;
    },
  });

  readonly bookmark = callable(this.prefixed("bookmark"), {
    // False when a bookmark of that name already exists.
    create: async (name: string, revision: string): Promise<boolean> => {
      return (await this.try`bookmark create ${name} -r ${revision}`) !== null;
    },

    // Tracked remote bookmarks as jj revsets (`main@origin`), optionally only
    // the one matching a git-style `<remote>/<name>`; `git` is the colocated
    // pseudo-remote, so `refs/heads/main` corresponds to `main@git`.
    list: async (ref?: string): Promise<string[]> => {
      const template = `if(tracked, remote ++ "/" ++ name ++ "::" ++ name ++ "@" ++ remote ++ "\n", "")`;
      const entries = (await this.read`bookmark list -a -T ${template}`)
        .split("\n")
        .filter(Boolean);
      return entries
        .filter((entry) => !ref || entry.split("::")[0] === ref)
        .map((entry) => entry.split("::")[1] ?? "");
    },

    // False when there is no bookmark `from` to rename.
    rename: async (from: string, to: string): Promise<boolean> => {
      return (await this.try`bookmark rename ${from} ${to}`) !== null;
    },

    delete: async (name: string): Promise<void> => {
      await this.run`bookmark delete ${name}`;
    },

    // Forward-only and never creates: false when the bookmark is missing, the
    // revset names no single commit, or the move would go backwards.
    advance: async (name: string, to: string): Promise<boolean> => {
      return (await this.try`bookmark move ${name} --to ${to}`) !== null;
    },
  });

  // The colocated git side, for the few things jj does not manage.
  readonly git = {
    // Full commit id a ref points at, or null when it does not exist.
    revParse: async (ref: string): Promise<string | null> => {
      return this.execGit(["rev-parse", "--verify", "-q", ref]).catch(() => null);
    },

    attach: async (branch: string): Promise<void> => {
      this.execGit(["symbolic-ref", "HEAD", `refs/heads/${branch}`]).catch(() => null);
    },
  };

  private prefixed(...prefix: string[]): Tag<string> {
    return (strings, ...values) => this.exec([...prefix, ...argv(strings, values)]);
  }

  private async exec(args: string[]): Promise<string> {
    const config = Object.entries(this.options.config ?? {}).flatMap(([key, value]) => [
      "--config",
      `${key}=${value}`,
    ]);
    return this.execWith("jj", [...config, ...args]);
  }

  private async execGit(args: string[]): Promise<string> {
    return this.execWith("git", args);
  }

  private async execWith(binary: Binary, args: string[]): Promise<string> {
    const binPath = await getBinaryFor(binary);
    const result = await execa(binPath, [...args], {
      cwd: this.cwd,
      reject: false,
    });
    if (result.failed) {
      const msg = `${binary} ${args.join(" ")} failed in ${this.cwd}: ${result.stderr.trim()}`;
      log.error(msg);
      throw new Error(msg);
    }
    return result.stdout.trim();
  }
}

export function createJJClient(cwd: string, options?: JJClientOptions): JJClient {
  return new JJClient(cwd, options);
}
