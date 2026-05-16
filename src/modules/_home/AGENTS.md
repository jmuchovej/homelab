# `/modules/home/` - Home Manager Modules

This directory contains **Home Manager modules** for user environment
configuration in the `rebellion` homelab. These modules manage user-specific
settings, dotfiles, applications, and services that run in user space.

## Overview

Home Manager modules in `rebellion` provide declarative user environment
management across all platforms (NixOS, macOS, and standalone installations).
These modules focus on:

- **User applications and packages**
- **Dotfile configuration**
- **User services and daemons**
- **Shell environments and aliases**
- **Desktop environment customization**
- **Development tool configuration**

## Directory Structure

```
modules/home/
├── AGENTS.md                    # This file
├── common/                      # Common/shared configurations
├── common.nix                   # Top-level common module
├── desktop/                     # Desktop/GUI applications & environment
│   ├── browsers/               # Web browsers
│   │   ├── arc.nix             # rebellion.desktop.arc
│   │   ├── brave.nix           # rebellion.desktop.brave
│   │   ├── firefox.nix         # rebellion.desktop.firefox
│   │   ├── google-chrome.nix   # rebellion.desktop.google-chrome
│   │   └── vivaldi.nix         # rebellion.desktop.vivaldi
│   ├── communication/          # Communication apps
│   ├── emulators/              # Emulation software
│   ├── pkm/                    # Personal knowledge management
│   ├── fermium.nix             # rebellion.desktop.fermium
│   ├── modeling.nix            # rebellion.desktop.modeling
│   ├── openconnect.nix         # rebellion.desktop.openconnect
│   ├── plex.nix                # rebellion.desktop.plex
│   ├── proton.nix              # rebellion.desktop.proton
│   └── spotify.nix             # rebellion.desktop.spotify
├── desktop.nix                  # Top-level desktop module
├── development/                 # Development tools & languages
│   ├── app.nix                 # rebellion.development.app
│   ├── go.nix                  # rebellion.development.go
│   ├── julia.nix               # rebellion.development.julia
│   ├── nix.nix                 # rebellion.development.nix
│   ├── python.nix              # rebellion.development.python
│   ├── rlang.nix               # rebellion.development.rlang
│   ├── rust.nix                # rebellion.development.rust
│   ├── typst.nix               # rebellion.development.typst
│   └── web.nix                 # rebellion.development.web
├── development.nix              # Top-level development module
├── editor/                      # Text editors (separate namespace!)
│   ├── micro/                  # Micro editor configs
│   ├── helix.nix               # rebellion.editor.helix
│   ├── helix-languages.part.nix # Helix language support
│   ├── micro.nix               # rebellion.editor.micro
│   ├── neovim.nix              # rebellion.editor.neovim
│   ├── vscode.nix              # rebellion.editor.vscode
│   └── zed.nix                 # rebellion.editor.zed
├── editor.nix                   # Top-level editor module
├── homelab/                     # Homelab-specific configurations
├── homelab.nix                  # Top-level homelab module
├── programs/                    # General programs
│   ├── statusbars/             # Status bar programs
│   └── tools/                  # General tools
├── services/                    # User services and daemons
│   ├── sops.nix                # rebellion.services.sops
│   ├── ssh-agent.nix           # rebellion.services.ssh-agent
│   └── syncthing.nix           # rebellion.services.syncthing
├── shell/                       # Shell configuration
│   ├── bash.nix                # rebellion.shell.bash
│   ├── nushell.nix             # rebellion.shell.nushell
│   └── zsh.nix                 # rebellion.shell.zsh
├── shell.nix                    # Top-level shell module
└── theme/                       # Theme configurations
```

## Purpose-Based Organization

The structure groups modules by **purpose/context**:

- **`common/`** - Tools and configurations that should always be applied across
  every `home-manager` environment
- **`desktop/`** - GUI applications and desktop environment (browsers, media
  apps, GUI tools)
