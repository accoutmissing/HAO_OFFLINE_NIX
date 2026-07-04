{ pkgs, ... }:
{
  # ── 字体 ────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = false;
    fontDir.enable = true;

    packages = with pkgs; [
      # 中文
      source-han-sans              # 思源黑体
      source-han-serif             # 思源宋体
      source-han-mono              # 思源等宽
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      lxgw-wenkai                 # 霞鹜文楷

      # 西文
      source-sans
      source-serif
      jetbrains-mono
      maple-mono.NF-CN            # 中英文 2:1 等宽

      # 图标与表情
      nerd-fonts.jetbrains-mono
      noto-fonts-emoji
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Source Han Serif SC" "Source Serif" ];
        sansSerif = [ "Source Han Sans SC" "Source Sans" ];
        monospace = [ "Maple Mono NF CN" "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
