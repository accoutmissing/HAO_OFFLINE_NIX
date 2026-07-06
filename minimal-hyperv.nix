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

  system.stateVersion = "25.05";
}
