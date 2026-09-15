#!/usr/bin/env bash
# Configure the repository-scoped Bunny cache values used by CI.
set -euo pipefail

repo=sandwichfarm/hyprexpo

usage() {
    cat <<'EOF'
Usage: configure-bunny-cache.sh [--repo OWNER/REPO]

Prompts for the two public GitHub Actions variables and three repository
secrets required by the signed Bunny-backed Hyprland cache.
EOF
}

while (($#)); do
    case $1 in
        --repo)
            (($# >= 2)) || { echo '--repo requires OWNER/REPO' >&2; exit 2; }
            repo=$2
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

[[ $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
    echo 'Repository must be OWNER/REPO' >&2
    exit 2
}

prompt_public() {
    local label=$1 variable=$2
    read -r -p "$label: " "$variable"
}

prompt_secret() {
    local label=$1 variable=$2
    read -r -s -p "$label: " "$variable"
    printf '\n'
}

prompt_public 'BUNNY_CACHE_URL (public HTTPS cache URL)' cache_url
prompt_public 'BUNNY_CACHE_PUBLIC_KEY (Nix public signing key)' public_key
prompt_secret 'BUNNY_CACHE_STORAGE_ZONE (dedicated Bunny zone)' storage_zone
prompt_secret 'BUNNY_CACHE_STORAGE_PASSWORD' storage_password
prompt_secret 'BUNNY_CACHE_SIGNING_KEY (Nix private signing key)' signing_key

[[ $cache_url == https://* && $cache_url != *[$'\r\n\t ']* && $cache_url != *'?'* && $cache_url != *'#'* && $cache_url != *'@'* ]] || {
    echo 'BUNNY_CACHE_URL must be an HTTPS cache URL without credentials, query, or fragment' >&2
    exit 2
}
[[ $public_key =~ ^[A-Za-z0-9._-]+:[A-Za-z0-9+/]+={0,2}$ ]] || {
    echo 'BUNNY_CACHE_PUBLIC_KEY is not a Nix public key' >&2
    exit 2
}
[[ $storage_zone =~ ^[A-Za-z0-9_-]+$ ]] || {
    echo 'BUNNY_CACHE_STORAGE_ZONE must contain only letters, numbers, underscores, or hyphens' >&2
    exit 2
}
[[ -n $storage_password ]] || { echo 'BUNNY_CACHE_STORAGE_PASSWORD cannot be empty' >&2; exit 2; }
[[ $signing_key =~ ^[A-Za-z0-9._-]+:[A-Za-z0-9+/]+={0,2}$ ]] || {
    echo 'BUNNY_CACHE_SIGNING_KEY is not a Nix private key' >&2
    exit 2
}

command -v gh >/dev/null || { echo 'gh is required' >&2; exit 127; }
gh auth status --hostname github.com >/dev/null

set_variable() {
    printf '%s' "$2" | gh variable set "$1" --repo "$repo"
}

set_secret() {
    # stdin keeps the value out of the command line and process arguments.
    printf '%s' "$2" | gh secret set "$1" --repo "$repo"
}

set_variable BUNNY_CACHE_URL "$cache_url"
set_variable BUNNY_CACHE_PUBLIC_KEY "$public_key"
set_secret BUNNY_CACHE_STORAGE_ZONE "$storage_zone"
set_secret BUNNY_CACHE_STORAGE_PASSWORD "$storage_password"
set_secret BUNNY_CACHE_SIGNING_KEY "$signing_key"

unset cache_url public_key storage_zone storage_password signing_key
printf 'Configured Bunny cache variables and secrets for %s.\n' "$repo"
