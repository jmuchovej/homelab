## macOS helpers, exposed as `lib.rbn.macos`.
##
##   keycode         — virtual keycode for a key: `keycode " "` -> 49,
##                     `keycode "f11"` -> 103. Handy for apps that store
##                     shortcuts by keycode, e.g. Raycast's
##                     `raycastGlobalHotkey = "Command-${toString (keycode " ")}"`.
##   symbolic-hotkey — one entry for `com.apple.symbolichotkeys`
##                     `AppleSymbolicHotKeys`. Args: enabled, combo.
##                     `combo` is a `+`-joined string of modifiers followed by
##                     the key, e.g. "ctrl + shift + cmd + 3" or "cmd + ' '".
##                     Modifiers: `shift`, `ctrl`, `alt`, `cmd`, `fn`.
##
## A key is a single character or a lowercased name from the keycode table
## ("f11", "left arrow", "esc"). In a combo, wrap the key in single quotes to
## take it literally; that is how space and `+` are written: "cmd + ' '".
##
## The plist wants the key's ASCII code and its virtual keycode. The former comes
## from `charToInt` (65535 for non-printable keys); the latter is a physical-key
## number parsed at eval time from the `mac-keycodes` input, a pinned copy of
## https://gist.github.com/eegrok/949034 (lines like `0x31        Space`).
{ lib, inputs, ... }:
let
  inherit (lib)
    concatMap
    filter
    foldl'
    init
    last
    listToAttrs
    splitString
    stringLength
    toLower
    ;
  inherit (lib.strings) charToInt stringToCharacters trim;
  inherit (builtins) elemAt match readFile;

  # NSEventModifierFlags (AppKit NSEvent.h): 1 << 17 .. 1 << 23.
  masks = {
    shift = 131072;
    ctrl = 262144;
    alt = 524288;
    cmd = 1048576;
    fn = 8388608;
  };

  mask =
    combo: mods:
    foldl' (
      acc: m: acc + (masks.${m} or (throw "symbolic-hotkey: unknown modifier '${m}' in \"${combo}\""))
    ) 0 mods;

  hex-digit =
    c:
    let
      n = charToInt c;
    in
    if n >= 97 then n - 87 else n - 48;
  from-hex = s: foldl' (acc: c: acc * 16 + hex-digit c) 0 (stringToCharacters (toLower s));

  # "0x14        3" -> { name = "3"; value = 20; }; anything else -> [ ]
  parse-line =
    line:
    let
      m = match "0x([0-9A-Fa-f]+)[[:space:]]+([^[:space:]].*[^[:space:]]|[^[:space:]])[[:space:]]*" line;
    in
    if m == null then
      [ ]
    else
      [
        {
          name = if toLower (elemAt m 1) == "space" then " " else toLower (elemAt m 1);
          value = from-hex (elemAt m 0);
        }
      ];

  keycodes = listToAttrs (
    concatMap parse-line (splitString "\n" (readFile inputs.mac-keycodes.outPath))
  );

  # "ctrl + shift + cmd + 3" -> { mods = [ "ctrl" "shift" "cmd" ]; key = "3"; }
  # "cmd + '+'"              -> { mods = [ "cmd" ];                key = "+"; }
  parse-combo =
    combo:
    let
      quoted = match "(.*)'(.+)'[[:space:]]*" combo;
      head = if quoted == null then combo else elemAt quoted 0;
      parts = filter (p: p != "") (map trim (splitString "+" head));
    in
    assert parts != [ ] || throw "symbolic-hotkey: empty combo";
    if quoted == null then
      {
        mods = init parts;
        key = last parts;
      }
    else
      {
        mods = parts;
        key = elemAt quoted 1;
      };

  known = key: keycodes ? ${toLower key} || throw "symbolic-hotkey: unsupported key \"${key}\"";
  keycode =
    key:
    assert known key;
    keycodes.${toLower key};
  ascii =
    key:
    assert known key;
    if stringLength key == 1 then charToInt key else 65535;
in
{
  _rbn-lib.macos = {
    inherit keycode;

    symbolic-hotkey =
      enabled: combo:
      let
        inherit (parse-combo combo) mods key;
      in
      {
        inherit enabled;
        value = {
          parameters = [
            (ascii key)
            (keycode key)
            (mask combo mods)
          ];
          type = "standard";
        };
      };
  };
}
