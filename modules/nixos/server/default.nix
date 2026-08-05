{ mylib, ... }:
{
  # scanPaths 自动导入本目录所有 .nix（含 hardening/easytier 等子目录）
  imports = mylib.scanPaths ./.;
}
