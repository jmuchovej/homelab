# `/modules/macos/` - macOS System Modules

This directory contains **nix-darwin system modules** for declarative macOS
configuration in the `rebellion` homelab. These modules manage system-level
preferences, services, applications, and macOS-specific features using
nix-darwin.

## Overview

macOS modules in `rebellion` provide declarative system configuration management
for:

- **System preferences and defaults**
- **Homebrew package and application management**
- **macOS-specific services and daemons**
- **Application installation and configuration**
- **Security settings and policies**
- **Development environment setup**
- **Networking and VPN configuration**
- **User account and permission management**

## Directory Structure

```
modules/macos/
├── AGENTS.md                    # This file
├── applications/                # macOS applications
│   ├── browsers/               # Safari, Chrome, Firefox configs
│   ├── development/            # Xcode, dev tools
│   ├── media/                  # QuickTime, IINA, etc.
│   └── utilities/              # System utilities, tools
├── homebrew/                    # Homebrew management
│   ├── formulae/               # Command-line tools
│   ├── casks/                  # GUI applications
│   ├── taps/                   # Custom repositories
│   └── services/               # Homebrew services
├── networking/                  # Network configuration
│   ├── dns/                    # DNS settings
│   ├── firewall/               # macOS firewall config
│   ├── proxy/                  # Proxy configurations
│   └── vpn/                    # VPN clients (Tailscale, etc.)
├── security/                    # Security and privacy
│   ├── authentication/         # Touch ID, password policies
│   ├── encryption/             # FileVault, keychain
│   ├── gatekeeper/             # App security policies
│   └── privacy/                # Privacy settings
├── services/                    # System services
│   ├── backup/                 # Time Machine, cloud backup
│   ├── development/            # Development services
│   ├── monitoring/             # System monitoring
│   └── synchronization/        # File sync services
├── system/                      # Core system configuration
│   ├── defaults/               # System preferences
│   ├── dock/                   # Dock configuration
│   ├── finder/                 # Finder settings
│   ├── fonts/                  # System font management
│   ├── keyboard/               # Keyboard and input settings
│   ├── locale/                 # Localization settings
│   ├── menubar/                # Menu bar configuration
│   ├── trackpad/               # Trackpad and mouse settings
│   └── users/                  # User account management
└── virtualization/              # Virtualization on macOS
    ├── docker/                 # Docker Desktop
    ├── parallels/              # Parallels Desktop
    └── vmware/                 # VMware Fusion
```

## Core Patterns

### 1. nix-darwin Module Structure

All macOS modules follow the `rebellion` namespace pattern with nix-darwin
integration:

```nix
# modules/macos/system/dock.nix
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkIf types;
  inherit (lib.rebellion) mk-opt enabled disabled;

  cfg = config.rebellion.macos.system.dock;
in
{
  options.rebellion.macos.system.dock = {
    enable = mk-opt types.bool false "Enable Dock configuration";

    position = mk-opt (types.enum [ "bottom" "left" "right" ]) "bottom"
      "Dock position on screen";

    autohide = mk-opt types.bool true
      "Automatically hide and show the Dock";

    showRecents = mk-opt types.bool false
      "Show recent applications in Dock";

    tileSize = mk-opt types.int 48
      "Size of Dock tiles";

    magnification = {
      enable = mk-opt types.bool false
        "Enable Dock magnification";

      size = mk-opt types.int 64
        "Maximum magnification size";
    };

    applications = mk-opt (types.listOf types.str) [ ]
      "Applications to pin to Dock";
  };

  config = mkIf cfg.enable {
    system.defaults.dock = {
      orientation = cfg.position;
      autohide = cfg.autohide;
      show-recents = cfg.showRecents;
      tilesize = cfg.tileSize;
      magnification = cfg.magnification.enable;
      largesize = cfg.magnification.size;

      # Remove all default apps and add specified ones
      persistent-apps = map (app: "/Applications/${app}.app") cfg.applications;
    };

    # Apply changes immediately
    system.activationScripts.dock.text = ''
      echo "Restarting Dock..."
      killall Dock || true
    '';
  };
}
```

### 2. System Defaults Pattern

macOS system preferences are managed through the defaults system:

