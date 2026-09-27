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

## Quick start

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
