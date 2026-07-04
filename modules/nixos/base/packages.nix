{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # 系统工具
    git
    curl
    wget
    vim
    htop
    btop
    tree
    unzip
    zip
    ripgrep
    fd
    jq
    yq
    file
    pciutils
    usbutils

    # 网络诊断（dnsutils 已提供 dig/nslookup，无需 bind）
    iperf3
    mtr
    dnsutils
  ];

  programs = {
    git.enable = true;
    zsh.enable = true;
    mtr.enable = true;
  };
}
