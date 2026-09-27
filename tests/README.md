# Verification

Run offline checks from the repository root with PowerShell 7.2+:

```powershell
pwsh -NoProfile -File .\tests\Test-Crx.ps1
```

The test generates a temporary RSA-signed CRX3 fixture. It checks signature and ID validation, exact payload preservation, rejection of corruption, truncated/oversized headers, HTML responses and CRX2, plus ZIP path traversal rejection. No Chrome profile or installed extension is modified.

For a live smoke test, run the installer with `-InstallDir` pointing to a dedicated test directory. Repeat normally (same-version skip), then with `-Force` (backup and replacement). Compare every extracted file with the downloaded archive: only insertion of `manifest.key` is permitted. Do not load the test directory in Chrome unless you intend to test browser registration.
