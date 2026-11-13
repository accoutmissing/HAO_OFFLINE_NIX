# omp（oh-my-pi）官方预编译二进制。
#
# 上游 flake 的 packages.omp 会在本地跑完整 Rust + bun 构建（约 1800 个依赖），
# 在笔记本上要数小时；这里改为直接使用官方 release 的预编译单文件，安装只需一次下载。
#
# 升级：改 version，再执行
#   nix-prefetch-url https://github.com/can1357/oh-my-pi/releases/download/v<版本>/omp-linux-x64
# 把新的 sha256 填到 hash（或先 nix build 看报错里的 hash）。
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, libgcc
, zlib
,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "omp";
  version = "18.20.0";

  src = fetchurl {
    # 名字必须与 release 里的文件名一致，便于本地用 nix-store --add-fixed 复用同路径
    name = "omp-linux-x64";
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-linux-x64";
    hash = "sha256-yGlL6MbmofReNjbdio6eqniHitYpqJAAtAPsXkVtP4k=";
  };

  dontUnpack = true;
  # 二进制尾部内嵌了 JS bundle，strip 会破坏它
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    libgcc
    zlib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/omp
    runHook postInstall
  '';

  meta = {
    description = "Coding agent with the IDE wired in（官方预编译二进制）";
    homepage = "https://omp.sh";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
