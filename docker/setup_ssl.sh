ROOT_CERTIFICATE="./volumes/ssl/root.crt"
ROOT_KEY="./volumes/ssl/root.key"
INTERMEDIATE_CERTIFICATE_REQUEST="./volumes/ssl/intermediate.csr"
INTERMEDIATE_CERTIFICATE="./volumes/ssl/intermediate.crt"
INTERMEDIATE_KEY="./volumes/ssl/intermediate.key"
CHAIN="./volumes/ssl/chain.crt"
PASS="./volumes/ssl/root.pass"

# Non-interactive (e.g. GitHub Actions):
#   SSL_ROOT_CRT / SSL_ROOT_KEY — PEM text, or base64 of the PEM
#   SSL_ROOT_KEY_PASS — passphrase written to root.pass
# Optional: SSL_CERT_ROOT_SUBJ / SSL_CERT_INTERMEDIATE_SUBJ when generating self-signed material.
SSL_CERT_ROOT_SUBJ="${SSL_CERT_ROOT_SUBJ:-/O=Self-signed/CN=docker-stack-root}"
SSL_CERT_INTERMEDIATE_SUBJ="${SSL_CERT_INTERMEDIATE_SUBJ:-/O=Self-signed/CN=docker-stack-intermediate}"

# Git Bash/MSYS rewrites args that look like absolute paths (e.g. /O=... → C:/Program Files/Git/O=...).
openssl_req() {
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' openssl req "$@"
}

mkdir -p "$(dirname "$PASS")"

# Decode PEM from env: accept raw PEM or base64-encoded PEM.
write_ssl_material() {
    local dest="$1"
    local value="$2"
    local label="$3"

    if [ -z "$value" ]; then
        return 1
    fi

    local trimmed
    trimmed="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if printf '%s' "$trimmed" | grep -q '^-----BEGIN '; then
        printf '%s\n' "$trimmed" > "$dest"
    else
        if ! printf '%s' "$trimmed" | base64 -d > "$dest" 2>/dev/null; then
            echo "Error: $label is neither PEM nor valid base64"
            return 1
        fi
        if ! grep -q 'BEGIN ' "$dest" 2>/dev/null; then
            echo "Error: $label decoded but does not look like a PEM file"
            return 1
        fi
    fi

    if command_exists dos2unix 2>/dev/null || command -v dos2unix >/dev/null 2>&1; then
        dos2unix "$dest" >/dev/null 2>&1 || true
    fi
    chmod 644 "$dest" 2>/dev/null || true
    # Keys stay private; certs are readable (Postgres needs this when run as non-root).
    if [[ "$dest" == *.key ]]; then
        chmod 600 "$dest" 2>/dev/null || true
    fi
    echo "Wrote $dest from environment ($label)"
    return 0
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if [ -n "${SSL_ROOT_KEY_PASS:-}" ]; then
    printf '%s\n' "$SSL_ROOT_KEY_PASS" > "$PASS"
    echo "Wrote $PASS from SSL_ROOT_KEY_PASS"
elif ! [ -e "$PASS" ]; then
    echo "Please enter the password for your SSL key:"
    read -s SSL_PASSWORD
    echo
    echo "$SSL_PASSWORD" > "$PASS"
fi

if [ -n "${SSL_ROOT_KEY:-}" ]; then
    write_ssl_material "$ROOT_KEY" "$SSL_ROOT_KEY" "SSL_ROOT_KEY" || exit 1
elif ! [ -e "$ROOT_KEY" ]; then
    openssl genrsa -out "$ROOT_KEY" 2048
    command_exists dos2unix && dos2unix "$ROOT_KEY"
fi

if [ -n "${SSL_ROOT_CRT:-}" ]; then
    write_ssl_material "$ROOT_CERTIFICATE" "$SSL_ROOT_CRT" "SSL_ROOT_CRT" || exit 1
elif ! [ -e "$ROOT_CERTIFICATE" ]; then
    openssl_req -x509 -new -key "$ROOT_KEY" -days 3650 -out "$ROOT_CERTIFICATE" -subj "$SSL_CERT_ROOT_SUBJ"
    command_exists dos2unix && dos2unix "$ROOT_CERTIFICATE"
fi

# Intermediate chain is only for local/dev when generating self-signed material.
# Skip when production PEM is supplied (encrypted keys would prompt for a passphrase).
if [ -z "${SSL_ROOT_CRT:-}" ] && [ -z "${SSL_ROOT_KEY:-}" ]; then
    if ! [ -e "$INTERMEDIATE_KEY" ]; then
        openssl genrsa -out "$INTERMEDIATE_KEY" 2048
        command_exists dos2unix && dos2unix "$INTERMEDIATE_KEY"
    fi

    if ! [ -e "$INTERMEDIATE_CERTIFICATE_REQUEST" ]; then
        echo "Create ssl key"
        openssl_req -new -key "$INTERMEDIATE_KEY" -out "$INTERMEDIATE_CERTIFICATE_REQUEST" -subj "$SSL_CERT_INTERMEDIATE_SUBJ"
        command_exists dos2unix && dos2unix "$INTERMEDIATE_CERTIFICATE_REQUEST"
    fi

    if ! [ -e "$INTERMEDIATE_CERTIFICATE" ]; then
        openssl x509 -req -in "$INTERMEDIATE_CERTIFICATE_REQUEST" -CA "$ROOT_CERTIFICATE" -CAkey "$ROOT_KEY" -CAcreateserial -days 1825 -out "$INTERMEDIATE_CERTIFICATE"
        command_exists dos2unix && dos2unix "$INTERMEDIATE_CERTIFICATE"
    fi

    if ! [ -e "$CHAIN" ]; then
        cp "$INTERMEDIATE_CERTIFICATE" "$CHAIN"
    fi
fi
