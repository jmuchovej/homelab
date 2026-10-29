import { homedir } from "node:os";

import { basename, join, resolve, sep } from "pathe";
import { kebabCase, splitByCase } from "scule";

export { jj } from "./jj";

// scule does not split on spaces by default and keeps punctuation; bookmark
// names must be plain, so parts are scrubbed before joining.
export function slugify(value: string): string {
  const parts = splitByCase(value, [" ", "-", "_", "/", "."])
    .map((part) => part.replace(/[^a-z0-9]/gi, ""))
    .filter((part) => part !== "");
  return kebabCase(parts);
}

export const ROOT = join(homedir(), "Documents", "dev", "worktrees", "_paseo");

export function workspacePath(root: string, slug: string): string {
  return join(ROOT, basename(root), slug);
}

export function isManagedPath(path: string): boolean {
  const resolved = resolve(path);
  return resolved !== ROOT && resolved.startsWith(ROOT + sep);
}
