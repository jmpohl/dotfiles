#!/usr/bin/env zsh
#
# install-dotfiles.sh — copy this repo's configs into their expected home
# locations, without Nix. A fallback for machines where you can't or don't
# want to use the home-manager flake in ~/src/dotfiles.~1~ (or wherever the
# Nix-based profile lives).
#
# Safe by default: NEVER overwrites a file/directory that already exists at
# the destination. Run with --dry-run first to see what would happen, or
# --force to overwrite (use with care — this can clobber real configs,
# especially ~/.ssh/config, which is guarded even under --force; see below).
#
# Usage:
#   ./install-dotfiles.sh              # copy anything missing
#   ./install-dotfiles.sh --dry-run     # show what would be copied, do nothing
#   ./install-dotfiles.sh --force       # overwrite existing files too (asks per-file)

set -u

DOTFILES_DIR="${0:A:h}"  # absolute path to the directory this script lives in
DRY_RUN=0
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --force) FORCE=1 ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force]"
            exit 0
            ;;
        *)
            echo "Unrecognized option: $arg" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# What gets copied where. Format: "source relative to this repo" -> "dest".
# Order matters only in that parent dirs are created as needed; entries are
# otherwise independent.
# ---------------------------------------------------------------------------
typeset -A dotfiles=(
    ["zsh/zshrc"]="$HOME/.zprezto/runcoms/zshrc"
    ["zsh/zprofile"]="$HOME/.zprezto/runcoms/zprofile"
    ["zsh/zprezto/zpreztorc"]="$HOME/.zprezto/runcoms/zpreztorc"
    ["tmux/tmux.conf"]="$HOME/.tmux.conf"
    ["kak"]="$HOME/.config/kak"
    ["wenv"]="$HOME/.config/wenv"
    ["nvim"]="$HOME/.config/nvim"
    ["kv"]="$HOME/.config/kv"
    ["lazygit/config.yml"]="$HOME/.config/lazygit/config.yml"
    ["lf"]="$HOME/.config/lf"
    ["bin"]="$HOME/bin"
    ["beets/config.yaml"]="$HOME/.config/beets/config.yaml"
    ["mpv/mpv.conf"]="$HOME/.config/mpv/mpv.conf"
    ["newsboat"]="$HOME/.newsboat"
)

# ~/.ssh/config is deliberately NOT in the table above. It's too easy to
# clobber a machine's real ssh config (proxy routes, host aliases, etc.) —
# on at least one machine this repo is used from, that file has irreplaceable
# live entries. Handle it explicitly, always asking, never silently.
SSH_CONFIG_SRC="$DOTFILES_DIR/ssh/config"
SSH_CONFIG_DEST="$HOME/.ssh/config"

# Directories this script intentionally does NOT touch: macos/, linux/,
# X11/, systemd/, julia/, jupyter/, vim/, bbmp/. These are either
# platform-specific (X11/linux/macos/systemd), for tools not everyone runs
# (julia/jupyter/vim/bbmp), or need manual review before copying (systemd
# unit files need root + systemctl enable, not a plain file copy). Copy them
# by hand if you need them.

echo "dotfiles repo: $DOTFILES_DIR"
(( DRY_RUN )) && echo "-- DRY RUN: no files will be changed --"
echo

copy_one() {
    local src="$1" dest="$2"
    local abs_src="$DOTFILES_DIR/$src"

    if [[ ! -e "$abs_src" ]]; then
        echo "SKIP  $src -> $dest  (source missing in repo)"
        return
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        if (( FORCE )); then
            printf "OVERWRITE %s -> %s ? [y/N] " "$src" "$dest"
            read -r reply
            if [[ "$reply" != [yY]* ]]; then
                echo "SKIP  $src -> $dest  (declined)"
                return
            fi
            if (( DRY_RUN )); then
                echo "WOULD REMOVE existing $dest, then copy $src"
                return
            fi
            rm -rf "$dest"
        else
            echo "SKIP  $src -> $dest  (already exists — pass --force to overwrite)"
            return
        fi
    fi

    if (( DRY_RUN )); then
        echo "WOULD COPY  $src -> $dest"
        return
    fi

    mkdir -p "${dest:h}"
    cp -R "$abs_src" "$dest"
    echo "COPIED  $src -> $dest"
}

for src in "${(@k)dotfiles}"; do
    copy_one "$src" "${dotfiles[$src]}"
done

echo
echo "--- ssh config (handled separately, always confirmed) ---"
if [[ ! -e "$SSH_CONFIG_SRC" ]]; then
    echo "SKIP  ssh/config  (source missing in repo)"
elif [[ -e "$SSH_CONFIG_DEST" ]]; then
    echo "SKIP  ssh/config -> $SSH_CONFIG_DEST  (already exists; this file commonly has"
    echo "      irreplaceable per-machine entries — merge the Include line and any"
    echo "      wanted Host blocks by hand instead of overwriting)"
else
    if (( DRY_RUN )); then
        echo "WOULD COPY  ssh/config -> $SSH_CONFIG_DEST"
    else
        mkdir -p "$HOME/.ssh"
        cp "$SSH_CONFIG_SRC" "$SSH_CONFIG_DEST"
        chmod 600 "$SSH_CONFIG_DEST"
        echo "COPIED  ssh/config -> $SSH_CONFIG_DEST"
    fi
fi

echo
echo "Done. Not handled by this script (copy manually if needed):"
echo "  macos/ linux/ X11/ systemd/ julia/ jupyter/ vim/ bbmp/"