- **`editor/`** - Text editors
- **`development/`** - Development tools and language environments
- **`shell/`** - Shell environments and terminal configuration
- **`services/`** - Background services and daemons
- **`programs/`** - General purpose programs and utilities
- **Top-level .nix files** - Suite modules that aggregate related functionality

**Mixed Naming Patterns**:

- Some modules use **flat names**: `rebellion.desktop.firefox`,
  `rebellion.development.rust`
- Some modules use **grouped names**: `rebellion.desktop.brave` (even though
  it's in `desktop/browsers/brave.nix`)
- **Editors have their own namespace**: `rebellion.editor.neovim` (not
  `rebellion.development.neovim`)

````
## Core Patterns

### 1. Module Structure

All home-manager modules follow the `rebellion` namespace pattern:

```nix
# modules/home/editor/neovim.nix
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkIf types;
  inherit (lib.rebellion) mk-opt enabled disabled;

  cfg = config.rebellion.editor.neovim;
in
{
  options.rebellion.editor.neovim = {
    enable = mk-opt types.bool false "Enable Neovim configuration";

    plugins = mk-opt (types.listOf types.str) [ ]
      "List of additional Neovim plugins to install";

    extraConfig = mk-opt types.str ""
      "Extra Neovim configuration";
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      plugins = with pkgs.vimPlugins; [
        # Default plugins
        telescope-nvim
        nvim-lspconfig
      ] ++ (map (name: pkgs.vimPlugins.${name}) cfg.plugins);

      extraConfig = ''
        -- Default config
        ${cfg.extraConfig}
      '';
    };
  };
}
````

### 2. Configuration Integration

Home modules integrate with system-level configuration:

```nix
# In homes/{user}/{host}/default.nix
{
  rebellion = {
    editor.neovim = enabled;
    development.nix = enabled;
    shell.zsh = {
      enable = true;
      aliases = {
        vim = "nvim";
        vi = "nvim";
      };
    };
  };
}
```

### 3. Cross-Platform Compatibility

Use platform-specific conditionals when needed:

```nix
config = mkIf cfg.enable {
  programs.alacritty = {
    enable = true;
    settings = {
      font.family = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.isDarwin "SF Mono")
        (lib.mkIf pkgs.stdenv.isLinux "Fira Code")
      ];
    };
  };
};
```

## Common Module Categories

### 1. Desktop Modules

**Purpose**: Configure GUI applications and desktop environment **Location**:
`desktop/`

```nix
# Example: Browser configuration (desktop/browsers/firefox.nix)
options.rebellion.desktop.firefox = {
  enable = mk-opt types.bool false "Enable Firefox configuration";

  bookmarks = mk-opt (types.listOf types.attrs) [ ]
    "Firefox bookmarks to configure";

  extensions = mk-opt (types.listOf types.str) [ ]
    "Firefox extensions to install";
};

config = mkIf cfg.enable {
  programs.firefox = {
    enable = true;
    profiles.default = {
      bookmarks = cfg.bookmarks;
      extensions = with pkgs.nur.repos.rycee.firefox-addons;
        map (name: pkgs.nur.repos.rycee.firefox-addons.${name}) cfg.extensions;
    };
  };
};
```

### 2. Development Environment Modules

**Purpose**: Configure development tools and language environments\
**Location**: `development/`

```nix
# Example: Language toolchain (development/rust.nix)
options.rebellion.development.rust = {
  enable = mk-opt types.bool false "Enable Rust development environment";

  components = mk-opt (types.listOf types.str) [ "rustc" "cargo" "rust-fmt" ]
    "Rust components to install";

  targets = mk-opt (types.listOf types.str) [ ]
    "Additional compilation targets";
};

