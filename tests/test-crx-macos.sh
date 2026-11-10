#!/bin/zsh
# Offline checks for Install-Update-ChatGPT-ChromeExtension-macOS.sh. Nothing is downloaded or installed.
emulate -R zsh
setopt no_unset pipe_fail err_exit
source "${0:A:h}/../Install-Update-ChatGPT-ChromeExtension-macOS.sh"

fail() { print -ru2 -- "FAIL: $*"; exit 1 }
pass() { print -r -- "PASS: $*" }
assert_rejected() {
    local name=$1; shift
    local err
    if err=$( ( "$@" ) 2>&1 >/dev/null ); then fail "expected rejection: $name"; fi
    local -a lines=("${(@f)err}")
    pass "$name (${lines[-1]:-no message})"
}

# Builds a CRX3 package: build_crx PROOF_FIELD PRIVATE_KEY PAYLOAD_FILE OUT_CRX; prints the extension ID.
build_crx() {
    local field=$1 priv=$2 payload=$3 out=$4 dir=${4:h}
    /usr/bin/openssl pkey -in "$priv" -pubout -outform DER -out "$dir/pub.der"
    /usr/bin/perl -e '
        use strict; use Digest::SHA qw(sha256 sha256_hex);
        sub slurp { open(my $f, "<:raw", $_[0]) or die; local $/; <$f> }
        sub spew { open(my $f, ">:raw", $_[0]) or die; print {$f} $_[1]; close $f }
        sub varint { my $v = shift; my $r = ""; while ($v > 127) { $r .= chr(($v & 127) | 128); $v >>= 7 } $r . chr($v) }
        sub field { my ($n, $d) = @_; varint($n * 8 + 2) . varint(length $d) . $d }
        my ($dir, $payload_file) = @ARGV;
        my $key = slurp("$dir/pub.der"); my $payload = slurp($payload_file);
        my $signed = field(1, substr(sha256($key), 0, 16));
        spew("$dir/signed.bin", $signed);
        spew("$dir/message.unsigned", "CRX3 SignedData\0" . pack("V", length $signed) . $signed . $payload);
        my $id = substr(sha256_hex($key), 0, 32); $id =~ tr/0-9a-f/a-p/; print "$id\n";
    ' "$dir" "$payload"
    /usr/bin/openssl dgst -sha256 -sign "$priv" -out "$dir/sig.raw" "$dir/message.unsigned"
    /usr/bin/perl -e '
        use strict;
        sub slurp { open(my $f, "<:raw", $_[0]) or die; local $/; <$f> }
        sub varint { my $v = shift; my $r = ""; while ($v > 127) { $r .= chr(($v & 127) | 128); $v >>= 7 } $r . chr($v) }
        sub field { my ($n, $d) = @_; varint($n * 8 + 2) . varint(length $d) . $d }
        my ($dir, $proof_field, $payload_file, $out) = @ARGV;
        my $proof = field(1, slurp("$dir/pub.der")) . field(2, slurp("$dir/sig.raw"));
        my $header = field($proof_field, $proof) . field(10000, slurp("$dir/signed.bin"));
        open(my $f, ">:raw", $out) or die;
        print {$f} "Cr24" . pack("V", 3) . pack("V", length $header) . $header . slurp($payload_file);
        close $f;
    ' "$dir" "$field" "$payload" "$out"
}

# Overwrites bytes in a file: patch_file FILE OFFSET HEX (negative OFFSET counts from the end).
patch_file() {
    /usr/bin/perl -e '
        my ($file, $offset, $hex) = @ARGV;
        open(my $f, "<:raw", $file) or die; local $/; my $d = <$f>; close $f;
        $offset += length $d if $offset < 0;
        substr($d, $offset, length($hex) / 2) = pack("H*", $hex);
        open($f, ">:raw", $file) or die; print {$f} $d; close $f;
    ' "$@"
}

[[ $(normalize_extension_version 1.2) == $(normalize_extension_version 1.2.0) ]] || fail 'equivalent versions differ'
[[ $(normalize_extension_version 1) == $(normalize_extension_version 1.0.0.0) ]] || fail 'single component version'
[[ $(normalize_extension_version 1.2) > $(normalize_extension_version 1.1.9.9999) ]] || fail 'version ordering'
[[ $(normalize_extension_version 1.10) > $(normalize_extension_version 1.9) ]] || fail 'numeric version ordering'
[[ $(display_version "$(normalize_extension_version 1.26.1102.11740)") == 1.26.1102.11740 ]] || fail 'display version'
pass 'Chrome version equality and ordering'
for invalid in 0 0.0.0.0 01.2 1.65536 1.2.3.4.5 1.-1 1.beta ''; do
    assert_rejected "invalid version '$invalid'" normalize_extension_version "$invalid"
