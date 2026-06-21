# Check if the .env file exists
if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in
            ''|\#*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
        esac
        export "$key=$value"
    done < "$ENV_FILE"
else
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | cut -d= -f1)

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if curl is installed
if ! command_exists curl; then
    echo "Error: curl is not installed. Please install curl to proceed."
    exit 1
fi

SECONDS=0
TIMEOUT=10
while [ ! -e "./bin/envsubst.exe" ]; do
    if [ $SECONDS -ge $TIMEOUT ]; then
        echo "Timeout: File $FILE did not appear within $TIMEOUT seconds."
        exit 1
    fi
    sleep 1
done