config = mkIf cfg.enable {
  home.packages = with pkgs; [
    (rust-bin.stable.latest.default.override {
      extensions = cfg.components;
      targets = cfg.targets;
    })
    rust-analyzer
  ];

  # Configure development tools
  programs.vscode.extensions = [ "rust-lang.rust-analyzer" ];
};
```

### 3. Shell Configuration Modules

**Purpose**: Configure shell environments, aliases, and prompt **Location**:
`shell/`

```nix
# Example: Zsh configuration (shell/zsh.nix)
options.rebellion.shell.zsh = {
  enable = mk-opt types.bool false "Enable Zsh configuration";

  aliases = mk-opt (types.attrsOf types.str) { }
    "Shell aliases to configure";

  functions = mk-opt (types.attrsOf types.str) { }
    "Custom shell functions";

  plugins = mk-opt (types.listOf types.str) [ ]
    "Zsh plugins to enable";
};

config = mkIf cfg.enable {
  programs.zsh = {
    enable = true;
    shellAliases = cfg.aliases;
    initExtra = lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: body: "${name}() {\n${body}\n}") cfg.functions);
  };
};
```

### 4. Service Modules

**Purpose**: Configure user-level systemd services and daemons **Location**:
`services/`

```nix
# Example: Backup service (services/restic.nix)
# Note: On macOS, uses launchd instead of systemd
options.rebellion.services.restic = {
  enable = mk-opt types.bool false "Enable Restic backup service";

  repository = mk-opt types.str ""
    "Restic repository URL";

  schedule = mk-opt types.str "daily"
    "Backup schedule";

  paths = mk-opt (types.listOf types.str) [ ]
    "Paths to backup";
};

config = mkIf cfg.enable (lib.mkMerge [
  # Linux systemd service
  (lib.mkIf pkgs.stdenv.isLinux {
    services.restic.backups.home = {
      inherit (cfg) repository paths;
      passwordFile = config.sops.secrets.restic-password.path;
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  })

  # macOS launchd service
  (lib.mkIf pkgs.stdenv.isDarwin {
    launchd.agents.restic-backup = {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.restic}/bin/restic" "backup" ] ++ cfg.paths;
        StartCalendarInterval = [{ Hour = 2; Minute = 0; }]; # Daily at 2 AM
      };
    };
  })
]);
```

## Development Workflows

### Creating New Home Modules

1. **Choose appropriate purpose-based category**:
   - GUI applications → `desktop/` (may have subdirectories)
   - Text editors → `editor/`
   - Development tools → `development/`
   - Shell config → `shell/`
   - Background services → `services/`
   - General programs → `programs/`

2. **Create module file**:

   ```bash
   touch modules/home/editor/my-editor.nix
   ```

3. **Follow the module template**:

   ```nix
   { lib, config, pkgs, ... }:
   let
     inherit (lib) mkIf;
     inherit (lib.rebellion) mk-opt enabled;

     cfg = config.rebellion.editor.my-editor;
   in
   {
     options.rebellion.editor.my-editor = {
       enable = mk-opt lib.types.bool false "Enable my-editor";
       # Add specific options
     };

     config = mkIf cfg.enable {
       # Home Manager configuration
     };
   }
   ```

4. **Test the module**:

   ```bash
   # Test in user config
   rebellion.editor.my-editor = enabled;

   # Build and switch
   home-manager switch --flake .#{user}@{host}
   ```

### Integrating with System Configuration

Home modules often need to coordinate with system-level configuration:

```nix
# System module (modules/nixos/services/my-service.nix)
options.rebellion.services.my-service = {
  enable = mk-opt types.bool false "Enable system service";
  users = mk-opt (types.listOf types.str) [ ] "Users to configure";
};

# Home module (modules/home/services/my-service.nix)
options.rebellion.services.my-service = {
  enable = mk-opt types.bool false "Enable user service client";
  serverAddress = mk-opt types.str "localhost" "Service server address";
};

config = mkIf cfg.enable {
  # User-specific client configuration
  programs.my-service-client = {
    enable = true;
    settings.server = cfg.serverAddress;
  };
};
```

## Testing & Debugging

### Testing Home Modules

```bash
# Test home configuration build
nix build .#homeConfigurations.{user}@{host}.activationPackage

# Test specific module
nix repl
> :lf .
> homeConfigurations.{user}@{host}.options.rebellion.editor