done

temp=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/chatgpt-crx-test.XXXXXXXX")
trap '[[ ${temp:t} == chatgpt-crx-test.* ]] && /bin/rm -rf -- "$temp"' EXIT

print -rn -- 'test payload; verification does not parse ZIP' > "$temp/payload"
for algo in rsa ecdsa; do
    work="$temp/$algo"; /bin/mkdir -p "$work/out"
    if [[ $algo == rsa ]]; then
        /usr/bin/openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$work/priv.pem" 2>/dev/null
        id=$(build_crx 2 "$work/priv.pem" "$temp/payload" "$work/test.crx")
    else
        /usr/bin/openssl ecparam -name prime256v1 -genkey -noout -out "$work/priv.pem"
        id=$(build_crx 3 "$work/priv.pem" "$temp/payload" "$work/test.crx")
    fi
    key=$(verify_and_write_zip "$work/test.crx" "$work/out" "$id")
    [[ $key == $(/usr/bin/openssl base64 -A -in "$work/pub.der") ]] || fail "$algo: wrong public key"
    /usr/bin/cmp -s "$work/out/payload.zip" "$temp/payload" || fail "$algo: payload changed"
    [[ $(helper key-id "$key") == $id ]] || fail "$algo: key-id"
    pass "$algo: valid signature, ID and exact payload"
    assert_rejected "$algo: wrong extension ID" verify_and_write_zip "$work/test.crx" "$work/out" "$EXTENSION_ID"

    /bin/cp "$work/test.crx" "$work/bad.crx"; patch_file "$work/bad.crx" -1 00
    assert_rejected "$algo: tampered payload" verify_and_write_zip "$work/bad.crx" "$work/out" "$id"
    /usr/bin/head -c 16 "$work/test.crx" > "$work/bad.crx"
    assert_rejected "$algo: truncated header" verify_and_write_zip "$work/bad.crx" "$work/out" "$id"
    print -r -- '<html>not a CRX</html>' > "$work/bad.crx"
    assert_rejected "$algo: HTML response" verify_and_write_zip "$work/bad.crx" "$work/out" "$id"
    /bin/cp "$work/test.crx" "$work/bad.crx"; patch_file "$work/bad.crx" 4 02
    assert_rejected "$algo: unsupported CRX2" verify_and_write_zip "$work/bad.crx" "$work/out" "$id"
    /bin/cp "$work/test.crx" "$work/bad.crx"; patch_file "$work/bad.crx" 8 01001000
    assert_rejected "$algo: oversized header" verify_and_write_zip "$work/bad.crx" "$work/out" "$id"
done

# Archive checks: traversal and symbolic links are rejected before anything escapes.
/bin/mkdir -p "$temp/extract"
/usr/bin/perl -MIO::Compress::Zip=zip -e 'zip(\"bad", "$ARGV[0]", Name => "../escaped.txt") or die' "$temp/traversal.zip"
assert_rejected 'ZIP traversal' extract_zip "$temp/traversal.zip" "$temp/extract/a"
[[ ! -e "$temp/extract/escaped.txt" ]] || fail 'ZIP escaped destination'
/bin/mkdir -p "$temp/linksrc" && /bin/ln -s /etc/passwd "$temp/linksrc/link"
( cd "$temp/linksrc" && /usr/bin/zip -qy "$temp/link.zip" link )
assert_rejected 'ZIP symbolic link' extract_zip "$temp/link.zip" "$temp/extract/b"
/usr/bin/perl -MIO::Compress::Zip=zip -e 'zip(\"{}", "$ARGV[0]", Name => "manifest.json") or die' "$temp/ok.zip"
extract_zip "$temp/ok.zip" "$temp/extract/c" && [[ -f "$temp/extract/c/manifest.json" ]] || fail 'valid ZIP'
pass 'valid ZIP extracts'

# Manifest: key is inserted without touching other values.
print -r -- '{ "manifest_version": 3, "version": "1.2", "content_security_policy": {"extension_pages": "script-src '\''self'\''"} }' > "$temp/manifest.json"
/bin/cp "$temp/manifest.json" "$temp/manifest.orig"
helper insert-key "$temp/manifest.json" 'QUJD'
info=("${(@f)$(helper manifest "$temp/manifest.json")}")
[[ ${info[1]} == 1.2 && ${info[2]} == 3 && ${info[3]} == QUJD ]] || fail 'manifest key insertion'
manifest=$(<"$temp/manifest.json")
[[ ${manifest/$'{\n  "key": "QUJD",'/\{} == "$(<"$temp/manifest.orig")" ]] || fail 'manifest content changed'
assert_rejected 'manifest key injection' helper insert-key "$temp/manifest.json" 'A",'
pass 'manifest key insertion preserves original values'
