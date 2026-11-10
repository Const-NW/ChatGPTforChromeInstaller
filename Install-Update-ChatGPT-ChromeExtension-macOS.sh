#!/bin/zsh
# Downloads and prepares the official ChatGPT Chrome extension for Load unpacked on macOS.
#
# Uses only tools shipped with macOS: zsh, curl, openssl (LibreSSL), perl, unzip.
# Only manifest.key may be changed. The original CSP, scripts and native messaging
# configuration are untouched.
#
# Usage: zsh Install-Update-ChatGPT-ChromeExtension-macOS.sh [--install-dir DIR] [--chrome-version VER] [--force]

emulate -R zsh
setopt no_unset pipe_fail
umask 022

readonly EXTENSION_ID='hehggadaopoacecdllhhajmbjkdcmajg'
INSTALL_DIR="$HOME/Library/Application Support/ChatGPTforChromeInstaller/$EXTENSION_ID"
CHROME_VERSION=''
FORCE=0
STAGE=''
STAGE_PARENT=''

die() { print -ru2 -- "Error: $*"; exit 1 }

usage() {
    print -r -- "Usage: zsh Install-Update-ChatGPT-ChromeExtension-macOS.sh [--install-dir DIR] [--chrome-version VERSION] [--force]

  --install-dir DIR        Destination folder (default: $INSTALL_DIR)
  --chrome-version VERSION Chrome version from chrome://version, if Chrome is not found
  --force                  Restore official files when the same version is installed"
}

# CRX3 parsing and manifest helpers. Perl and its core modules ship with macOS.
# Parse bounded protobuf fields and extract the developer proof before verification.
readonly PERL_HELPER='
use strict; use warnings;
use Digest::SHA qw(sha256_hex);
use JSON::PP ();

sub id_of_hex { my $h = substr($_[0], 0, 32); $h =~ tr/0-9a-f/a-p/; return $h }
sub key_id { return id_of_hex(sha256_hex($_[0])) }
sub slurp { my ($f) = @_; open(my $fh, "<:raw", $f) or die "Cannot read $f\n"; local $/; my $d = <$fh>; close $fh; return defined $d ? $d : "" }
sub spew { my ($f, $d) = @_; open(my $fh, ">:raw", $f) or die "Cannot write $f\n"; print {$fh} $d or die "Write failed\n"; close $fh or die "Write failed\n" }

sub varint {
    my ($b, $p) = @_; my $v = 0;
    for (my $shift = 0; $shift < 64; $shift += 7) {
        die "Truncated protobuf\n" if $$p >= length $b;
        my $n = ord substr($b, $$p++, 1);
        die "Varint overflow\n" if $shift == 63 && $n > 1;
        $v |= ($n & 127) << $shift;
        return $v unless $n & 128;
    }
    die "Invalid varint\n";
}
sub slice {
    my ($b, $p, $n) = @_;
    die "Invalid CRX length\n" if $p < 0 || $n < 0 || $p > length($b) - $n;
    return substr($b, $p, $n);
}
sub fields {
    my ($b) = @_; my @f; my $p = 0;
    while ($p < length $b) {
        my $tag = varint($b, \$p); my $field = $tag >> 3;
        die "Invalid protobuf tag\n" if $field == 0 || $field > 0x7fffffff;
        my $wire = $tag & 7;
        if    ($wire == 0) { varint($b, \$p) }
        elsif ($wire == 1) { slice($b, $p, 8); $p += 8 }
        elsif ($wire == 5) { slice($b, $p, 4); $p += 4 }
        elsif ($wire == 2) {
            my $n = varint($b, \$p);
            die "Invalid CRX length\n" if $n > 0x7fffffff;
            push @f, [$field, slice($b, $p, $n)]; $p += $n;
        }
        else { die "Unsupported protobuf wire type\n" }
    }
    return @f;
}
sub one {
    my ($id, @f) = @_; my $r;
    for (@f) { next unless $_->[0] == $id; die "Duplicate protobuf field\n" if defined $r; $r = $_->[1] }
    die "Missing protobuf field\n" unless defined $r;
    return $r;
}

