---
name: nix-naming
description: "Nix naming conventions and code style. Use when naming variables, files, or organizing attributes in Nix code."
---

# Naming Conventions

## Quick Reference

| Element    | Style      | Examples                             |
| ---------- | ---------- | ------------------------------------ |
| Variables  | kebab-case | `cfg`, `user-name`, `enable-feature` |
| Files/dirs | kebab-case | `my-module.nix`, `window-managers/`  |
| Constants  | UPPER_CASE | `MAX_RETRIES`, `DEFAULT_PORT`        |

## Variables

```nix
let
  # Correct - camelCase
  user-name = "khaneliman";
  server-hostname = "myserver";
  enable-auto-start = true;

  # Wrong
  userName = "...";   # camelCase
  user_name = "...";  # snake_case
  UserName = "...";   # PascalCase
in
```

## The cfg Pattern

Always use this pattern:

```nix
let
  cfg = config.rebellion.programs.my-app;
in
{
  config = lib.mkIf cfg.enable { ... };
}
```

## File Naming

```
# Correct - kebab-case
modules/home/programs/my-app.nix
modules/nixos/services/my-service.nix

# Wrong
modules/home/programs/myApp.nix        # camelCase
modules/nixos/services/my_service.nix  # snake_case
```

## Attribute Organization

Group by function, then alphabetically:

```nix
{
  # Options first
  options.namespace.module = { ... };

  # Config second
  config = {
    # Group related settings
    programs.git = { ... };
    programs.vim = { ... };

    # Then packages
    home.packages = [ ... ];
  };
}
```

## Formatting

- Use `nixfmt` for consistent formatting
- Prefer flat dot-notation: `services.nginx.enable = true`
- Avoid deep nesting when flat works
