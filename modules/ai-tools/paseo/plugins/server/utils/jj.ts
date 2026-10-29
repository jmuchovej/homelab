import { homedir, userInfo } from "node:os";

import { execa, parseCommandString } from "execa";
import { pathExists } from "fs-extra/esm";
import { join } from "pathe";

// Not a bare `jj`: the daemon's GUI PATH has no nix profile on it.
const CANDIDATES = [
  `/etc/profiles/per-user/${userInfo().username}/bin/jj`,
  `${homedir()}/.nix-profile/bin/jj`,
  "/run/current-system/sw/bin/jj",
  "/opt/homebrew/bin/jj",
  "/usr/local/bin/jj",
];

let binary: Promise<string> | undefined;

async function lookupBinary(): Promise<string> {
  binary ??= (async () => {
    for (const candidate of CANDIDATES) {
      if (await pathExists(candidate)) return candidate;
    }
    return "jj";
  })();
  return binary;
}

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

async function exec(cwd: string, args: string[]): Promise<string> {
  const result = await execa(await lookupBinary(), args, { cwd, reject: false });
  if (result.failed) {
    throw new Error(`jj ${args.join(" ")} failed in ${cwd}: ${result.stderr.trim()}`);
  }
  return result.stdout.trim();
}

type Tag<Result> = (strings: TemplateStringsArray, ...values: Part[]) => Promise<Result>;

// Not `Object.assign`: a function's own `name` and `length` are read-only, so
// assigning a member called `name` onto a callable throws at load time.
function callable<F extends object, M extends object>(fn: F, members: M): F & M {
  for (const [key, value] of Object.entries(members)) {
    Object.defineProperty(fn, key, { value, writable: true, configurable: true, enumerable: true });
  }
  return fn as F & M;
}

// A subcommand is a fixed argv prefix; `jj.bookmark(cwd)\`rename a b\`` runs
// `jj bookmark rename a b`. Each one carries a `.try` that yields null instead
// of throwing, so `jj.try` is just the prefix-less case.
function command(...prefix: string[]) {
  const strict =
    (cwd: string): Tag<string> =>
    (strings, ...values) =>
      exec(cwd, [...prefix, ...argv(strings, values)]);
  const lenient =
    (cwd: string): Tag<string | null> =>
    async (strings, ...values) => {
      try {
        return await strict(cwd)(strings, ...values);
      } catch {
        return null;
      }
    };
  return callable(strict, { try: lenient });
}

export const jj = callable(command(), {
  log: callable(command("--ignore-working-copy", "log", "--no-graph"), {
    latestRevision(cwd: string, candidate: string): Promise<string | null> {
      return jj.log.try(cwd)`--limit 1 --reversed -T commit_id -r ${candidate}`;
    },
    revision(cwd: string, candidate: string): Promise<string | null> {
      return jj.log.try(cwd)`-T commit_id -r ${candidate}`;
    },
  }),

  bookmark: callable(command("bookmark"), {
    rename: (cwd: string, current: string, desired: string) =>
      jj.bookmark.try(cwd)`rename ${current} ${desired}`,
    delete: (cwd: string, name: string) => jj.bookmark(cwd)`delete ${name}`,
  }),

  workspace: callable(command("workspace"), {
    is: (path: string): Promise<boolean> => pathExists(join(path, ".jj")),

    // The jj workspace name, read from inside the workspace.
    async name(cwd: string): Promise<string> {
      const names = await jj.log(cwd)`-r @ -T working_copies`;
      const name = names.split(/\s+/).find((entry) => entry.endsWith("@"));
      if (!name) throw new Error(`jj-workspaces: ${cwd} has no working-copy name`);
      return name.slice(0, -1);
    },

    // The main checkout, from any workspace of the repo.
    root: (cwd: string): Promise<string> =>
      jj.workspace(cwd)`root --name default --ignore-working-copy`,

    rename: (cwd: string, desired: string): Promise<string> => jj.workspace(cwd)`rename ${desired}`,
    forget: (cwd: string): Promise<string> => jj.workspace(cwd)`forget`,
  }),
});
