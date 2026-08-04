{ __findFile, ... }:
{
  rbn.suite._.desktop = {
    includes = [
      <rbn/system/fonts>
      <rbn/programs/security/onepassword>
      <rbn/programs/security/proton>
    ];
  };
}
