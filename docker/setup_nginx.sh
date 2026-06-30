if [ -n "$ENV_FILE" ]; then
    echo "Skipping nginx env setup"
else
    ENV_FILE=".env"
    source ./load_env.sh
fi

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

export host="\$host" server_port="\$server_port" http_x_csrf_token="\$http_x_csrf_token" http_authorization="\$http_authorization" http_cookie="\$http_cookie" remote_addr="\$remote_addr" proxy_add_x_forwarded_for="\$proxy_add_x_forwarded_for" scheme="\$scheme" http_upgrade="\$http_upgrade" connection_upgrade="\$connection_upgrade"

append_nginx_block_if_replicas() {
    local replicas="${1:-0}"
    local template="$2"
    local output="$3"

    if [[ "${replicas}" -gt 0 ]]; then
        envsubst < "${template}" >> "${output}"
        echo "" >> "${output}"
        echo "Included nginx block from ${template}"
    else
        echo "Skipping nginx block ${template} (replicas=${replicas})"
    fi
}

if [[ "${STACK_ARRAY[@]}" =~ "core" ]]; then
    : > ./volumes/nginx/conf.d/http/core.conf
    append_nginx_block_if_replicas "${CORE_STUDIO_REPLICAS:-0}" ./volumes/nginx/conf.d/http/core-studio.conf.template ./volumes/nginx/conf.d/http/core.conf
    append_nginx_block_if_replicas "${CORE_KONG_REPLICAS:-0}" ./volumes/nginx/conf.d/http/core-kong.conf.template ./volumes/nginx/conf.d/http/core.conf
    append_nginx_block_if_replicas "${CORE_ANALYTICS_REPLICAS:-0}" ./volumes/nginx/conf.d/http/core-logflare.conf.template ./volumes/nginx/conf.d/http/core.conf

    if [[ -s ./volumes/nginx/conf.d/http/core.conf ]]; then
        export NGINX_CORE_HTTP_CONFIG="include /etc/nginx/conf.d/http/core.conf;"
    else
        export NGINX_CORE_HTTP_CONFIG=""
        echo "No core HTTP nginx hosts enabled"
    fi

    : > ./volumes/nginx/conf.d/stream/core.conf
    append_nginx_block_if_replicas "${CORE_DB_REPLICAS:-0}" ./volumes/nginx/conf.d/stream/core-db.conf.template ./volumes/nginx/conf.d/stream/core.conf

    if [[ -s ./volumes/nginx/conf.d/stream/core.conf ]]; then
        export NGINX_CORE_STREAM_CONFIG="include /etc/nginx/conf.d/stream/core.conf;"
    else
        export NGINX_CORE_STREAM_CONFIG=""
        echo "No core stream nginx hosts enabled"
    fi
else
    echo "Skipping nginx core config"
    export NGINX_CORE_HTTP_CONFIG=""
    export NGINX_CORE_STREAM_CONFIG=""
fi

if [[ "${STACK_ARRAY[@]}" =~ "ecommerce" ]]; then
    : > ./volumes/nginx/conf.d/http/ecommerce.conf
    append_nginx_block_if_replicas "${ECOMMERCE_MEDUSA_SERVER_REPLICAS:-0}" ./volumes/nginx/conf.d/http/ecommerce-medusa.conf.template ./volumes/nginx/conf.d/http/ecommerce.conf

    if [[ -s ./volumes/nginx/conf.d/http/ecommerce.conf ]]; then
        export NGINX_ECOMMERCE_HTTP_CONFIG="include /etc/nginx/conf.d/http/ecommerce.conf;"
    else
        export NGINX_ECOMMERCE_HTTP_CONFIG=""
        echo "No ecommerce HTTP nginx hosts enabled"
    fi

    : > ./volumes/nginx/conf.d/stream/ecommerce.conf
    append_nginx_block_if_replicas "${ECOMMERCE_MEDUSA_SERVER_REPLICAS:-0}" ./volumes/nginx/conf.d/stream/ecommerce-medusa.conf.template ./volumes/nginx/conf.d/stream/ecommerce.conf

    if [[ -s ./volumes/nginx/conf.d/stream/ecommerce.conf ]]; then
        export NGINX_ECOMMERCE_STREAM_CONFIG="include /etc/nginx/conf.d/stream/ecommerce.conf;"
    else
        export NGINX_ECOMMERCE_STREAM_CONFIG=""
        echo "No ecommerce stream nginx hosts enabled"
    fi
else
    echo "Skipping nginx ecommerce config"
    export NGINX_ECOMMERCE_HTTP_CONFIG=""
    export NGINX_ECOMMERCE_STREAM_CONFIG=""
fi

if [[ "${STACK_ARRAY[@]}" =~ "ai" ]]; then
    : > ./volumes/nginx/conf.d/http/ai.conf
    append_nginx_block_if_replicas "${AI_OPEN_WEBUI_REPLICAS:-0}" ./volumes/nginx/conf.d/http/ai-open-webui.conf.template ./volumes/nginx/conf.d/http/ai.conf
    append_nginx_block_if_replicas "${AI_OPENEDAI_SPEECH_SERVER_REPLICAS:-0}" ./volumes/nginx/conf.d/http/ai-openedai-speech.conf.template ./volumes/nginx/conf.d/http/ai.conf

    if [[ -s ./volumes/nginx/conf.d/http/ai.conf ]]; then
        export NGINX_AI_HTTP_CONFIG="include /etc/nginx/conf.d/http/ai.conf;"
    else
        export NGINX_AI_HTTP_CONFIG=""
        echo "No ai HTTP nginx hosts enabled"
    fi
else
    echo "Skipping nginx ai config"
    export NGINX_AI_HTTP_CONFIG=""
fi

if [[ "${STACK_ARRAY[@]}" =~ "blog" ]]; then
    : > ./volumes/nginx/conf.d/http/blog.conf
    append_nginx_block_if_replicas "${BLOG_GHOST_REPLICAS:-0}" ./volumes/nginx/conf.d/http/blog-ghost.conf.template ./volumes/nginx/conf.d/http/blog.conf

    if [[ -s ./volumes/nginx/conf.d/http/blog.conf ]]; then
        export NGINX_BLOG_HTTP_CONFIG="include /etc/nginx/conf.d/http/blog.conf;"
    else
        export NGINX_BLOG_HTTP_CONFIG=""
        echo "No blog HTTP nginx hosts enabled"
    fi
else
    echo "Skipping nginx blog config"
    export NGINX_BLOG_HTTP_CONFIG=""
fi

envsubst < ./volumes/nginx/nginx.conf.template > ./volumes/nginx/nginx.conf
