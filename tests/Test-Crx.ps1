#Requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../Install-Update-ChatGPT-ChromeExtension.ps1"

function Assert-Rejected([scriptblock] $Action, [string] $Name) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw "Expected rejection: $Name" }
    Write-Host "PASS: $Name"
}
function Varint([ulong] $Value) {
    $bytes = [Collections.Generic.List[byte]]::new()
    while ($Value -gt 127) { $bytes.Add([byte](($Value -band 127) -bor 128)); $Value = $Value -shr 7 }
    $bytes.Add([byte]$Value)
    return ,$bytes.ToArray()
}
function Field([int] $Number, [byte[]] $Data) {
    return ,[byte[]]((Varint ($Number * 8 + 2)) + (Varint $Data.Length) + $Data)
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('chatgpt-crx-test-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temp) | Out-Null
try {
    $rsa = [Security.Cryptography.RSA]::Create(2048)
    $key = $rsa.ExportSubjectPublicKeyInfo()
    $id = [ChatGptCrx]::Id($key)
    $hash = [Security.Cryptography.SHA256]::HashData($key)
    $signed = Field 1 ([byte[]]$hash[0..15])
    $payload = [Text.Encoding]::UTF8.GetBytes('test payload; verification does not parse ZIP')
    $message = [byte[]]([Text.Encoding]::ASCII.GetBytes("CRX3 SignedData`0") + [BitConverter]::GetBytes($signed.Length) + $signed + $payload)
    $signature = $rsa.SignData($message, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $proof = [byte[]]((Field 1 $key) + (Field 2 $signature))
    $header = [byte[]]((Field 2 $proof) + (Field 10000 $signed))
    $package = [byte[]]([Text.Encoding]::ASCII.GetBytes('Cr24') + [BitConverter]::GetBytes([uint32]3) + [BitConverter]::GetBytes($header.Length) + $header + $payload)
    $crx = Join-Path $temp 'test.crx'
    $zip = Join-Path $temp 'test.zip'
    [IO.File]::WriteAllBytes($crx, $package)
    $actualKey = [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, $id)
    if ($actualKey -ne [Convert]::ToBase64String($key)) { throw 'Wrong public key' }
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($zip)) -ne [Convert]::ToBase64String($payload)) { throw 'Payload changed' }
    Write-Host 'PASS: valid RSA signature, ID and exact payload'
    Assert-Rejected { [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, 'hehggadaopoacecdllhhajmbjkdcmajg') } 'wrong extension ID'
    $package[-1] = $package[-1] -bxor 1
    [IO.File]::WriteAllBytes($crx, $package)
    Assert-Rejected { [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, $id) } 'tampered payload'
    [IO.File]::WriteAllBytes($crx, [byte[]]$package[0..15])
    Assert-Rejected { [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, $id) } 'truncated header'
    [IO.File]::WriteAllText($crx, '<html>not a CRX</html>')
    Assert-Rejected { [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, $id) } 'HTML response'
    $package[4] = 2
    [IO.File]::WriteAllBytes($crx, $package)
    Assert-Rejected { [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, $id) } 'unsupported CRX2'
    $package[4] = 3
    [BitConverter]::GetBytes([uint32]1048577).CopyTo($package, 8)
    [IO.File]::WriteAllBytes($crx, $package)
    Assert-Rejected { [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, $id) } 'oversized header'
    # Ensure our chosen .NET extractor rejects ZIP traversal entries.
    $badZip = Join-Path $temp 'traversal.zip'
    $archive = [IO.Compression.ZipFile]::Open($badZip, 'Create')
    $entry = $archive.CreateEntry('../escaped.txt')
    $writer = [IO.StreamWriter]::new($entry.Open())
    $writer.Write('bad'); $writer.Dispose(); $archive.Dispose()
    Assert-Rejected { [IO.Compression.ZipFile]::ExtractToDirectory($badZip, (Join-Path $temp 'extract')) } 'ZIP traversal'
    if (Test-Path -LiteralPath (Join-Path $temp 'escaped.txt')) { throw 'ZIP escaped destination' }
} finally {
    if ($rsa) { $rsa.Dispose() }
    $resolved = [IO.Path]::GetFullPath($temp)
    if ((Split-Path -Parent $resolved) -eq [IO.Path]::GetTempPath().TrimEnd('\','/') -and (Split-Path -Leaf $resolved) -match '^chatgpt-crx-test-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