```nix
# modules/macos/system/finder.nix
{ lib, config, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) mk-opt;

  cfg = config.rebellion.macos.system.finder;
in
{
  options.rebellion.macos.system.finder = {
    enable = mk-opt lib.types.bool false "Enable Finder configuration";

    showHiddenFiles = mk-opt lib.types.bool true
      "Show hidden files in Finder";

    showPathBar = mk-opt lib.types.bool true
      "Show path bar in Finder windows";

    showStatusBar = mk-opt lib.types.bool true
      "Show status bar in Finder windows";

    defaultViewStyle = mk-opt (lib.types.enum [ "icnv" "Nlsv" "clmv" "Flwv" ]) "Nlsv"
      "Default view style (icon/list/column/gallery)";

    searchScope = mk-opt (lib.types.enum [ "SCev" "SCcf" "SCsp" ]) "SCcf"
      "Search scope (everywhere/current folder/previous)";
  };

  config = mkIf cfg.enable {
    system.defaults.finder = {
      AppleShowAllFiles = cfg.showHiddenFiles;
      ShowPathbar = cfg.showPathBar;
      ShowStatusBar = cfg.showStatusBar;
      FXPreferredViewStyle = cfg.defaultViewStyle;
      FXDefaultSearchScope = cfg.searchScope;

      # Additional useful defaults
      FXEnableExtensionChangeWarning = false;
      _FXShowPosixPathInTitle = true;
      AppleShowAllExtensions = true;
    };

    # Custom folder settings
    system.defaults.universalaccess = {
      reduceTransparency = false;
      reduceMotion = false;
    };
  };
}
```

### 3. Homebrew Integration Pattern

Homebrew packages and applications are managed declaratively:

```nix
# modules/macos/homebrew/development.nix
{ lib, config, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) mk-opt;

  cfg = config.rebellion.macos.homebrew.development;
in
{
  options.rebellion.macos.homebrew.development = {
    enable = mk-opt lib.types.bool false "Enable development tools via Homebrew";

    formulae = mk-opt (lib.types.listOf lib.types.str) [
      "git"
      "gh"
      "node"
      "python@3.11"
      "rust"
      "go"
    ] "Development formulae to install";

    casks = mk-opt (lib.types.listOf lib.types.str) [
      "visual-studio-code"
      "docker"
      "postman"
      "tableplus"
    ] "Development applications to install";

    services = mk-opt (lib.types.listOf lib.types.str) [ ]
      "Homebrew services to start";
  };

  config = mkIf cfg.enable {
    homebrew = {
      enable = true;
      brews = cfg.formulae;
      casks = cfg.casks;

      # Auto-start specified services
      taps = [ "homebrew/services" ];
    };

    # Configure services
    launchd.daemons = lib.listToAttrs (map (service: {
      name = "homebrew-${service}";
      value = {
        script = ''
          ${pkgs.homebrew}/bin/brew services start ${service}
        '';
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
        };
      };
    }) cfg.services);
  };
}
```

### 4. Application Management Pattern

Both Nix and Homebrew applications are managed consistently:

```nix
# modules/macos/applications/browsers/firefox.nix
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) mk-opt enabled;

  cfg = config.rebellion.macos.applications.browsers.firefox;
in
{
  options.rebellion.macos.applications.browsers.firefox = {
    enable = mk-opt lib.types.bool false "Enable Firefox browser";

    source = mk-opt (lib.types.enum [ "nixpkgs" "homebrew" ]) "homebrew"
      "Installation source for Firefox";

    setDefaultBrowser = mk-opt lib.types.bool false
      "Set Firefox as default browser";

    profiles = mk-opt lib.types.attrs { }
      "Firefox profiles configuration";
  };

  config = mkIf cfg.enable (lib.mkMerge [
    # Install via Homebrew (recommended for macOS)
    (lib.mkIf (cfg.source == "homebrew") {
      homebrew.casks = [ "firefox" ];
    })

    # Install via Nix (alternative)
    (lib.mkIf (cfg.source == "nixpkgs") {
      environment.systemPackages = [ pkgs.firefox-bin ];
    })

    # Set as default browser
    (lib.mkIf cfg.setDefaultBrowser {
      system.activationScripts.defaultBrowser.text = ''
        # Set Firefox as default browser
        ${pkgs.duti}/bin/duti -s org.mozilla.firefox public.html all
        ${pkgs.duti}/bin/duti -s org.mozilla.firefox public.xhtml all
        ${pkgs.duti}/bin/duti -s org.mozilla.firefox com.compuserve.gif all
      '';
    })

    # Profile management integrates with home-manager
    {
      rebellion.home.applications.browsers.firefox = {
        enable = true;
        profiles = cfg.profiles;
      };
    }
  ]);
}
```

## Common Module Categories

### 1. System Preferences Modules

**Purpose**: Configure macOS system preferences and defaults **Location**:
`system/`

Key areas:

