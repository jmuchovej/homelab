import { homedir } from "node:os";

import { pathExists } from "fs-extra/esm";
import { basename, join } from "pathe";

// The daemon runs with the desktop app's environment, so this cannot come from
// a shell variable; it is the plugin's one fixed location.
export const WORKTREES_ROOT = join(homedir(), "Documents", "dev", "worktrees", "_paseo");

export function workspacePath(root: string, slug: string): string {
  return join(WORKTREES_ROOT, basename(root), slug);
}

const USER = process.env.USER || basename(homedir());

const PATHS = [
  `/etc/profiles/per-user/${USER}/bin`,
  `${homedir()}/.nix-profile/bin`,
  "/run/current-system/sw/bin",
  "/opt/homebrew/bin",
  "/usr/local/bin",
];

export type Binary = "jj" | "git";
const binaries = new Map<Binary, Promise<string>>();

export function getBinaryFor(name: Binary): Promise<string> {
  let found = binaries.get(name);
  if (!found) {
    found = (async () => {
      for (const dir of PATHS) {
        if (await pathExists(join(dir, name))) return join(dir, name);
      }
      return name;
    })();
    binaries.set(name, found);
  }
  return found;
}
