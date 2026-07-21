# Path to the password file
HTPASSWD_FILE="./volumes/nginx/.htpasswd"

# Non-interactive (CI): set from GitHub secrets, not .env:
#   NGINX_BASIC_AUTH_USER
#   NGINX_BASIC_AUTH_PASSWORD

mkdir -p "$(dirname "$HTPASSWD_FILE")"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create or overwrite .htpasswd with a single user (batch / non-interactive).
write_htpasswd() {
    local username="$1"
    local password="$2"

    if command_exists htpasswd; then
        htpasswd -cb "$HTPASSWD_FILE" "$username" "$password"
    else
        npx --yes htpasswd -cb "$HTPASSWD_FILE" "$username" "$password"
    fi

    if command_exists dos2unix; then
        dos2unix "$HTPASSWD_FILE" >/dev/null 2>&1 || true
    fi
    chmod 644 "$HTPASSWD_FILE" 2>/dev/null || true
    echo "Wrote $HTPASSWD_FILE for user $username"
}

if [ -n "${NGINX_BASIC_AUTH_USER:-}" ] && [ -n "${NGINX_BASIC_AUTH_PASSWORD:-}" ]; then
    write_htpasswd "$NGINX_BASIC_AUTH_USER" "$NGINX_BASIC_AUTH_PASSWORD"
elif [ -n "${NGINX_BASIC_AUTH_USER:-}" ] || [ -n "${NGINX_BASIC_AUTH_PASSWORD:-}" ]; then
    echo "Error: set both NGINX_BASIC_AUTH_USER and NGINX_BASIC_AUTH_PASSWORD (or neither)"
    exit 1
elif ! [ -e "$HTPASSWD_FILE" ]; then
    echo "Create NGINX user"
    read -p "Enter username (or press Enter to finish): " username
    if [ -z "$username" ]; then
        echo "Error: username is required to create $HTPASSWD_FILE"
        exit 1
    fi
    # Securely read password
    read -s -p "Enter password for $username: " password
    echo  # Add a newline after password input for better UX
    if [ -z "$password" ]; then
        echo "Error: password is required to create $HTPASSWD_FILE"
        exit 1
    fi

    write_htpasswd "$username" "$password"
fi