- Dock configuration and behavior
- Finder settings and view options
- Keyboard shortcuts and input methods
- Trackpad and mouse sensitivity
- Menu bar and status items
- Mission Control and Spaces
- Security and privacy settings

```nix
# Example: Keyboard configuration
options.rebellion.macos.system.keyboard = {
  enable = mk-opt types.bool false "Enable keyboard configuration";

  keyRepeat = mk-opt types.int 2
    "Key repeat rate (1-10, lower is faster)";

  initialKeyRepeat = mk-opt types.int 15
    "Initial key repeat delay (10-120)";

  shortcuts = mk-opt (types.attrsOf types.str) { }
    "Custom keyboard shortcuts";

  inputSources = mk-opt (types.listOf types.str) [ "com.apple.keylayout.US" ]
    "Keyboard input sources";
};

config = mkIf cfg.enable {
  system.defaults.NSGlobalDomain = {
    KeyRepeat = cfg.keyRepeat;
    InitialKeyRepeat = cfg.initialKeyRepeat;
    AppleKeyboardUIMode = 3; # Enable full keyboard access
  };

  # Custom shortcuts
  system.defaults.com.apple.symbolichotkeys = {
    AppleSymbolicHotKeys = lib.mapAttrs (key: value: {
      enabled = true;
      value = { parameters = [ value ]; };
    }) cfg.shortcuts;
  };
};
```

### 2. Application Management Modules

**Purpose**: Install and configure applications **Location**: `applications/`

Supports both Nix and Homebrew installation:

```nix
# Generic application module pattern
options.rebellion.macos.applications.{category}.{app} = {
  enable = mk-opt types.bool false "Enable {app}";

  source = mk-opt (types.enum [ "nixpkgs" "homebrew" "mac-app-store" ]) "homebrew"
    "Installation source";

  autoStart = mk-opt types.bool false
    "Start application automatically";

  configuration = mk-opt types.attrs { }
    "Application-specific configuration";
};
```

### 3. Service Management Modules

**Purpose**: Configure system services and daemons **Location**: `services/`

Uses launchd for service management:

```nix
# Example: Development service
options.rebellion.macos.services.development.postgresql = {
  enable = mk-opt types.bool false "Enable PostgreSQL service";

  version = mk-opt types.str "15"
    "PostgreSQL version";

  dataDir = mk-opt types.str "/opt/homebrew/var/postgres"
    "Data directory";

  port = mk-opt types.int 5432
    "PostgreSQL port";

  autoStart = mk-opt types.bool true
    "Start PostgreSQL automatically";
};

config = mkIf cfg.enable {
  homebrew = {
    brews = [ "postgresql@${cfg.version}" ];
    services = lib.mkIf cfg.autoStart [ "postgresql@${cfg.version}" ];
  };

  launchd.user.agents.postgresql = lib.mkIf cfg.autoStart {
    script = ''
      ${pkgs.homebrew}/bin/brew services start postgresql@${cfg.version}
    '';
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
    };
  };
};
```

### 4. Security and Privacy Modules

**Purpose**: Configure macOS security features **Location**: `security/`

```nix
# Example: FileVault encryption
options.rebellion.macos.security.encryption.filevault = {
  enable = mk-opt types.bool false "Enable FileVault disk encryption";

  deferSetupUntilLogout = mk-opt types.bool true
    "Defer FileVault setup until logout";

  requirePasswordOnWake = mk-opt types.bool true
    "Require password when waking from sleep";
};

config = mkIf cfg.enable {
  system.defaults.alf = {
    globalstate = 1; # Enable firewall
    allowsignedenabled = 1; # Allow signed apps
    allowdownloadsignedenabled = 1; # Allow downloaded signed apps
  };

  system.defaults.screensaver = {
    askForPassword = cfg.requirePasswordOnWake;
    askForPasswordDelay = 0; # Require immediately
  };

  # FileVault activation script
  system.activationScripts.filevault.text = ''
    if ! fdesetup isactive; then
      echo "FileVault is not enabled. Enable it in System Preferences > Security & Privacy > FileVault"
    fi
  '';
};
```

## Development Workflows

### Creating New macOS Modules

1. **Identify the module category**:
   - System preference → `system/{area}/`
   - Application → `applications/{category}/`
   - Service → `services/{category}/`
   - Security feature → `security/{area}/`

2. **Create module file**:

   ```bash
   touch modules/macos/system/menubar.nix
   ```

