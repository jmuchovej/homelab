# theme/ — palette & theming

Current theme: catppuccin. `catppuccin/_colors.nix` is the single palette
source; app-specific artifacts (e.g. `catppuccin-macchiato.theme.css`) are
generated/kept beside it.

Conventions (carried from the pre-den tree — still the intent):

- The theme name/palette is defined **once** and referenced — never duplicate
  theme string literals or hex values inside program aspects.
- Preference order for theming an app: (1) the app/module's own theme options;
  (2) conditionals keyed on the shared theme name; (3) a global theming
  framework (Stylix-style) only as a last resort for apps with no native
  hooks.
- Fonts are not theming — they live in `system/fonts`.
