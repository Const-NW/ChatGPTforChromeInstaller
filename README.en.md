# ChatGPT Chrome extension installer

[Home](README.md) · [Русский](README.ru.md) · **English** · [简体中文](README.zh-CN.md)

## Purpose

This community helper downloads the official CRX from Google update service and prepares an unpacked installation with ID `hehggadaopoacecdllhhajmbjkdcmajg`. It is not an OpenAI or Google product.

The original user reported that the Web Store page was unavailable or installation failed, and an unpacked copy had a different ID. The store failure's cause is unconfirmed; availability can vary. ID mismatch may affect integrations. Preserving the ID does not guarantee desktop detection, sign-in or service access.

**CSP is not patched.** CSP is the browser policy limiting which resources an extension can load. The script leaves it unchanged and does not fix existing CSP errors. Only the public `manifest.key` is added if absent; JavaScript, native hosts, registry, profiles and browser policies are untouched.

## Requirements and installation

Windows, Google Chrome and [PowerShell 7.2+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) are required. Run `pwsh`, not Windows PowerShell 5.1 (`powershell`). You need network access to `clients2.google.com` and Google's download hosts, plus write access to the destination. The default location needs no administrator rights.

1. Download the repository (**Code → Download ZIP**), extract it and open a terminal in the extracted folder.
2. Run:

   ```powershell
   pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1
   ```

3. Open `chrome://extensions`, enable **Developer mode**, click **Load unpacked**, and choose the printed folder, not its parent:

   ```text
   %LOCALAPPDATA%\ChatGPTforChromeInstaller\hehggadaopoacecdllhhajmbjkdcmajg
   ```

4. Confirm ID `hehggadaopoacecdllhhajmbjkdcmajg`.

Keep this folder: Chrome reads files from it. Registration is manual. This is not a Web Store-managed installation.

## Run from PowerShell without a manual download

Paste the entire block into PowerShell. It downloads the latest installer from this repository, runs it with PowerShell 7.2+, and deletes the temporary script. PowerShell 7.2+ must already be installed with `pwsh` available in PATH. You can also paste this block into Windows PowerShell 5.1.

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

This executes code from the repository's `main` branch. `ExecutionPolicy Bypass` applies only to the child process and does not change the saved execution policy. Append `-Force` or `-InstallDir 'C:\Install\ChatGPT\hehggadaopoacecdllhhajmbjkdcmajg'` after `-File $installer` to pass options. Rerun the block to update, then click **Reload** in Chrome. For the first installation, complete the **Load unpacked** step above.

## Updates and options

Run the same command and click **Reload** on the extension card. Updates are manual; no scheduled task is created. Equal versions are skipped; downgrades are rejected even with `-Force`.

```powershell
# Restore official files at the same version; retain a backup
pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1 -Force

# Permanent custom path: use it for every update
pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1 -InstallDir 'C:\Install\ChatGPT\hehggadaopoacecdllhhajmbjkdcmajg'

# If Chrome detection fails: substitute your actual chrome://version value
pwsh -NoProfile -File .\Install-Update-ChatGPT-ChromeExtension.ps1 -ChromeVersion '153.0.8010.54'
```

The version shown is an example, not a requirement or a promise of the latest version. Existing destinations must have a manifest with the matching key. Otherwise, use a new folder and migrate manually. Disable the old copy while testing the new one; removing an extension may delete its local data. An existing store installation with the same ID must be handled manually in Chrome before loading this copy.

## Verification and recovery

Before replacement, the script checks CRX3 structure, signed ID, the ID derived from the developer public key and its cryptographic signature. This is not Chrome's complete Web Store verification policy. CRX2 is unsupported. HTTPS certificate checks remain enabled.

Every replaced installation is retained in a sibling `*.backup-<timestamp>-<suffix>` folder. Preparation failures preserve the old installation; failure of the final move triggers a restoration attempt. Backups are never automatically deleted.

To recover manually, disable the extension, move the failed folder aside, rename a backup to the exact original installation path, then reload and enable the extension. Backups contain extension files, not Chrome profile data.

## Troubleshooting

- **Script blocked:** after reviewing it, run `Unblock-File .\Install-Update-ChatGPT-ChromeExtension.ps1` if it was marked as downloaded. Organization policy may still block execution.
- **Network/TLS/HTTP error:** check connectivity and Chrome version. The update service may also be unavailable; there is no mirror fallback.
- **Signature/ID failure:** stop; do not bypass verification.
- **Wrong ID:** verify that Chrome loaded the printed folder and that you reloaded the correct card.
- **Desktop still cannot detect it:** follow the application's own setup instructions. This helper does not repair native hosts.
- **Developer mode blocked:** contact your administrator; this does not bypass policy.
- **Folder locked:** close processes using it and retry. Keep the backups.

References: [manifest key](https://developer.chrome.com/docs/extensions/reference/manifest/key), [CRX3](https://chromium.googlesource.com/chromium/src/+/HEAD/components/crx_file/crx3.proto). Repository: [GPL-3.0](LICENSE); extension terms are separate.
