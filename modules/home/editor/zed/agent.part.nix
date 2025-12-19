{ lib, ... }:
{
  settings = lib.mkMerge [
    # Agent Panel
    # https://zed.dev/docs/visual-customization#agent-panel
    # https://zed.dev/docs/configuring-zed#agent
    { disable_ai = false; }
    {
      agent = {
        default_model = {
          provider = "zed.dev";
          model = "claude-opus-4-1-thinking";
        };
        dock = "right";
        button = true;
        default_height = 420;
        default_width = 420;
        enabled = true;
        default_profile = "ask";
        use_modifier_to_send = true;
        model_parameters = [ ];
      };
    }
    # Language Models
    # https://zed.dev/docs/configuring-zed#language-models
    {
      language_models = {
        anthropic = {
          api_url = "https://api.anthropic.com";
        };
        google = {
          api_url = "https://generativelanguage.googleapis.com";
        };
        ollama = {
          api_url = "http://localhost:11434";
        };
        openai = {
          api_url = "https://api.openai.com/v1";
        };
      };
    }
  ];
  keybinds = [
    # https://zed.dev/docs/ai/edit-prediction#keybinding-example-always-use-alt-tab
    {
      context = "Editor && edit_prediction";
      bindings.alt-tab = "editor::AcceptEditPrediction";
    }
    # Bind `tab` back to its original behavior.
    {
      context = "Editor";
      bindings.tab = "editor::Tab";
    }
    {
      context = "Editor && showing_completions";
      bindings.tab = "editor::ComposeCompletion";
    }
    {
      context = "(VimControl && !menu) || vim_mode == replace || vim_mode == waiting";
      bindings.tab = "vim::Tab";
    }
    {
      context = "vim_mode == literal";
      bindings.tab = [
        "vim::Literal"
        [
          "tab"
          "\u0009"
        ]
      ];
    }
  ];
}
