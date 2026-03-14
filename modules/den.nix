{
  inputs,
  den,
  ...
}:
{
  imports = [ (inputs.den.namespace "rbn" true) ];
  _module.args.__findFile = den.lib.__findFile;
}
