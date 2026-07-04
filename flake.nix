{
  description = "Feng's NixOS configuration";

  # ── 输入源 ──────────────────────────────────────────────────────────
  inputs = {
    # NixOS 官方源
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager（用户级包管理）
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 磁盘分区（安装用）
    disko = {
      url = "github:nix-community/disko/v1.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 游戏优化
    nix-gaming = {
      url = "github:fufexan/nix-gaming/25efde5";  # 2026-03-17
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 桌面壳层（bar、dock、通知、锁屏、启动器）
    noctalia = {
      url = "github:noctalia-dev/noctalia/legacy-v4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ── 输出 ────────────────────────────────────────────────────────────
  outputs =
    { self, nixpkgs, home-manager, disko, nix-gaming, noctalia, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      mylib = import ./lib { inherit lib; };
      myvars = import ./vars { inherit lib; };

      # 基础模块列表（所有主机共享的 infrastructure）
      baseModules = [
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

      # 快速生成 nixosSystem，减少重复
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
    in
    {
      nixosConfigurations = {
        # 笔记本：Intel i7-8750H + GTX 1060 Optimus
        HAO_OFFLINE = mkSystem "HAO_OFFLINE" [ ];

        # 台式机：Intel i5-13600KF + RTX 4070 Super
        HAO_DESKTOP = mkSystem "HAO_DESKTOP" [ ];

        # Hyper-V 虚拟机测试（无 GPU，软件渲染）
        HAO_HYPERV = mkSystem "HAO_HYPERV" [ ];
      };
    };

  # ── Nix 配置（对 flake 命令生效，系统级见 base/nix.nix） ──────
  nixConfig = {
    extra-substituters = myvars.cachixSubstituters;
    extra-trusted-public-keys = myvars.cachixTrustedPublicKeys;
  };
}
