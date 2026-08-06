# ⚠️  这是独立于 flake 的最小化 Hyper-V 配置（约 30 行），用于快速测试。
#    正式使用请走 flake：nixos-rebuild --flake .#HAO_HYPERV
#    两者功能重叠但互不引用，避免混淆。

{ config, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  networking.hostName = "HAO_HYPERV";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.feng = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  services.openssh.enable = true;
  virtualisation.hypervGuest.enable = true;

  environment.systemPackages = with pkgs; [ git vim curl htop ];

  system.stateVersion = "26.05";
}
