{ mylib, ... }:
{
  # scanPaths 自动导入当前目录下所有 .nix 文件和子目录（含 networking/）
  imports = mylib.scanPaths ./.;
}
