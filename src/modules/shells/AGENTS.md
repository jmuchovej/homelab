# shells/ — login shells

One file per shell (`rbn.shells._.{zsh,bash,nushell}`). Split: the `os` key
registers the package in `environment.shells`; all actual configuration lives
under `homeManager`. A user's _login_ shell is chosen in their user file via
`den.batteries.user-shell "<shell>"` — including a shell aspect only makes it
available/configured, it does not make it the login shell.

Shell-agnostic CLI tools (starship, zoxide, carapace, fzf…) live in
`programs/terminal/`, not here — this directory is only the shells
themselves.
