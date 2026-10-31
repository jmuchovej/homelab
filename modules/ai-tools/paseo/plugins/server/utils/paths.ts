import { homedir } from "node:os";

import { basename, join } from "pathe";

// The daemon runs with the desktop app's environment, so this cannot come from
// a shell variable; it is the plugin's one fixed location.
export const WORKTREES_ROOT = join(homedir(), "Documents", "dev", "worktrees", "_paseo");

export function workspacePath(root: string, slug: string): string {
  return join(WORKTREES_ROOT, basename(root), slug);
}
