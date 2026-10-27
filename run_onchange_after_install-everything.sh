#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C.UTF-8

install_and_configure_locale() {
    sudo apt-get update --error-on=any
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        locales \
        build-essential \
        procps \
        curl \
        file \
        git

    # Enable en_US.UTF-8 for locale-gen without changing other locales.
    if ! grep -Eq '^[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8([[:space:]]|$)' \
        /etc/locale.gen; then
        echo 'en_US.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null
    fi

    if ! LC_ALL=C locale -a | grep -Eiq '^en_US\.(utf8|utf-8)$'; then
        sudo env LC_ALL=C locale-gen
    fi

    # Set the system default and clear other system-wide locale settings.
    sudo env LC_ALL=C update-locale --reset LANG=en_US.UTF-8
}

install_homebrew() (
    local installer_dir

    if command -v brew >/dev/null 2>&1 \
        || [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] \
        || [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
        echo "Homebrew is already installed."
        return 0
    fi

    installer_dir=$(mktemp -d)
    trap 'rm -rf "$installer_dir"' EXIT

    curl -fsSL \
        https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
        -o "$installer_dir/install.sh"

    NONINTERACTIVE=1 /bin/bash "$installer_dir/install.sh"
)

install_brew_bundle() {
    local brew_path

    if command -v brew >/dev/null 2>&1; then
        brew_path=$(command -v brew)
    elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        brew_path=/home/linuxbrew/.linuxbrew/bin/brew
    elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
        brew_path="$HOME/.linuxbrew/bin/brew"
    else
        echo "Homebrew was not found after installation." >&2
        return 1
    fi

    # Make Homebrew and its installed tools available to this script.
    eval "$("$brew_path" shellenv)"
    brew analytics off
    brew developer off
    brew update
    brew bundle install --global
}

install_fisher() (
    local plugins_file="${XDG_CONFIG_HOME:-$HOME/.config}/fish/fish_plugins"
    local tmpdir
    local fish_script

    if ! command -v fish >/dev/null 2>&1; then
        echo "Fish was not found. Add it to your Brewfile." >&2
        return 1
    fi

    if [[ -L "$plugins_file" || ! -f "$plugins_file" ]]; then
        echo "Expected a regular Fish plugin list at: $plugins_file" >&2
        return 1
    fi

    tmpdir=$(mktemp -d)
    cp "$plugins_file" "$tmpdir/fish_plugins"
    trap 'cp "$tmpdir/fish_plugins" "$plugins_file"; rm -rf "$tmpdir"' EXIT

    if ! fish -c 'functions --query fisher' </dev/null; then
        curl -fsSL \
            'https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish' \
            -o "$tmpdir/fisher.fish"
    fi

    fish_script=$(cat <<'FISH'
if test -f "$argv[1]"
    source "$argv[1]"; or exit 1
end

fisher update

# Compare against Fisher's recorded plugin names.
for plugin in (string match --regex -- '^[^\s]+$' < "$argv[2]")
    set -l expanded (string replace -- '~' "$HOME" "$plugin")

    if test -e "$expanded"
        set plugin (realpath "$expanded")
    else
        set plugin (string lower -- "$expanded")
    end

    if not contains -- "$plugin" $_fisher_plugins
        echo "Fisher plugin not installed: $plugin" >&2
        exit 1
    end
end

exit 0
FISH
    )

    fish -c "$fish_script" -- "$tmpdir/fisher.fish" "$tmpdir/fish_plugins" \
        </dev/null
)

if [[ $(id -u) -eq 0 ]]; then
    echo "Run Chezmoi as the standard user, not root." >&2
    exit 1
fi

install_and_configure_locale
install_homebrew
install_brew_bundle
install_fisher
