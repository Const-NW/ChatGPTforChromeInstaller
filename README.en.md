# Install ChatGPT Chrome Extension When Chrome Web Store Is Unavailable

[Home](README.md) · [Русский](README.ru.md) · **English** · [简体中文](README.zh-CN.md)

## Cannot install the ChatGPT Chrome extension?

If Chrome Web Store is unavailable, the ChatGPT extension is not available in your region, or the Add to Chrome installation fails, this Windows PowerShell installer provides an alternative download path through Google update service. It prepares an unpacked copy of the official CRX with extension ID `hehggadaopoacecdllhhajmbjkdcmajg`, verifies the developer signature and keeps backups when updating. It is a community tool, not an OpenAI or Google product.

The method requires Google's package service to remain reachable. It does not guarantee a bypass of regional restrictions or access to ChatGPT itself.

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

The version shown is an example, not a requirement or a promise of the latest version. Existing destinations must have a manifest with the matching key. Otherwise, specify a destination that does not exist yet and migrate manually; a pre-created empty folder is also rejected. Disable the old copy while testing the new one; removing an extension may delete its local data. An existing store installation with the same ID must be handled manually in Chrome before loading this copy.

## Verification and recovery

Before replacement, the script checks CRX3 structure, signed ID, the ID derived from the developer public key and its cryptographic signature. This is not Chrome's complete Web Store verification policy. CRX2 is unsupported. HTTPS certificate checks remain enabled.

Every replaced installation is retained in a sibling `*.backup-<timestamp>-<suffix>` folder. Preparation failures preserve the old installation; failure of the final move triggers a restoration attempt. Backups are never automatically deleted.

To recover manually, disable the extension, move the failed folder aside, rename a backup to the exact original installation path, then reload and enable the extension. Backups contain extension files, not Chrome profile data.

## FAQ: ChatGPT Chrome extension won't install

### How do I install ChatGPT when Chrome Web Store is unavailable?
Run the PowerShell block above, then use Load unpacked. The store page is not needed, but Google's package service must be reachable. The direct command also needs `raw.githubusercontent.com`; if it is unavailable, use an already downloaded repository copy.

### What if the extension is not available in my country or region?
You can try the Google update service download. Restrictions may also affect the package, so success is not guaranteed. Installing it does not remove account restrictions or unlock ChatGPT access. The original store failure's cause is unconfirmed.

### Add to Chrome does not work. Will this fix it?
First update Chrome and use a regular desktop profile, not Incognito or Guest mode. This alternative download path may help if the store page is the problem. Administrator restrictions require your administrator's help. See [Google's installation troubleshooting](https://support.google.com/chrome_webstore/answer/1698338?hl=en).

### Is this the official ChatGPT extension or a third-party alternative?
Only Google's package for `hehggadaopoacecdllhhajmbjkdcmajg` is downloaded; its developer signature is verified before extraction. The installer itself is a community project and does not install similarly named extensions.

### Why does ChatGPT or Codex not detect my unpacked extension?
An extension ID mismatch is one possible cause. The public `manifest.key` preserves the original ID. The installer does not repair desktop setup or native messaging.

### How do I update without the Chrome Web Store page?
Rerun the command and click Reload in Chrome. Google's package service must remain reachable. Unpacked updates are manual.

### Why is pwsh not recognized?
Install PowerShell 7.2+ and open a new terminal. Windows PowerShell 5.1 cannot run the installer itself.

## Troubleshooting

- **Script blocked:** after reviewing it, run `Unblock-File .\Install-Update-ChatGPT-ChromeExtension.ps1` if it was marked as downloaded. Organization policy may still block execution.
- **Network/TLS/HTTP error:** check connectivity and Chrome version. The update service may also be unavailable; there is no mirror fallback.
- **Signature/ID failure:** stop; do not bypass verification.
- **Wrong ID:** verify that Chrome loaded the printed folder and that you reloaded the correct card.
- **Desktop still cannot detect it:** follow the application's own setup instructions. This helper does not repair native hosts.
- **Developer mode blocked:** contact your administrator; this does not bypass policy.
- **Folder locked:** close processes using it and retry. Keep the backups.

References: [manifest key](https://developer.chrome.com/docs/extensions/reference/manifest/key), [CRX3](https://chromium.googlesource.com/chromium/src/+/HEAD/components/crx_file/crx3.proto). Repository: [GPL-3.0](LICENSE); extension terms are separate.