# Dry run activation
home-manager switch --flake .#{user}@{host} --dry-run
```

### Debugging Common Issues

**Module not loading**:

```bash
# Check if module is imported
nix eval .#homeConfigurations.{user}@{host}.options.rebellion --json | jq keys

# Check module syntax
nix-instantiate --parse modules/home/path/to/module.nix
```

**Configuration conflicts**:

```bash
# Check for option collisions
home-manager switch --flake .#{user}@{host} --show-trace

# Inspect final configuration
nix eval .#homeConfigurations.{user}@{host}.config.programs
```

**Service issues**:

```bash
# Check user services
systemctl --user status my-service
journalctl --user -f -u my-service

# Restart user services
systemctl --user daemon-reload
systemctl --user restart my-service
```

## Integration Patterns

### 1. Suite Integration

Home modules can be included in suites:

```nix
# In suites definition
rebellion.suites.development = {
  home = {
    editor.neovim = enabled;
    editor.vscode = enabled;
    development = {
      nix = enabled;
      rust = enabled;
      python = enabled;
    };
    shell.zsh = enabled;
  };
};
```

### 2. Conditional Configuration

Enable modules based on system capabilities:

```nix
config = lib.mkMerge [
  # Always enabled
  {
    rebellion.shell.zsh = enabled;
  }

  # Only on macOS with desktop
  (lib.mkIf (pkgs.stdenv.isDarwin && config.rebellion.suites.desktop.enable) {
    rebellion = {
      desktop.firefox = enabled;
      desktop.yabai = enabled;
    };
  })

  # Only on development systems
  (lib.mkIf config.rebellion.suites.development.enable {
    rebellion.development.nix = enabled;
  })
];
```

### 3. User-Specific Customization

Allow per-user customization while maintaining defaults:

```nix
# In homes/{user}/{host}/default.nix
{
  rebellion = {
    editor.neovim = {
      enable = true;
      plugins = [ "trouble-nvim" "which-key-nvim" ];
      extraConfig = ''
        -- User-specific Neovim config
        vim.opt.colorscheme = "gruvbox"
      '';
    };
  };
}
```

## Best Practices

### 1. Modular Design

- Keep modules focused on single applications or related functionality
- Use composition over inheritance
- Provide sensible defaults with customization options

### 2. Cross-Platform Support

- Test modules on different platforms (NixOS, macOS, Ubuntu)
- Use platform-specific conditionals when needed
- Avoid hardcoding paths or platform-specific settings

### 3. Documentation

- Document all module options with clear descriptions
- Provide usage examples in module comments
- Include common configuration patterns

### 4. Error Handling

- Validate configuration options
- Provide helpful error messages
- Use assertions for critical dependencies

```nix
config = mkIf cfg.enable {
  assertions = [
    {
      assertion = cfg.repository != "";
      message = "rebellion.home.services.backup.restic.repository must be set";
    }
  ];

  # Rest of configuration
};
```

## Common Gotchas

1. **Home Manager vs System Packages**: Don't install the same package at both
   system and user level
2. **Service Dependencies**: User services may depend on system services being
   available
3. **File Conflicts**: Multiple modules managing the same files can cause
   conflicts
4. **Platform Differences**: macOS uses launchd while Linux uses systemd for
   services
5. **State Management**: Some applications need manual state migration when
   changing configs
6. **macOS Permissions**: Some features may require manual permission grants in
   System Preferences

## Reference Examples

See existing modules for patterns:

- `desktop/` - GUI applications and desktop environment (browsers, media apps,
  desktop tools)
- `editor/` - Text editors and IDEs (Neovim, VS Code, Helix, Zed)
- `development/` - Development tools and language environments (Rust, Python,
  Go, Nix)
- `shell/` - Shell environment setup (Zsh, Bash, NuShell)
- `services/` - User service management (Syncthing, SOPS, SSH agent)

For complex examples, examine how suite composition works in the broader
`rebellion` configuration.
