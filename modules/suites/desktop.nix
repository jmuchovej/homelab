{ __findFile, ... }:
{
  rbn.suite._.desktop = {
    includes = [
      <rbn/suite/common>
      <rbn/system/fonts>
      <rbn/programs/security/onepassword>
    ];
  };
}
