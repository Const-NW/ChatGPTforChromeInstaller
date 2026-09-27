#Requires -Version 7.2
<#
.SYNOPSIS
Downloads and prepares the official ChatGPT Chrome extension for Load unpacked.
.DESCRIPTION
Requires Windows and PowerShell 7.2+. Only manifest.key may be changed.
The original CSP, fonts, scripts and native messaging configuration are untouched.
#>
[CmdletBinding()]
param(
    [string] $InstallDir = (Join-Path $env:LOCALAPPDATA 'ChatGPTforChromeInstaller/hehggadaopoacecdllhhajmbjkdcmajg'),
    [string] $ChromeVersion,
    [switch] $Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$extensionId = 'hehggadaopoacecdllhhajmbjkdcmajg'

# Parse bounded protobuf fields and verify the developer proof before extraction.
if (-not ('ChatGptCrx' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
public static class ChatGptCrx {
    public static string Id(byte[] key) {
        var hash = SHA256.HashData(key);
        var s = new StringBuilder();
        for (int i=0; i<16; i++) { s.Append((char)('a'+(hash[i]>>4))); s.Append((char)('a'+(hash[i]&15))); }
        return s.ToString();
    }
    static ulong Varint(byte[] b, ref int p) {
        ulong v=0;
        for(int shift=0; shift<64; shift+=7) {
            if(p>=b.Length) throw new InvalidDataException("Truncated protobuf");
            byte n=b[p++];
            if(shift==63 && n>1) throw new InvalidDataException("Varint overflow");
            v|=(ulong)(n&127)<<shift;
            if((n&128)==0) return v;
        }
        throw new InvalidDataException("Invalid varint");
    }
    static byte[] Slice(byte[] b, int p, int n) {
        if(p<0 || n<0 || p>b.Length-n) throw new InvalidDataException("Invalid CRX length");
        var r=new byte[n]; Buffer.BlockCopy(b,p,r,0,n); return r;
    }
    static List<KeyValuePair<int,byte[]>> Fields(byte[] b) {
        var fields=new List<KeyValuePair<int,byte[]>>(); int p=0;
        while(p<b.Length) {
            ulong tag=Varint(b,ref p); int field=checked((int)(tag>>3));
            if(field==0) throw new InvalidDataException("Invalid protobuf tag");
            switch(tag&7) {
                case 0: Varint(b,ref p); break;
                case 1: Slice(b,p,8); p+=8; break;
                case 5: Slice(b,p,4); p+=4; break;
                case 2:
                    int n=checked((int)Varint(b,ref p));
                    fields.Add(new KeyValuePair<int,byte[]>(field,Slice(b,p,n))); p+=n; break;
                default: throw new InvalidDataException("Unsupported protobuf wire type");
            }
        }
        return fields;
    }
    static byte[] One(List<KeyValuePair<int,byte[]>> f,int id) {
        byte[] result=null;
        foreach(var x in f) if(x.Key==id) {
            if(result!=null) throw new InvalidDataException("Duplicate protobuf field"); result=x.Value;
        }
        if(result==null) throw new InvalidDataException("Missing protobuf field"); return result;
    }
    public static string VerifyAndWriteZip(string crx,string zip,string expected) {
        var b=File.ReadAllBytes(crx);
        if(b.Length<12 || Encoding.ASCII.GetString(b,0,4)!="Cr24") throw new InvalidDataException("Not a CRX package");
        if(BitConverter.ToUInt32(b,4)!=3) throw new InvalidDataException("Only CRX3 is supported");
        uint headerLength=BitConverter.ToUInt32(b,8);
        if(headerLength>1048576) throw new InvalidDataException("CRX header too large");
        int start=checked(12+(int)headerLength);
        var fields=Fields(Slice(b,12,(int)headerLength));
        var signed=One(fields,10000);
        var crxId=One(Fields(signed),1);
        var idText=new StringBuilder();
        foreach(byte v in crxId) { idText.Append((char)('a'+(v>>4))); idText.Append((char)('a'+(v&15))); }
        if(idText.ToString()!=expected) throw new InvalidDataException("Signed extension ID mismatch");
        byte[] payload=Slice(b,start,b.Length-start);
        using(var data=new MemoryStream()) {
            byte[] prefix=Encoding.ASCII.GetBytes("CRX3 SignedData\0");
            data.Write(prefix); data.Write(BitConverter.GetBytes(signed.Length)); data.Write(signed); data.Write(payload);
            byte[] message=data.ToArray();
            foreach(var proof in fields) {
                if(proof.Key!=2 && proof.Key!=3) continue;
                var p=Fields(proof.Value); var key=One(p,1); var signature=One(p,2);
                if(Id(key)!=expected) continue;
                bool valid;
                if(proof.Key==2) {
                    using(var rsa=RSA.Create()) {
                        rsa.ImportSubjectPublicKeyInfo(key,out int used);
                        valid=used==key.Length && rsa.VerifyData(message,signature,HashAlgorithmName.SHA256,RSASignaturePadding.Pkcs1);
                    }
                } else {
                    using(var ec=ECDsa.Create()) {
                        ec.ImportSubjectPublicKeyInfo(key,out int used);
                        valid=used==key.Length && ec.VerifyData(message,signature,HashAlgorithmName.SHA256,DSASignatureFormat.Rfc3279DerSequence);
                    }
                }
                if(!valid) throw new InvalidDataException("CRX developer signature is invalid");
                File.WriteAllBytes(zip,payload); return Convert.ToBase64String(key);
            }
        }
        throw new InvalidDataException("No developer proof matches the expected extension ID");
    }
}
'@
}

function Get-ChromeVersion {
    $candidates = @(
        "$env:ProgramFiles/Google/Chrome/Application/chrome.exe",
        "${env:ProgramFiles(x86)}/Google/Chrome/Application/chrome.exe",
        "$env:LOCALAPPDATA/Google/Chrome/Application/chrome.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Get-Item -LiteralPath $candidate).VersionInfo.ProductVersion
        }
    }
    throw 'Chrome was not found. Supply -ChromeVersion with the version shown at chrome://version.'
}

function Invoke-ExtensionInstall {
    if (-not $IsWindows) { throw 'This installer requires Windows.' }
    if (-not $ChromeVersion) { $ChromeVersion = Get-ChromeVersion }
    if ($ChromeVersion -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'Invalid Chrome version.' }
    $target = [IO.Path]::GetFullPath($InstallDir).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ($target -eq [IO.Path]::GetPathRoot($target).TrimEnd('\')) { throw 'InstallDir must not be a drive root.' }
    $parent = Split-Path -Parent $target
    # Reject junctions/symlinks in the destination ancestry before moving anything.
    for ($path = $target; $path; $path = Split-Path -Parent $path) {
        if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Install path contains a reparse point: $path"
        }
    }
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    # A sibling lock serializes runs targeting the same folder.
    $lock = [IO.File]::Open("$target.lock", 'OpenOrCreate', 'ReadWrite', 'None')
    $stage = Join-Path $parent ('.chatgpt-stage-' + [guid]::NewGuid().ToString('N'))
    try {
        $old = $null
        if (Test-Path -LiteralPath $target) {
            $oldManifest = Join-Path $target 'manifest.json'
            if (-not (Test-Path -LiteralPath $oldManifest -PathType Leaf)) { throw 'Refusing to replace a folder without manifest.json.' }
            $old = Get-Content -LiteralPath $oldManifest -Raw | ConvertFrom-Json -AsHashtable
            if (-not $old.key -or [ChatGptCrx]::Id([Convert]::FromBase64String($old.key)) -ne $extensionId) {
                throw 'Existing folder has no matching key. Use a new empty InstallDir; migrate manually.'
            }
        }
        [IO.Directory]::CreateDirectory($stage) | Out-Null
        $crx = Join-Path $stage 'extension.crx'
        $zip = Join-Path $stage 'extension.zip'
        $unpacked = Join-Path $stage 'unpacked'
        $query = [uri]::EscapeDataString("id=$extensionId&uc")
        $url = "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=$ChromeVersion&acceptformat=crx3&x=$query"
        Write-Host "Downloading extension for Chrome $ChromeVersion..."
        Invoke-WebRequest -Uri $url -OutFile $crx -MaximumRedirection 10 -TimeoutSec 120
        $key = [ChatGptCrx]::VerifyAndWriteZip($crx, $zip, $extensionId)
        # .NET extraction rejects entries escaping the destination directory.
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unpacked)
        $manifestPath = Join-Path $unpacked 'manifest.json'
        $raw = [IO.File]::ReadAllText($manifestPath)
        $manifest = ConvertFrom-Json -InputObject $raw -AsHashtable
        if (-not $manifest.version -or $manifest.manifest_version -ne 3) { throw 'Unexpected manifest.' }
        $newVersion = [version]$manifest.version
        if ($old -and $newVersion -lt [version]$old.version) { throw 'Refusing to downgrade the installed extension.' }
        if ($old -and $newVersion -eq [version]$old.version -and -not $Force) {
            Write-Host "Already current: $newVersion. Use -Force to restore official files at the same version."
            return
        }
        if ($manifest.ContainsKey('key')) {
            if ($manifest.key -ne $key) { throw 'Manifest key differs from the verified developer key.' }
        } else {
            # Insert only key; preserve every original JSON value (including CSP) verbatim.
            $start = $raw.IndexOf('{')
            if ($start -lt 0) { throw 'Invalid manifest object.' }
            $raw = $raw.Insert($start + 1, "`n  `"key`": `"$key`",")
            [IO.File]::WriteAllText($manifestPath, $raw, [Text.UTF8Encoding]::new($false))
        }
        $backup = $null
        if ($old) {
            $backup = "$target.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            [IO.Directory]::Move($target, $backup)
        }
        try { [IO.Directory]::Move($unpacked, $target) }
        catch {
            if ($backup -and -not (Test-Path -LiteralPath $target)) { [IO.Directory]::Move($backup, $target) }
            throw
        }
        Write-Host "Prepared version: $newVersion`nExtension ID: $extensionId`nFolder: $target"
        if ($backup) { Write-Host "Backup retained: $backup" }
        Write-Host 'Open chrome://extensions, enable Developer mode and Load unpacked (first install), or click Reload (update).'
    }
    finally {
        # Delete only the unique staging directory created by this run, never the target/backup.
        if ((Split-Path -Parent $stage) -ne $parent -or (Split-Path -Leaf $stage) -notmatch '^\.chatgpt-stage-[0-9a-f]{32}$') {
            throw 'Unexpected staging path; cleanup refused.'
        }
        try { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force } }
        finally { $lock.Dispose() }
    }
}

# Dot-sourcing exposes helpers for offline verification without installing anything.
if ($MyInvocation.InvocationName -ne '.') { Invoke-ExtensionInstall }
