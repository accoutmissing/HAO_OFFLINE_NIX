{ ... }:
{
  # 启用 SSH（远程管理与部署用）
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
}