3. **Follow the macOS module template**:

   ```nix
   { lib, config, ... }:
   let
     inherit (lib) mkIf;
     inherit (lib.rebellion) mk-opt enabled;

     cfg = config.rebellion.macos.system.menubar;
   in
   {
     options.rebellion.macos.system.menubar = {
       enable = mk-opt lib.types.bool false "Enable menu bar configuration";
       # Add specific options
     };

     config = mkIf cfg.enable {
       system.defaults.com.apple.menuextra = {
         # Menu bar configuration
       };

       # Activation scripts if needed
       system.activationScripts.menubar.text = ''
         # Apply menu bar changes
         killall SystemUIServer || true
       '';
     };
   }
   ```

4. **Test the module**:

   ```bash
   # Enable in system config
   rebellion.macos.system.menubar = enabled;

   # Build and apply
   nix build .#darwinConfigurations.hostname.system
   ./result/sw/bin/darwin-rebuild switch --flake .#hostname
   ```

### Integration with Home Manager

macOS system modules often coordinate with home-manager for user-level settings:

```nix
# System module sets up system-wide defaults
config = mkIf cfg.enable {
  system.defaults.dock = {
    autohide = true;
    show-recents = false;
  };

  # Also configure user-level settings
  rebellion.home.macos.dock = {
    enable = true;
    applications = cfg.applications;
  };
};
```

### Multi-User Configuration

Handle different user preferences on shared systems:

```nix
# System-wide defaults
system.defaults.NSGlobalDomain = {
  AppleShowAllExtensions = true;
  ApplePressAndHoldEnabled = false;
};

# User-specific overrides via home-manager
users.users = lib.mapAttrs (username: userConfig: {
  rebellion.home.macos = userConfig.macosPreferences or { };
}) config.rebellion.users;
```

## Testing & Debugging

### Testing macOS Modules

```bash
# Build darwin configuration
nix build .#darwinConfigurations.hostname.system

# Test configuration changes
darwin-rebuild check --flake .#hostname

# Apply changes
darwin-rebuild switch --flake .#hostname

# Rollback if needed
darwin-rebuild --rollback
```

### Debugging System Preferences

```bash
# Check current defaults
defaults read com.apple.dock
defaults read NSGlobalDomain

# Monitor defaults changes
log stream --predicate 'category == "defaults"' --info

# Reset specific preferences
defaults delete com.apple.dock
killall Dock
```

### Homebrew Debugging

```bash
# Check Homebrew status
brew doctor

# List installed packages
brew list --formula
brew list --cask

# Check service status
brew services list
brew services info service-name

# Reinstall problematic packages
brew uninstall package-name
brew install package-name
```

### Application Issues

```bash
# Check application signatures
spctl -a -vv /Applications/App.app

# Reset application preferences
defaults delete com.company.app

# Clear application cache
rm -rf ~/Library/Caches/com.company.app

# Check launch services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump
```

## Security Considerations

### 1. Application Security

```nix
# Configure Gatekeeper
system.defaults.alf = {
  globalstate = 1; # Enable firewall
  allowsignedenabled = 1; # Allow signed apps only
  allowdownloadsignedenabled = 1; # Allow downloaded signed apps
};

# System Integrity Protection
system.defaults.SoftwareUpdate = {
  AutomaticallyInstallMacOSUpdates = true;
  CriticalUpdateInstall = true;
};
```

### 2. Privacy Settings

```nix
# Location services
system.defaults."com.apple.locationmenu" = {
  LocationServicesEnabled = false;
};

# Analytics and diagnostics
system.defaults."com.apple.SubmitDiagInfo" = {
  AutoSubmit = false;
};
```

### 3. Network Security

```nix
# DNS over HTTPS
networking.dns = {
  enable = true;
  servers = [ "1.1.1.1" "1.0.0.1" ];
  options = [ "edns0" ];
};

# VPN configuration
services.tailscale = {
  enable = true;
  package = pkgs.tailscale;
};
```

## Performance Optimization

### 1. System Performance

```nix
# Reduce animations
system.defaults.NSGlobalDomain = {
  NSAutomaticWindowAnimationsEnabled = false;
  NSDocumentSaveNewDocumentsToCloud = false;
};

# Disable unnecessary services
launchd.daemons = {
  "com.apple.metadata.spotlight" = {
    disabled = true; # Disable Spotlight indexing if not needed
  };
};
```

### 2. Memory Management

```nix
# Configure swap and memory pressure
system.defaults.NSGlobalDomain = {
  NSQuitAlwaysKeepsWindows = false; # Don't restore windows
};

# Purge inactive memory regularly
launchd.user.agents.purge-memory = {
  script = ''
    ${pkgs.coreutils}/bin/sudo purge
  '';
  serviceConfig = {
    StartInterval = 3600; # Every hour
  };
};
```

## Integration Patterns

