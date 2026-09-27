# ChatGPT for Chrome — Installer & Updater

**[Русский](README.ru.md) · [English](README.en.md) · [简体中文](README.zh-CN.md)**

Download and update an unpacked copy of the official ChatGPT Chrome extension through Google's update service.

> Community project; not an OpenAI or Google product. No extension binaries are hosted here.

| | |
| --- | --- |
| Extension ID | `hehggadaopoacecdllhhajmbjkdcmajg` |
| Source | `https://clients2.google.com/service/update2/crx` |
| Requirements | Windows, Chrome, **PowerShell 7.2+ (`pwsh`)** |
| Scope | Prepare files, preserve ID, retain backups |
| Unchanged | CSP, JavaScript, native hosts, registry, Chrome policies |

## Run directly from PowerShell

Paste the following block into PowerShell. It downloads the latest installer from this repository, runs it with PowerShell 7.2+ and removes the temporary script. No manual download is needed. PowerShell 7.2+ must already be installed (`pwsh` available in PATH); the block can also be pasted into Windows PowerShell 5.1.

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

The command executes code from this repository's `main` branch. `ExecutionPolicy Bypass` applies only to the child process; it does not change the saved execution policy. To pass options, append `-Force` or `-InstallDir 'C:\Install\ChatGPT\hehggadaopoacecdllhhajmbjkdcmajg'` after `-File $installer`. Rerun the block to update, then click **Reload** in Chrome. On first install, follow the **Load unpacked** steps below.

## Install from a downloaded copy

Download this repository (**Code → Download ZIP**), extract it and run from its folder:

```powershell
pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1
```

First install: open `chrome://extensions`, enable **Developer mode**, click **Load unpacked**, and select the folder printed by the script. Confirm the ID above. To update, run the same command and click **Reload** on the extension card.

Default folder: `%LOCALAPPDATA%\ChatGPTforChromeInstaller\hehggadaopoacecdllhhajmbjkdcmajg`.

## Why this exists

The originating user reported an unavailable/non-installable Web Store version and an unpacked copy with a different ID. The cause of the store failure is unknown; this is not a claim of a global outage. An ID mismatch can affect integrations. Preserving the ID does not guarantee desktop detection or service access.

The helper verifies the CRX3 developer signature and expected ID before extracting files. Only the public `manifest.key` is added when missing. Registration in Chrome remains manual; updates are not automatic.

Read the localized guide for migration, options, backups and troubleshooting:

- [Русский](README.ru.md)
- [English](README.en.md)
- [简体中文](README.zh-CN.md)

References: [Chrome manifest key](https://developer.chrome.com/docs/extensions/reference/manifest/key), [Chromium CRX3 format](https://chromium.googlesource.com/chromium/src/+/HEAD/components/crx_file/crx3.proto).

The existing [GPL-3.0 license](LICENSE) applies to this repository. Downloaded extension files remain subject to their own license and terms.
