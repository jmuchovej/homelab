{
  config.programs.zellij.settings.keybinds =
    let
      # KDL helpers
      mk-keybind = args: children: {
        bind = {
          _args = args;
          _children = children;
        };
      };

      mk-mode = children: {
        _props.clear-defaults = true;
        _children = children;
      };

      # Single-arg KDL value — fallback for one-offs like `arg "Increase Left"`
      arg = v: { _args = [ v ]; };

      # Directions (values for MoveFocus, MovePane, NewPane, etc.)
      inherit
        (
          let
            a = v: {
              name = v;
              value = arg v;
            };
          in
          builtins.listToAttrs (
            map a [
              "Left"
              "Right"
              "Up"
              "Down"
            ]
          )
        )
        Left
        Right
        Up
        Down
        ;

      # Modes (values for SwitchToMode)
      inherit
        (
          let
            a = v: {
              name = v;
              value = arg v;
            };
          in
          builtins.listToAttrs (
            map a [
              "Normal"
              "Locked"
              "Scroll"
              "Search"
              "Pane"
              "Resize"
              "Move"
              "Tab"
              "Session"
              "Tmux"
              "RenameTab"
              "RenamePane"
              "EnterSearch"
            ]
          )
        )
        Normal
        Locked
        Scroll
        Search
        Pane
        Resize
        Move
        Tab
        Session
        Tmux
        RenameTab
        RenamePane
        EnterSearch
        ;

      # vim-zellij-navigator integration
      vim-nav = "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm";

      mk-vim-nav =
        key: name: payload: mod-key: mod-value:
        mk-keybind
          [ key ]
          [
            {
              MessagePlugin = {
                _args = [ vim-nav ];
                _children = [
                  { name._args = [ name ]; }
                  { payload._args = [ payload ]; }
                  { ${mod-key}._args = [ mod-value ]; }
                ];
              };
            }
          ];

      # shared_except helper for mode-switch rebindings
      mk-shared-rebind = except: unbind-key: bind-key: to-mode: {
        shared_except = {
          _args = [
            except
            "locked"
          ];
          _children = [
            { unbind._args = [ unbind-key ]; }
            (mk-keybind [ bind-key ] [ { SwitchToMode = to-mode; } ])
          ];
        };
      };
    in
    {
      _children = [
        { unbind._args = [ "Ctrl q" ]; }

        # locked
        {
          locked = mk-mode [
            (mk-keybind [ "Alt u" ] [ { SwitchToMode = Normal; } ])
          ];
        }

        # resize
        {
          resize = mk-mode [
            (mk-keybind [ "Alt r" "Esc" "Ctrl {" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind [ "h" "Left" ] [ { Resize = arg "Increase Left"; } ])
            (mk-keybind [ "j" "Down" ] [ { Resize = arg "Increase Down"; } ])
            (mk-keybind [ "k" "Up" ] [ { Resize = arg "Increase Up"; } ])
            (mk-keybind [ "l" "Right" ] [ { Resize = arg "Increase Right"; } ])
            (mk-keybind [ "H" ] [ { Resize = arg "Decrease Left"; } ])
            (mk-keybind [ "J" ] [ { Resize = arg "Decrease Down"; } ])
            (mk-keybind [ "K" ] [ { Resize = arg "Decrease Up"; } ])
            (mk-keybind [ "L" ] [ { Resize = arg "Decrease Right"; } ])
            (mk-keybind [ "=" "+" ] [ { Resize = arg "Increase"; } ])
            (mk-keybind [ "-" ] [ { Resize = arg "Decrease"; } ])
          ];
        }

        # pane
        {
          pane = mk-mode [
            (mk-keybind [ "Alt p" "Esc" "Ctrl {" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind [ "h" "Left" ] [ { MoveFocus = Left; } ])
            (mk-keybind [ "l" "Right" ] [ { MoveFocus = Right; } ])
            (mk-keybind [ "j" "Down" ] [ { MoveFocus = Down; } ])
            (mk-keybind [ "k" "Up" ] [ { MoveFocus = Up; } ])
            (mk-keybind [ "p" ] [ { SwitchFocus = { }; } ])
            (mk-keybind [ "n" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind
              [ "-" ]
              [
                { NewPane = Down; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "|" ]
              [
                { NewPane = Right; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "x" ]
              [
                { CloseFocus = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "f" ]
              [
                { ToggleFocusFullscreen = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "z" ]
              [
                { TogglePaneFrames = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "w" ]
              [
                { ToggleFloatingPanes = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "e" ]
              [
                { TogglePaneEmbedOrFloating = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "c" ]
              [
                { SwitchToMode = RenamePane; }
                { PaneNameInput = arg 0; }
              ]
            )
          ];
        }

        # move
        {
          move = mk-mode [
            (mk-keybind [ "Alt m" "Esc" "Ctrl {" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind [ "n" "Tab" ] [ { MovePane = { }; } ])
            (mk-keybind [ "p" ] [ { MovePaneBackwards = { }; } ])
            (mk-keybind [ "h" "Left" ] [ { MovePane = Left; } ])
            (mk-keybind [ "j" "Down" ] [ { MovePane = Down; } ])
            (mk-keybind [ "k" "Up" ] [ { MovePane = Up; } ])
            (mk-keybind [ "l" "Right" ] [ { MovePane = Right; } ])
          ];
        }

        # tab
        {
          tab = mk-mode (
            [
              (mk-keybind [ "Alt t" "Esc" "Ctrl {" ] [ { SwitchToMode = Normal; } ])
              (mk-keybind
                [ "r" ]
                [
                  { SwitchToMode = RenameTab; }
                  { TabNameInput = arg 0; }
                ]
              )
              (mk-keybind [ "h" "Left" "Up" "k" ] [ { GoToPreviousTab = { }; } ])
              (mk-keybind [ "l" "Right" "Down" "j" ] [ { GoToNextTab = { }; } ])
              (mk-keybind
                [ "n" ]
                [
                  { NewTab = { }; }
                  { SwitchToMode = Normal; }
                ]
              )
              (mk-keybind
                [ "x" ]
                [
                  { CloseTab = { }; }
                  { SwitchToMode = Normal; }
                ]
              )
              (mk-keybind
                [ "s" ]
                [
                  { ToggleActiveSyncTab = { }; }
                  { SwitchToMode = Normal; }
                ]
              )
            ]
            ++ builtins.genList (
              i:
              mk-keybind
                [ (toString (i + 1)) ]
                [
                  { GoToTab = arg (i + 1); }
                  { SwitchToMode = Normal; }
                ]
            ) 9
            ++ [
              (mk-keybind [ "Tab" ] [ { ToggleTab = { }; } ])
            ]
          );
        }

        # scroll
        {
          scroll = mk-mode [
            (mk-keybind [ "Alt f" "Esc" "Ctrl {" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind
              [ "e" ]
              [
                { EditScrollback = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "s" ]
              [
                { SwitchToMode = EnterSearch; }
                { SearchInput = arg 0; }
              ]
            )
            (mk-keybind
              [ "Ctrl c" ]
              [
                { ScrollToBottom = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind [ "j" "Down" ] [ { ScrollDown = { }; } ])
            (mk-keybind [ "k" "Up" ] [ { ScrollUp = { }; } ])
            (mk-keybind [ "Ctrl f" "PageDown" "Right" "l" ] [ { PageScrollDown = { }; } ])
            (mk-keybind [ "Ctrl b" "PageUp" "Left" "h" ] [ { PageScrollUp = { }; } ])
            (mk-keybind [ "d" ] [ { HalfPageScrollDown = { }; } ])
            (mk-keybind [ "u" ] [ { HalfPageScrollUp = { }; } ])
          ];
        }

        # search
        {
          search = mk-mode [
            (mk-keybind [ "Alt f" "Esc" "Ctrl {" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind
              [ "Ctrl c" "Esc" "Ctrl {" ]
              [
                { ScrollToBottom = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind [ "j" "Down" ] [ { ScrollDown = { }; } ])
            (mk-keybind [ "k" "Up" ] [ { ScrollUp = { }; } ])
            (mk-keybind [ "Ctrl f" "PageDown" "Right" "l" ] [ { PageScrollDown = { }; } ])
            (mk-keybind [ "Ctrl b" "PageUp" "Left" "h" ] [ { PageScrollUp = { }; } ])
            (mk-keybind [ "d" ] [ { HalfPageScrollDown = { }; } ])
            (mk-keybind [ "u" ] [ { HalfPageScrollUp = { }; } ])
            (mk-keybind [ "n" ] [ { Search = arg "down"; } ])
            (mk-keybind [ "p" ] [ { Search = arg "up"; } ])
            (mk-keybind [ "c" ] [ { SearchToggleOption = arg "CaseSensitivity"; } ])
            (mk-keybind [ "w" ] [ { SearchToggleOption = arg "Wrap"; } ])
            (mk-keybind [ "o" ] [ { SearchToggleOption = arg "WholeWord"; } ])
          ];
        }

        # entersearch
        {
          entersearch = mk-mode [
            (mk-keybind [ "Ctrl c" "Esc" "Ctrl {" ] [ { SwitchToMode = Scroll; } ])
            (mk-keybind [ "Enter" ] [ { SwitchToMode = Search; } ])
          ];
        }

        # renametab
        {
          renametab = mk-mode [
            (mk-keybind [ "Ctrl c" "Enter" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind
              [ "Esc" "Ctrl {" ]
              [
                { UndoRenameTab = { }; }
                { SwitchToMode = Tab; }
              ]
            )
          ];
        }

        # renamepane
        {
          renamepane = mk-mode [
            (mk-keybind [ "Ctrl c" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind
              [ "Esc" "Ctrl {" ]
              [
                { UndoRenamePane = { }; }
                { SwitchToMode = Pane; }
              ]
            )
          ];
        }

        # session
        {
          session = mk-mode [
            (mk-keybind [ "Alt s" "Esc" "Ctrl {" ] [ { SwitchToMode = Normal; } ])
            (mk-keybind [ "Alt f" ] [ { SwitchToMode = Scroll; } ])
            (mk-keybind [ "d" ] [ { Detach = { }; } ])
            (mk-keybind
              [ "w" ]
              [
                {
                  LaunchOrFocusPlugin = {
                    _args = [ "zellij:session-manager" ];
                    _children = [
                      { floating._args = [ false ]; }
                      { move_to_focused_tab._args = [ true ]; }
                    ];
                  };
                }
                { SwitchToMode = Normal; }
              ]
            )
          ];
        }

        # tmux
        {
          tmux = mk-mode [
            (mk-keybind
              [ "Ctrl b" "Esc" "Ctrl {" ]
              [
                { Write = arg 2; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind [ "[" ] [ { SwitchToMode = Scroll; } ])
            (mk-keybind
              [ "\"" ]
              [
                { NewPane = Down; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "%" ]
              [
                { NewPane = Right; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "z" ]
              [
                { ToggleFocusFullscreen = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "c" ]
              [
                { NewTab = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind [ "," ] [ { SwitchToMode = RenameTab; } ])
            (mk-keybind
              [ "p" ]
              [
                { GoToPreviousTab = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "n" ]
              [
                { GoToNextTab = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "Left" ]
              [
                { MoveFocus = Left; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "Right" ]
              [
                { MoveFocus = Right; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "Down" ]
              [
                { MoveFocus = Down; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "Up" ]
              [
                { MoveFocus = Up; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "h" ]
              [
                { MoveFocus = Left; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "l" ]
              [
                { MoveFocus = Right; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "j" ]
              [
                { MoveFocus = Down; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "k" ]
              [
                { MoveFocus = Up; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind [ "o" ] [ { FocusNextPane = { }; } ])
            (mk-keybind [ "d" ] [ { Detach = { }; } ])
            (mk-keybind [ "Space" ] [ { NextSwapLayout = { }; } ])
            (mk-keybind
              [ "x" ]
              [
                { CloseFocus = { }; }
                { SwitchToMode = Normal; }
              ]
            )
            (mk-keybind
              [ "g" ]
              [
                {
                  LaunchOrFocusPlugin = {
                    _args = [
                      "https://github.com/laperlej/zellij-sessionizer/releases/download/v0.4.3/zellij-sessionizer.wasm"
                    ];
                    _children = [
                      { floating._args = [ true ]; }
                      { move_to_focused_tab._args = [ true ]; }
                      { cwd._args = [ "/" ]; }
                      {
                        root_dirs._args = [
                          "/home/haseeb/projects;/home/haseebmajid/projects;/home/haseebmajid/projects/personal;/home/haseebmajid;/home/haseeb"
                        ];
                      }
                    ];
                  };
                }
                { SwitchToMode = Locked; }
              ]
            )
          ];
        }

        # shared_except "locked"
        {
          shared_except = {
            _args = [ "locked" ];
            _children = [
              (mk-keybind [ "Alt u" ] [ { SwitchToMode = Locked; } ])
              (mk-keybind [ "Alt q" ] [ { Quit = { }; } ])

              # vim-zellij-navigator: focus
              (mk-vim-nav "Alt h" "move_focus_or_tab" "left" "move_mod" "alt")
              (mk-vim-nav "Alt j" "move_focus" "down" "move_mod" "alt")
              (mk-vim-nav "Alt k" "move_focus" "up" "move_mod" "alt")
              (mk-vim-nav "Alt l" "move_focus_or_tab" "right" "move_mod" "alt")

              (mk-keybind [ "Ctrl n" ] [ { GoToNextTab = { }; } ])
              (mk-keybind [ "Ctrl p" ] [ { GoToPreviousTab = { }; } ])

              # vim-zellij-navigator: resize
              (mk-vim-nav "Ctrl Alt h" "resize" "left" "resize_mod" "ctrl+alt")
              (mk-vim-nav "Ctrl Alt j" "resize" "down" "resize_mod" "ctrl+alt")
              (mk-vim-nav "Ctrl Alt k" "resize" "up" "resize_mod" "ctrl+alt")
              (mk-vim-nav "Ctrl Alt l" "resize" "right" "resize_mod" "ctrl+alt")

              (mk-keybind [ "Alt =" "Alt +" ] [ { Resize = arg "Increase"; } ])
              (mk-keybind [ "Alt -" ] [ { Resize = arg "Decrease"; } ])
              (mk-keybind [ "Alt [" ] [ { PreviousSwapLayout = { }; } ])
              (mk-keybind [ "Alt ]" ] [ { NextSwapLayout = { }; } ])
            ];
          };
        }

        # shared_except: unbind defaults + rebind to Alt keys
        {
          shared_except = {
            _args = [
              "normal"
              "locked"
            ];
            _children = [
              { unbind._args = [ "Ctrl g" ]; }
              (mk-keybind [ "Enter" "Esc" "Alt u" ] [ { SwitchToMode = Normal; } ])
            ];
          };
        }
        (mk-shared-rebind "pane" "Ctrl p" "Alt p" Pane)
        (mk-shared-rebind "resize" "Ctrl n" "Alt r" Resize)
        (mk-shared-rebind "scroll" "Ctrl s" "Alt f" Scroll)
        (mk-shared-rebind "session" "Ctrl o" "Alt s" Session)
        (mk-shared-rebind "tab" "Ctrl t" "Alt t" Tab)
        (mk-shared-rebind "move" "Ctrl h" "Alt m" Move)
        (mk-shared-rebind "tmux" "Ctrl b" "Alt b" Tmux)
      ];
    };
}