# crx CRX OUTDIR EXPECTED_ID: writes message.bin, payload.zip, key.der, sig.bin; prints rsa|ecdsa.
sub cmd_crx {
    my ($crx, $out, $expected) = @_;
    my $b = slurp($crx);
    die "Not a CRX package\n" if length($b) < 12 || substr($b, 0, 4) ne "Cr24";
    die "Only CRX3 is supported\n" if unpack("V", substr($b, 4, 4)) != 3;
    my $header_length = unpack("V", substr($b, 8, 4));
    die "CRX header too large\n" if $header_length > 1048576;
    my @header = fields(slice($b, 12, $header_length));
    my $signed = one(10000, @header);
    my $crx_id = one(1, fields($signed));
    die "Signed extension ID mismatch\n" if id_of_hex(unpack("H*", $crx_id)) ne $expected;
    my $payload = substr($b, 12 + $header_length);
    for my $proof (@header) {
        next unless $proof->[0] == 2 || $proof->[0] == 3;
        my @p = fields($proof->[1]);
        my $key = one(1, @p); my $sig = one(2, @p);
        next if key_id($key) ne $expected;
        spew("$out/message.bin", "CRX3 SignedData\0" . pack("V", length $signed) . $signed . $payload);
        spew("$out/payload.zip", $payload);
        spew("$out/key.der", $key);
        spew("$out/sig.bin", $sig);
        print $proof->[0] == 2 ? "rsa\n" : "ecdsa\n";
        return;
    }
    die "No developer proof matches the expected extension ID\n";
}

sub read_manifest {
    my ($raw) = @_; $raw =~ s/^\xEF\xBB\xBF//;
    my $m = JSON::PP->new->decode($raw);
    die "Invalid manifest object\n" unless ref $m eq "HASH";
    return $m;
}

# manifest FILE: prints version, manifest_version and key (empty when absent) on three lines.
sub cmd_manifest {
    my $m = read_manifest(slurp($_[0]));
    for my $k (qw(version manifest_version key)) {
        my $v = $m->{$k};
        $v = "" unless defined $v && !ref $v;
        die "Invalid manifest value: $k\n" if $v =~ /[\r\n]/;
        print "$v\n";
    }
}

# insert-key FILE KEY: inserts only key; preserves every original JSON value (including CSP) verbatim.
sub cmd_insert_key {
    my ($file, $key) = @_;
    die "Invalid key\n" unless $key =~ m{\A[A-Za-z0-9+/]+={0,2}\z};
    my $raw = slurp($file);
    my $start = index($raw, "{");
    die "Invalid manifest object\n" if $start < 0;
    substr($raw, $start + 1, 0) = "\n  \"key\": \"$key\",";
    read_manifest($raw);
    spew($file, $raw);
}

# key-id BASE64: prints the extension ID derived from a public key.
sub cmd_key_id {
    my ($b64) = @_;
    die "Invalid key\n" unless $b64 =~ m{\A[A-Za-z0-9+/]+={0,2}\z};
    require MIME::Base64;
    print key_id(MIME::Base64::decode_base64($b64)), "\n";
}

my $cmd = shift @ARGV // "";
if    ($cmd eq "crx")        { cmd_crx(@ARGV) }
elsif ($cmd eq "manifest")   { cmd_manifest(@ARGV) }
elsif ($cmd eq "insert-key") { cmd_insert_key(@ARGV) }
elsif ($cmd eq "key-id")     { cmd_key_id(@ARGV) }
else  { die "Unknown helper command\n" }
'

helper() { /usr/bin/perl -e "$PERL_HELPER" -- "$@" }

# Verifies the extracted developer proof with OpenSSL. Prints the base64 public key on success.
verify_and_write_zip() {
    local crx=$1 out=$2 expected=$3 type pem
    type=$(helper crx "$crx" "$out" "$expected") || return 1
    pem="$out/key.pem"
    {
        print -r -- '-----BEGIN PUBLIC KEY-----'
        /usr/bin/openssl base64 -in "$out/key.der" || return 1
        print -r -- '-----END PUBLIC KEY-----'
    } > "$pem" || return 1
    # The key must be a canonical SubjectPublicKeyInfo of the declared algorithm.
    /usr/bin/openssl pkey -pubin -in "$pem" -outform DER -out "$out/key.check.der" 2>/dev/null \
        && /usr/bin/cmp -s "$out/key.der" "$out/key.check.der" \
        || { print -ru2 -- 'Invalid developer public key'; return 1 }
    case $type in
        rsa)   /usr/bin/openssl rsa -pubin -in "$pem" -noout 2>/dev/null ;;
        ecdsa) /usr/bin/openssl ec -pubin -in "$pem" -noout 2>/dev/null ;;
        *)     false ;;
    esac || { print -ru2 -- 'Developer key type does not match its proof'; return 1 }
    /usr/bin/openssl dgst -sha256 -verify "$pem" -signature "$out/sig.bin" "$out/message.bin" >/dev/null 2>&1 \
        || { print -ru2 -- 'CRX developer signature is invalid'; return 1 }
    /usr/bin/openssl base64 -A -in "$out/key.der" || return 1
    print
}

