{ __findFile, ... }:
{
  rbn.suite._.desktop = {
    includes = [
      <rbn/suite/common>
      <rbn/programs/security/onepassword>
    ];
  };
}
