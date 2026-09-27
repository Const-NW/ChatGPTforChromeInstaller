# ChatGPT Chrome 扩展安装与更新工具

[首页](README.md) · [Русский](README.ru.md) · [English](README.en.md) · **简体中文**

## 用途

本脚本通过 Google 更新服务下载官方 CRX 文件，并准备可通过“加载已解压的扩展程序”安装的文件，保持扩展 ID 为 `hehggadaopoacecdllhhajmbjkdcmajg`。这是社区项目，并非 OpenAI 或 Google 产品。

最初的用户报告称，Chrome 应用商店页面无法访问或无法安装，而解压后的副本获得了不同的 ID。商店故障的原因尚未确定；不同环境的可用性可能不同。ID 不一致可能影响集成。保持 ID 并不保证桌面应用能够识别扩展，也不保证登录或服务访问。

**不修改 CSP。** CSP 是浏览器用于限制扩展可加载资源的安全策略。本脚本保留原始策略，不修复 CSP 错误。仅在缺少时添加公开的 `manifest.key`；不修改 JavaScript、本地消息主机（浏览器与桌面应用之间的连接程序）、注册表、浏览器配置文件或策略。

## 环境要求与安装

需要 Windows、Google Chrome 和 [PowerShell 7.2 或更新版本](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)。请使用 `pwsh`，而不是 Windows PowerShell 5.1 的 `powershell`。还需要访问 `clients2.google.com` 及 Google 下载服务器，并具有目标文件夹的写入权限。默认路径不需要管理员权限。

1. 通过 **Code → Download ZIP** 下载仓库，解压后在该目录打开终端。
2. 运行：

   ```powershell
   pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1
   ```

3. 打开 `chrome://extensions`，启用**开发者模式**，点击**加载已解压的扩展程序**，选择脚本输出的文件夹，而不是其上一级目录：

   ```text
   %LOCALAPPDATA%\ChatGPTforChromeInstaller\hehggadaopoacecdllhhajmbjkdcmajg
   ```

4. 确认 ID 为 `hehggadaopoacecdllhhajmbjkdcmajg`。

请保留此文件夹，Chrome 会直接使用其中的文件。浏览器中的注册操作需要手动完成。这不是由应用商店管理的安装。

## 在 PowerShell 中直接运行，无需手动下载

将整个代码块粘贴到 PowerShell 中。它会从本仓库下载最新安装脚本，使用 PowerShell 7.2+ 运行，然后删除临时脚本。必须事先安装 PowerShell 7.2+，并确保 PATH 中可以找到 `pwsh`。此代码块也可粘贴到 Windows PowerShell 5.1 中。

```powershell
& {
    $pwsh = Get-Command pwsh -ErrorAction Stop
    $installer = Join-Path $env:TEMP ("ChatGPT-installer-" + [guid]::NewGuid() + ".ps1")
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/Const-NW/ChatGPTforChromeInstaller/main/Install-Update-ChatGPT-ChromeExtension.ps1' -OutFile $installer -ErrorAction Stop
        & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $installer
        if ($LASTEXITCODE -ne 0) { throw "Installer failed (exit code $LASTEXITCODE)." }
    }
    finally {
        if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
    }
}
```

此命令执行本仓库 `main` 分支中的代码。`ExecutionPolicy Bypass` 仅对启动的子进程有效，不修改已保存的执行策略。需要传递参数时，在 `-File $installer` 后添加 `-Force` 或 `-InstallDir 'C:\Install\ChatGPT\hehggadaopoacecdllhhajmbjkdcmajg'`。更新时再次运行代码块，然后在 Chrome 中点击**重新加载 / Reload**。首次安装仍需完成上文的**加载已解压的扩展程序**步骤。

## 更新与参数

再次运行同一命令，然后在扩展卡片上点击**重新加载 / Reload**。更新需要手动进行，脚本不会创建计划任务。相同版本默认跳过；即使指定 `-Force` 也不允许降级。

```powershell
# 同版本重新安装官方文件，并保留备份
pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1 -Force

# 自定义永久目录；以后更新时使用相同路径
pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1 -InstallDir 'C:\Install\ChatGPT\hehggadaopoacecdllhhajmbjkdcmajg'

# 无法自动检测 Chrome 时，填写 chrome://version 中的实际版本
pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1 -ChromeVersion '153.0.8010.54'
```

上述版本仅为示例，并非要求使用的版本，也不保证是最新版本。已有目标目录必须包含具有匹配公钥的清单，否则脚本会拒绝覆盖。迁移旧副本时，请选择新目录并手动处理。在测试新副本期间可停用旧副本；删除扩展可能导致其本地数据丢失。如果应用商店版本已使用同一 ID，请先在 Chrome 中手动处理现有安装。

## 验证与恢复

替换文件前，脚本会检查 CRX3 结构、已签名的 ID、公钥计算出的 ID，以及开发者的密码学签名。这不等于 Chrome 应用商店的完整验证策略。不支持 CRX2。HTTPS 证书验证保持启用。

每次替换都会在旁边保留 `*.backup-<时间戳>-<后缀>` 备份目录。准备阶段失败不会改变旧安装；最后移动失败时，脚本会尝试恢复旧目录。备份不会自动删除。

手动恢复时，先停用扩展，把有问题的目录移到其他位置，将所需备份改回原来的完整安装路径，然后重新加载并启用扩展。备份仅包含扩展文件，不包含 Chrome 用户配置数据。

## 常见问题

- **脚本被阻止：** 审阅代码后，如果文件带有下载标记，可运行 `Unblock-File .\Install-Update-ChatGPT-ChromeExtension.ps1`。组织策略仍可能禁止执行。
- **网络/TLS/HTTP 错误：** 检查网络及 Chrome 版本。更新服务本身也可能不可用；脚本不使用镜像站点。
- **签名或 ID 验证失败：** 停止操作，不要绕过验证。
- **Chrome 中 ID 不正确：** 确认选择了脚本输出的目录，并重新加载正确的扩展卡片。
- **桌面应用仍无法识别：** 检查应用自身的连接设置。脚本不会修复本地消息主机。
- **开发者模式被策略禁止：** 联系管理员；脚本不会绕过策略。
- **目录被占用：** 关闭使用该目录的进程后重试，并保留备份。

参考资料：[manifest key](https://developer.chrome.com/docs/extensions/reference/manifest/key)、[CRX3 格式](https://chromium.googlesource.com/chromium/src/+/HEAD/components/crx_file/crx3.proto)。仓库使用现有的 [GPL-3.0 许可证](LICENSE)；扩展本身适用独立的许可和条款。