# Chrome treats missing components as zero: 1.2 == 1.2.0 == 1.2.0.0. Prints a sortable form.
normalize_extension_version() {
    local value=$1 part nonzero=0
    local -a parts out
    [[ $value =~ '^(0|[1-9][0-9]{0,4})(\.(0|[1-9][0-9]{0,4})){0,3}$' ]] \
        || { print -ru2 -- "Invalid extension version: $value"; return 1 }
    parts=("${(@s:.:)value}")
    for part in $parts; do
        (( part > 65535 )) && { print -ru2 -- "Invalid extension version: $value"; return 1 }
        (( part != 0 )) && nonzero=1
        out+=("${(l:5::0:)part}")
    done
    (( nonzero )) || { print -ru2 -- "Invalid extension version: $value"; return 1 }
    while (( ${#out} < 4 )); do out+=('00000'); done
    print -r -- "${(j:.:)out}"
}

display_version() {
    local -a parts
    parts=("${(@s:.:)1}")
    print -r -- "$(( 10#${parts[1]} )).$(( 10#${parts[2]} )).$(( 10#${parts[3]} )).$(( 10#${parts[4]} ))"
}

# Rejects absolute paths, parent references and links before extracting anything.
extract_zip() {
    local zip=$1 dest=$2 entry
    local -a entries
    entries=("${(@f)$(/usr/bin/unzip -Z1 "$zip" 2>/dev/null)}") || { print -ru2 -- 'Invalid archive.'; return 1 }
    (( ${#entries} )) && [[ -n ${entries[1]} ]] || { print -ru2 -- 'Empty archive.'; return 1 }
    for entry in $entries; do
        if [[ $entry == /* || $entry == *\\* || "/$entry/" == */../* ]]; then
            print -ru2 -- "Unsafe archive entry: $entry"; return 1
        fi
    done
    if /usr/bin/unzip -Z "$zip" | /usr/bin/grep -q '^l'; then
        print -ru2 -- 'Archive contains symbolic links.'; return 1
    fi
    /usr/bin/unzip -q "$zip" -d "$dest" || return 1
    [[ -z $(/usr/bin/find "$dest" -type l -print -quit) ]] || { print -ru2 -- 'Archive contains symbolic links.'; return 1 }
}

get_chrome_version() {
    local app version
    for app in '/Applications/Google Chrome.app' "$HOME/Applications/Google Chrome.app"; do
        if [[ -f "$app/Contents/Info.plist" ]]; then
            version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist" 2>/dev/null) \
                && [[ -n $version ]] && { print -r -- "$version"; return 0 }
        fi
    done
    die 'Chrome was not found. Supply --chrome-version with the version shown at chrome://version.'
}

cleanup() {
    [[ -n $STAGE ]] || return 0
    # Delete only the unique staging directory created by this run, never the target/backup.
    if [[ ${STAGE:h} != "$STAGE_PARENT" || ${STAGE:t} != .chatgpt-stage-[0-9a-f](#c32) ]]; then
        print -ru2 -- 'Unexpected staging path; cleanup refused.'
        return 1
    fi
    [[ -d $STAGE && ! -L $STAGE ]] && /bin/rm -rf -- "$STAGE"
    STAGE=''
}

install_extension() {
    local target parent path_ lock_fd old_version='' old_key new_version_raw manifest_version manifest_key
    local crx zip unpacked key new_version old_norm='' backup=''
    local -a info

    [[ $OSTYPE == darwin* ]] || die 'This installer requires macOS.'
    local tool
    for tool in /usr/bin/curl /usr/bin/openssl /usr/bin/perl /usr/bin/unzip /usr/bin/plutil; do
        [[ -x $tool ]] || die "Required tool is missing: $tool"
    done
    zmodload zsh/system 2>/dev/null && zsystem supports flock || die 'This zsh build does not support file locking.'
    setopt extended_glob

    [[ -n $CHROME_VERSION ]] || CHROME_VERSION=$(get_chrome_version) || exit 1
    [[ $CHROME_VERSION =~ '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' ]] || die 'Invalid Chrome version.'

    [[ -n $INSTALL_DIR ]] || die 'InstallDir must not be empty.'
    target=${INSTALL_DIR:a}
    target=${target%%/#}
    [[ -n $target && $target != / ]] || die 'InstallDir must not be the filesystem root.'
    parent=${target:h}
    # Reject symlinks in the destination ancestry before moving anything.
    path_=$target
    while [[ $path_ != / ]]; do
        [[ -L $path_ ]] && die "Install path contains a symbolic link: $path_"
        path_=${path_:h}
    done
    /bin/mkdir -p -- "$parent" || die "Cannot create $parent"

    # A sibling lock serializes runs targeting the same folder.
    [[ -L "$target.lock" ]] && die "Lock file is a symbolic link: $target.lock"
    : >> "$target.lock" || die "Cannot create $target.lock"
    zsystem flock -t 0 -f lock_fd "$target.lock" 2>/dev/null \
        || die "Another installer run is using $target"

    STAGE_PARENT=$parent
    STAGE="$parent/.chatgpt-stage-$(/usr/bin/openssl rand -hex 16)" || die 'Cannot create staging name.'

    if [[ -e $target || -L $target ]]; then
        [[ -f "$target/manifest.json" ]] || die 'Refusing to replace a folder without manifest.json.'
        info=("${(@f)$(helper manifest "$target/manifest.json")}") || die 'Cannot read the existing manifest.'
        old_version=${info[1]-}
        old_key=${info[3]-}
        if [[ -z $old_key ]] || [[ "$(helper key-id "$old_key" 2>/dev/null)" != "$EXTENSION_ID" ]]; then
            die 'Existing folder has no matching key. Use an --install-dir that does not exist yet; migrate manually.'
        fi
        old_norm=$(normalize_extension_version "$old_version") || exit 1
    fi

    /bin/mkdir -m 700 -- "$STAGE" || die 'Cannot create the staging directory.'
    crx="$STAGE/extension.crx"
    zip="$STAGE/payload.zip"
    unpacked="$STAGE/unpacked"
    local query="id%3D${EXTENSION_ID}%26uc"
    local url="https://clients2.google.com/service/update2/crx?response=redirect&prodversion=$CHROME_VERSION&acceptformat=crx3&x=$query"
    print -r -- "Downloading extension for Chrome $CHROME_VERSION..."
    /usr/bin/curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
        --max-redirs 10 --max-time 120 --output "$crx" -- "$url" || die 'Download failed.'

    key=$(verify_and_write_zip "$crx" "$STAGE" "$EXTENSION_ID") || die 'CRX verification failed.'

    extract_zip "$zip" "$unpacked" || die 'Cannot extract the extension archive.'

    local manifest_path="$unpacked/manifest.json"
    [[ -f $manifest_path ]] || die 'Unexpected manifest.'
    info=("${(@f)$(helper manifest "$manifest_path")}") || die 'Unexpected manifest.'
    new_version_raw=${info[1]-}
    manifest_version=${info[2]-}
    manifest_key=${info[3]-}
    [[ -n $new_version_raw && $manifest_version == 3 ]] || die 'Unexpected manifest.'
    new_version=$(normalize_extension_version "$new_version_raw") || exit 1
    if [[ -n $old_norm ]]; then
        [[ $new_version < $old_norm ]] && die 'Refusing to downgrade the installed extension.'
        if [[ $new_version == $old_norm && $FORCE != 1 ]]; then
            print -r -- "Already current: $(display_version "$new_version"). Use --force to restore official files at the same version."
            return 0
        fi
    fi
    if [[ -n $manifest_key ]]; then
        [[ $manifest_key == $key ]] || die 'Manifest key differs from the verified developer key.'
    else
        helper insert-key "$manifest_path" "$key" || die 'Cannot add key to manifest.'
    fi

    if [[ -n $old_norm ]]; then
        backup="$target.backup-$(/bin/date +%Y%m%d-%H%M%S)-$(/usr/bin/openssl rand -hex 4)"
        /bin/mv -- "$target" "$backup" || die 'Cannot move the existing installation to a backup.'
    fi
    if ! /bin/mv -- "$unpacked" "$target"; then
        [[ -n $backup && ! -e $target ]] && /bin/mv -- "$backup" "$target"
        die 'Cannot move the prepared extension into place.'
    fi

    print -r -- "Prepared version: $(display_version "$new_version")"
    print -r -- "Extension ID: $EXTENSION_ID"
    print -r -- "Folder: $target"
    [[ -n $backup ]] && print -r -- "Backup retained: $backup"
    print -r -- 'Open chrome://extensions, enable Developer mode and Load unpacked (first install), or click Reload (update).'
    print -r -- 'In the folder dialog press Cmd+Shift+G and paste the folder path above.'
    print -rn -- "$target" | /usr/bin/pbcopy 2>/dev/null && print -r -- 'The folder path has been copied to the clipboard.'
    return 0
}

parse_args() {
    while (( $# )); do
        case $1 in
            --install-dir)    (( $# >= 2 )) || die "$1 requires a value"; INSTALL_DIR=$2; shift 2 ;;
            --install-dir=*)  INSTALL_DIR=${1#*=}; shift ;;
            --chrome-version) (( $# >= 2 )) || die "$1 requires a value"; CHROME_VERSION=$2; shift 2 ;;
            --chrome-version=*) CHROME_VERSION=${1#*=}; shift ;;
            --force)          FORCE=1; shift ;;
            -h|--help)        usage; exit 0 ;;
            *)                usage >&2; die "Unknown option: $1" ;;
        esac
    done
}

# Sourcing exposes helpers for offline verification without installing anything.
if [[ $ZSH_EVAL_CONTEXT != *:file ]]; then
    parse_args "$@"
    trap 'cleanup' EXIT
    trap 'cleanup; exit 130' INT TERM HUP
    install_extension
    exit $?
fi
