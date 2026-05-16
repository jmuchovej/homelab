_: {
  rbn.programs._.editors.provides.default-editor = command: {
    includes = [
      {
        homeManager.home.sessionVariables = {
          EDITOR = command;
          VISUAL = command;
          SUDO_EDITOR = command;
        };
      }
    ];
  };
}