### 1. Development Environment Setup

```nix
# Complete development suite
rebellion.macos = {
  applications.development = {
    vscode = enabled;
    xcode = enabled;
    docker = enabled;
  };

  homebrew.development = {
    enable = true;
    formulae = [ "git" "gh" "node" "python" "rust" ];
    casks = [ "postman" "tableplus" "proxyman" ];
  };

  system = {
    dock.applications = [
      "Visual Studio Code"
      "Xcode"
      "Docker Desktop"
      "Terminal"
    ];
  };
};
```

### 2. Creative Workflow Setup

```nix
# Creative professional configuration
rebellion.macos = {
  applications.creative = {
    adobe-creative-cloud = enabled;
    sketch = enabled;
    figma = enabled;
  };

  system = {
    trackpad = {
      scaling = 2.0; # Higher precision for design work
      forceClick = true;
    };

    display = {
      colorProfile = "P3";
      nightShift = disabled; # Disable for color-critical work
    };
  };
};
```

### 3. Server/Headless Configuration

```nix
# Minimal server configuration
rebellion.macos = {
  system = {
    dock.autohide = true;
    finder.showDesktop = false;
    menubar.minimal = true;
  };

  services = {
    ssh = enabled;
    remote-management = enabled;
  };

  security = {
    firewall = enabled;
    filevault = enabled;
  };
};
```

## Best Practices

### 1. Module Design

- **Use nix-darwin patterns**: Leverage system.defaults for preferences
- **Coordinate with home-manager**: Share configuration between system and user
  levels
- **Provide activation scripts**: Some changes need immediate application
- **Handle rollbacks gracefully**: Ensure configuration changes are reversible

### 2. Package Management

- **Prefer Homebrew for macOS apps**: Better integration and updates
- **Use Nix for CLI tools**: Better reproducibility and pinning
- **Document installation sources**: Make it clear where packages come from
- **Handle conflicts**: Ensure same packages aren't installed via multiple
  sources

### 3. User Experience

- **Provide reasonable defaults**: Don't break expected macOS behavior
- **Make changes discoverable**: Document what settings are changed
- **Consider different user types**: Developers vs. regular users
- **Test on multiple macOS versions**: Ensure compatibility

### 4. Security

- **Enable security features by default**: FileVault, firewall, etc.
- **Follow principle of least privilege**: Don't over-permissive
- **Keep software updated**: Regular security updates
- **Audit third-party software**: Be selective about what's installed

## Common Gotchas

1. **System Defaults Timing**: Some preferences require logout/restart to take
   effect
2. **Homebrew Permissions**: Homebrew directory permissions can cause issues
3. **Code Signing**: Some applications may need re-signing after Nix
   installation
4. **System Integrity Protection**: SIP can prevent certain system modifications
5. **Version Compatibility**: macOS defaults may change between OS versions
6. **Application Conflicts**: Multiple versions of same app can cause issues
7. **Service Dependencies**: Some services depend on others being started first
8. **Path Conflicts**: Multiple package managers can cause PATH conflicts

## Platform-Specific Considerations

### macOS Version Differences

```nix
# Handle macOS version-specific features
config = lib.mkMerge [
  # Common configuration
  {
    rebellion.macos.system.dock = enabled;
  }

  # macOS 13+ features
  (lib.mkIf (lib.versionAtLeast config.system.stateVersion "13") {
    system.defaults.dock.persistent-others = [
      "/Applications"
      "/Documents"
    ];
  })

  # macOS 12 and older
  (lib.mkIf (lib.versionOlder config.system.stateVersion "13") {
    system.defaults.dock.persistent-others = [
      "${config.users.users.${config.user}.home}/Applications"
      "${config.users.users.${config.user}.home}/Documents"
    ];
  })
];
```

### Apple Silicon vs Intel

```nix
# Architecture-specific configuration
config = lib.mkMerge [
  # Common configuration
  {
    rebellion.macos.homebrew.enable = true;
  }

  # Apple Silicon specific
  (lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
    homebrew.brewPrefix = "/opt/homebrew";
    rebellion.macos.applications.rosetta = enabled;
  })

  # Intel specific
  (lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
    homebrew.brewPrefix = "/usr/local";
  })
];
```

## Reference Examples

See existing modules for implementation patterns:

- `system/dock.nix` - System preference configuration
- `applications/browsers/` - Application management
- `homebrew/development.nix` - Homebrew integration
- `security/filevault.nix` - Security feature configuration
- `services/tailscale.nix` - Service management

For integration examples, examine how macOS-specific suites compose multiple
modules and coordinate with home-manager configurations.
