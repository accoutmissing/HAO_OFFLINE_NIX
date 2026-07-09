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
  };

  # ── 输出 ────────────────────────────────────────────────────────────
  outputs =
    { self, nixpkgs, home-manager, disko, noctalia, treefmt-nix, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mylib = import ./lib { inherit lib; };
      myvars = import ./vars { } ;

      # 基础模块列表（所有主机共享）
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
      treefmtEval = treefmt-nix.lib.evalConfig pkgs ./treefmt.nix;
    in
    {
      # ── 系统配置 ──────────────────────────────────────────────────────
      nixosConfigurations = {
        HAO_OFFLINE = mkSystem "HAO_OFFLINE" [ ];
        HAO_DESKTOP = mkSystem "HAO_DESKTOP" [ ];
        HAO_HYPERV = mkSystem "HAO_HYPERV" [ ];
      };

      # ── 安装工具 ──────────────────────────────────────────────────────
      packages.${system}.disko = disko.packages.${system}.disko;

      # ── 格式化 ────────────────────────────────────────────────────────
      formatter.${system} = treefmtEval.config.build.formatter;

      # ── 开发环境 ──────────────────────────────────────────────────────
      devShells.${system}.default = pkgs.mkShell {
        name = "nixos-config";
        buildInputs = [
          treefmtEval.config.build.formatter
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
      "nix-community.cachix.org-1:4BzitgziQkMCO+4QhMhVA8Wp9T5IhzsaCqPCU3c1gQ8="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
}
