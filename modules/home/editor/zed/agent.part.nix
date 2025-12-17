[
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

]
