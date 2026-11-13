{
  description = "Admin's HAO NixOS configuration";

  # ── 输入源 ──────────────────────────────────────────────────────────
  inputs = {
    # NixOS 官方源（滚动更新；与 Home Manager master 对齐）
    # 首次在 Nix 环境中务必生成并提交 flake.lock，避免上游变化直接破坏构建
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager（用户级包管理）
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 磁盘分区（安装用）
    disko = {
      url = "github:nix-community/disko/v1.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 桌面壳层
    noctalia = {
      url = "github:noctalia-dev/noctalia/legacy-v4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 格式化工具集
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS on Windows WSL（借鉴 nix-community/NixOS-WSL）
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ── 输出 ────────────────────────────────────────────────────────────
  outputs =
    { self, nixpkgs, home-manager, disko, treefmt-nix, nixos-wsl, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      # The EFI image builder uses pkgs.buildPackages.mtools. Nixpkgs
      # applies this overlay to buildPackages as well as the host package set.
      mtoolsSecurityOverlay = import ./lib/mtools-overlay.nix { inherit lib; };
      securityOverlay = _final: prev: (mtoolsSecurityOverlay _final prev) // {
        # edk2 的 GHSA-99cj-7hg9-mp4m / CVE-2026-97631 修复（上游 PR 13302）
        # 自 2026-10-30 的 nixpkgs 起已包含在 edk2 源里，再打补丁会命中
        # "Reversed (or previously applied) patch detected" 而构建失败，故移除。
        # 2026-10 之后的 nixpkgs 已带 Nix 2.34.9（含 GHSA-jwvx-xq5j-gc56 /
        # CVE-2026-110450 的修复），不再需要从源码重建 2.34.9；
        # 若未来锁进入受影响的 2.35.0–2.35.2 区间则 fail closed。
        nixVersions =
          let
            stableNixVersion = prev.nixVersions.stable.version;
          in
          if lib.versionAtLeast stableNixVersion "2.35.0"
            && lib.versionOlder stableNixVersion "2.35.3" then
            throw "Nix ${stableNixVersion} is in affected range 2.35.0–2.35.2 for GHSA-jwvx-xq5j-gc56 (CVE-2026-110450); use a fixed nixpkgs/Nix release."
          else
            prev.nixVersions;
      };
      securityPackageModule = { pkgs, ... }: {
        nixpkgs.overlays = [ securityOverlay ];
        nix.package = pkgs.nixVersions.stable;
      };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ securityOverlay ];
      };
      mylib = import ./lib { inherit lib; };
      myvars = import ./vars { };

      # 基础模块列表（所有主机共享）
      baseModules = [
        securityPackageModule
        ./modules/nixos/base
        ./modules/nixos/desktop
        disko.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { };
          };
        }
      ];

      # 快速生成 nixosSystem
      mkSystem = hostname: extraModules:
        let
          hostVars = myvars // { inherit hostname; };
          args = inputs // {
            inherit inputs mylib system;
            myvars = hostVars;
          };
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = args;
          modules = baseModules ++ [
            ./hosts/${hostname}
            {
              home-manager = {
                extraSpecialArgs = args;
                users.${myvars.username} = import ./home/linux;
              };
            }
          ] ++ extraModules;
        };

      # treefmt 配置
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      # HAO 品牌安装介质（全屏 TUI + Disko + Flake 安装）
      mkInstaller = offlineHost: lib.nixosSystem {
        inherit system;
        specialArgs = inputs // {
          inherit inputs self system offlineHost;
        };
        modules = [ securityPackageModule ./installer/iso.nix ];
      };
      haoInstaller = mkInstaller null;
      haoDesktopInstaller = mkInstaller "HAO_DESKTOP";
      haoLaptopInstaller = mkInstaller "HAO_OFFLINE";
    in
    {
      # ── 系统配置 ──────────────────────────────────────────────────────
      nixosConfigurations = {
        HAO_OFFLINE = mkSystem "HAO_OFFLINE" [ ];
        HAO_DESKTOP = mkSystem "HAO_DESKTOP" [ ];

        # 可启动安装 ISO；与桌面主机分离，不继承 base/desktop 模块。
        HAO_INSTALLER = haoInstaller;
        HAO_INSTALLER_OFFLINE_DESKTOP = haoDesktopInstaller;
        HAO_INSTALLER_OFFLINE_LAPTOP = haoLaptopInstaller;

        # Windows WSL 测试环境（无引导/无桌面，精简配置）
        # 仍然接 Home Manager：与桌面主机共用 home/linux（用户名、家目录都一致），
        # 让 WSL 里的 shell 体验（aliases / starship / bat / lazygit / gh / git 身份）
        # 与笔记本、台式机一致。HM 默认通过系统服务激活 home 配置；
        # hosts/HAO_WSL 另开 users.users.admin.linger，保证常驻用户服务
        # 在没有 admin 登录会话时也能启动。
        HAO_WSL = lib.nixosSystem {
          inherit system;
          specialArgs = inputs // {
            inherit inputs mylib system;
            myvars = myvars // { hostname = "HAO_WSL"; };
          };
          modules = [
            securityPackageModule
            nixos-wsl.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = inputs // {
                  inherit inputs mylib system;
                  myvars = myvars // { hostname = "HAO_WSL"; };
                };
                users.${myvars.username} = import ./home/linux;
              };
            }
            ./hosts/HAO_WSL
          ];
        };
      };

      # ── 安装工具 ──────────────────────────────────────────────────────
      packages.${system} = {
        disko = disko.packages.${system}.disko;
        hao-installer-iso = haoInstaller.config.system.build.isoImage;
        hao-installer-offline-desktop-iso = haoDesktopInstaller.config.system.build.isoImage;
        hao-installer-offline-laptop-iso = haoLaptopInstaller.config.system.build.isoImage;
      };

      # ── 格式化 ────────────────────────────────────────────────────────
      formatter.${system} = treefmtEval.config.build.wrapper;

      # ── 开发环境 ──────────────────────────────────────────────────────
      devShells.${system}.default = pkgs.mkShell {
        name = "nixos-config";
        buildInputs = [
          treefmtEval.config.build.wrapper
          pkgs.statix
          pkgs.deadnix
        ];
        shellHook = ''
          echo "🔧 NixOS 配置开发环境"
          echo "   nix fmt         格式化所有 .nix 文件"
          echo "   statix check .  检查无用代码"
          echo "   nix flake check 全量验证"
        '';
      };

      # ── CI 检查 ───────────────────────────────────────────────────────
      checks.${system} = {
        formatting = treefmtEval.config.build.check self;
        desktop-support = import ./tests/desktop-support.nix {
          inherit lib pkgs;
          laptopConfig = self.nixosConfigurations.HAO_OFFLINE.config;
          desktopConfig = self.nixosConfigurations.HAO_DESKTOP.config;
        };
        installer-failure-handling = pkgs.runCommand "installer-failure-handling"
          { nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.gnugrep ]; }
          ''
            bash ${./tests/installer-run-phase.sh} ${./installer/scripts/hao-installer.sh}
            touch "$out"
          '';
        installer-downloads = pkgs.runCommand "installer-downloads"
          { nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gawk ]; }
          ''
            bash ${./tests/installer-downloads.sh} ${./installer/scripts/hao-installer.sh}
            touch "$out"
          '';
        installer-vm = import ./tests/installer-vm.nix {
          inherit lib pkgs;
          disko = inputs.disko.packages.${system}.disko;
          installerConfig = haoInstaller.config;
        };
      };
    };

  # ── Nix 配置 ──────────────────────────────────────────────────────
  nixConfig = {
    extra-substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
}
