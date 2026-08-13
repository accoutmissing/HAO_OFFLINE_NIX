{ lib, ... }:
{
  # 扫描目录，返回除 default.nix 外的所有 .nix 文件与子目录（供 imports 用）
  scanPaths =
    path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs
          (
            name: _type:
            (_type == "directory")
            || (
              (name != "default.nix")
              && (lib.strings.hasSuffix ".nix" name)
            )
          )
          (builtins.readDir path)
      )
    );
}
