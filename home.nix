{ config, lib, pkgs, wenv, ... }:

let
  zprezto = pkgs.fetchgit {
    url = "https://github.com/sorin-ionescu/prezto.git";
    rev = "cff2d01871425b1b80710f8ec6a475c5a53145b4";
    sha256 = "sha256-TgdyG1XiQh61F2JPUChXe2srUxnJYOa5K1wLaRnmTlA=";
    fetchSubmodules = true;
    leaveDotGit = false;
  };

  # Every repo-tracked config file below is linked via mkOutOfStoreSymlink
  # instead of a plain `source = ./path` — home-manager's usual behavior
  # copies the file into the Nix store and symlinks *there*, which makes it
  # read-only (the symlink target is in /nix/store). mkOutOfStoreSymlink
  # instead symlinks straight to the file's real, absolute path, so it stays
  # editable in place — edit e.g. kak/kakrc directly and the change is live
  # immediately, no `home-manager switch` needed. The tradeoff: Nix no
  # longer guarantees the live file matches the last committed state, since
  # you can edit and forget to commit.
  #
  # NOTE: `local` takes a *string* like "kak/kakrc", not a Nix path
  # (./kak/kakrc) — a `./`-relative path gets resolved against this flake's
  # immutable store copy of the repo (flakes always copy their source into
  # the store, even for local git checkouts), which would silently point
  # `mkOutOfStoreSymlink` at another read-only copy and defeat the whole
  # point. Hardcoding against $HOME/src/dotfiles (this repo's location on
  # every machine it's used from) keeps it pointed at the real, live
  # checkout on disk instead.
  local = relPath: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/src/dotfiles/${relPath}";
in
{
  home.username = "jpohl";
  home.homeDirectory =
    if pkgs.stdenv.hostPlatform.isDarwin then "/Users/jpohl" else "/home/jpohl";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    zsh
    tmux
    kakoune
    fzf
    silver-searcher-ng # provides `ag`, used by skag/skak in .zshrc
    lazygit
    lf
    openssh
    git # needed by lazy.nvim's self-bootstrap (git clone) below, and by npm/pi below
    cargo # kakrc's plug.kak block self-builds kakoune-lsp via `cargo install` on first launch
    rustc
    neovim
    ripgrep # telescope.nvim live_grep/grep_string backend
    fd # telescope.nvim find_files backend
    gnumake # builds telescope-fzf-native.nvim and LuaSnip's jsregexp on first launch
    tree-sitter # nvim-treesitter's :TSInstall/:TSUpdate shell out to this CLI to compile parsers — without it on $PATH, parser installs fail silently and buffers get no syntax highlighting
    stylua
    nodejs_22 # required by the pi coding agent CLI (engines: node >=22.19.0), see activation script below
    ncdu
    jq
    rsync
    mosh
    claude-code
    rust-analyzer # nvim's rustaceanvim plugin auto-detects this on $PATH — no mason/network fetch needed
  ];

  ########################################
  # zsh + Zprezto
  ########################################
  # NOTE: deliberately NOT using programs.zsh.enable — that module generates
  # its own .zshenv/.zprofile/.zshrc/.zlogin/.zlogout via home.file and
  # collides with the ones set explicitly below (home-manager will warn
  # "conflicts with recursively symlinked file" and silently override one
  # with the other if both are set). Since Zprezto's runcoms are hand-managed
  # here, zsh itself is just installed as a plain package above.
  #
  # These paths point directly at this repo's real files (zsh/, kak/,
  # tmux/, etc.) — the same files install-dotfiles.sh copies for a no-Nix
  # setup. There is no separate files/ mirror to keep in sync. They're
  # linked via `local` (mkOutOfStoreSymlink, defined above) so the live
  # files stay editable in place.

  home.file.".zprezto".source = zprezto;
  home.file.".zshenv".source = "${zprezto}/runcoms/zshenv";
  home.file.".zlogin".source = "${zprezto}/runcoms/zlogin";
  home.file.".zlogout".source = "${zprezto}/runcoms/zlogout";
  home.file.".zprofile".source = local "zsh/zprofile";
  home.file.".zshrc".source = local "zsh/zshrc";
  home.file.".zpreztorc".source = local "zsh/zprezto/zpreztorc";

  # wenv completions (see wenv README step 4: symlink _wenv into fpath) —
  # zshrc's `fpath=($XDG_DATA_HOME/zsh/completions $fpath)` expects this.
  # zprofile sets XDG_DATA_HOME=$HOME/.local (not the XDG-spec default of
  # ~/.local/share), matching linux-tower's actual setting.
  home.file.".local/zsh/completions/_wenv".source = "${wenv}/_wenv";

  ########################################
  # tmux
  ########################################
  # tmux checks ~/.tmux.conf before $XDG_CONFIG_HOME/tmux/tmux.conf, and the
  # file's own `bind r source-file ~/.tmux.conf` reload binding assumes this
  # path too — so this manages ~/.tmux.conf directly, not the XDG location.
  home.file.".tmux.conf".source = local "tmux/tmux.conf";

  ########################################
  # kakoune + kakoune-lsp
  ########################################
  home.file.".config/kak/kakrc".source = local "kak/kakrc";
  # kakrc's kakoune-lsp plug block configures LSP entirely inline
  # (lsp_servers, per-filetype hooks) — no kak-lsp.toml needed. kakrc also
  # sources "%val{config}/plugins/plug.kak/rc/plug.kak" — plug.kak
  # (github:andreyorst/plug.kak) is a self-installing plugin manager; on
  # first kakoune launch it bootstraps itself and pulls down
  # kakoune-cd/kakoune-buffers/kakoune-lsp as declared in kakrc. This
  # includes self-building kakoune-lsp via `cargo install` (see the `cargo`/
  # `rustc` packages above) — no separate Nix-packaged kakoune-lsp binary is
  # installed, to avoid two copies of the same tool. Requires network access
  # on first run.

  ########################################
  # git
  ########################################
  # Personal identity by default (matches BLADE) — override per-machine with
  # a local `git config --global user.email ...` if needed (e.g. for work).
  programs.git = {
    enable = true;
    settings.user.name = "josie";
    settings.user.email = "josiahpohl@live.com";
  };

  ########################################
  # ssh (client config only — keys are not part of this profile)
  ########################################
  home.file.".ssh/config".source = local "ssh/config";

  ########################################
  # neovim (kickstart.nvim-derived, lazy.nvim + LSP/DAP/Rust)
  ########################################
  home.file.".config/nvim/init.lua".source = local "nvim/init.lua";
  home.file.".config/nvim/lazy-lock.json".source = local "nvim/lazy-lock.json";
  home.file.".config/nvim/.stylua.toml".source = local "nvim/.stylua.toml";
  # rust-analyzer (home.packages above) and codelldb (below) are both on
  # $PATH, so rustaceanvim's defaults (vim.fn.exepath('rust-analyzer') /
  # exepath_or_binary('codelldb')) find them with no mason install and no
  # network access — the only remaining first-launch network dependency is
  # lazy.nvim's own plugin bootstrap (git clone + pulling everything pinned
  # in lazy-lock.json).
  #
  # codelldb isn't a standalone nixpkgs package — it only ships bundled
  # inside the vscode-lldb extension derivation, which has no top-level
  # bin/, so home.packages alone wouldn't put it on $PATH. This symlinks
  # just the binary out to ~/bin instead of adding the whole extension.
  home.file."bin/codelldb".source =
    "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
  # NOTE: the rust-debugging config hardcodes
  # `/usr/lib/llvm-15/bin/lldb-vscode` as a DAP adapter path — that's specific
  # to a particular Ubuntu install. It's an unused fallback (codelldb is the
  # adapter actually wired to <F5>/RustLsp), but fix the path or remove the
  # `dap.adapters.lldb` block in nvim/init.lua if you rely on it.

  ########################################
  # lf
  ########################################
  home.file.".config/lf/lfrc".source = local "lf/lfrc";

  ########################################
  # lazygit
  ########################################
  home.file.".config/lazygit/config.yml".source = local "lazygit/config.yml";

  ########################################
  # ~/bin — editor wrapper scripts, portable/POSIX-only
  ########################################
  # NOTE: no `executable = true` here — with mkOutOfStoreSymlink, setting it
  # explicitly makes home-manager try to stat/cp the out-of-store target
  # during the sandboxed build (to verify/fix the executable bit), which
  # fails with "Permission denied"/"Operation not permitted" since the
  # sandbox can't read outside the Nix store. Leaving it unset (default:
  # inherit from source) just does a plain `ln -s`, which works fine — and
  # since these repo files already have +x set on disk, the symlink reports
  # as executable exactly like the file it points to.
  home.file."bin/kak_session".source = local "bin/kak_session";
  # kv swaps between kakoune and neovim on the same file/cursor position via
  # <F8>, sharing one daemon per wenv with kak_session. Depends on
  # ~/.config/kv/swap.kak + swap.lua below, both sourced by kv itself.
  home.file."bin/kv".source = local "bin/kv";
  home.file.".config/kv/swap.kak".source = local "kv/swap.kak";
  home.file.".config/kv/swap.lua".source = local "kv/swap.lua";
  home.file."bin/newticket".source = local "bin/newticket";

  ########################################
  # wenv — personal work-environment switcher (github:dgrisham/wenv)
  ########################################
  # zshrc (shared with the no-Nix path) sources $SRC/wenv/wenv directly —
  # i.e. ~/src/wenv/wenv, since zprofile sets SRC=$HOME/src — rather than a
  # Nix-store path, so both paths (Nix and plain-copy) load it the same way.
  # This symlinks ~/src/wenv to the pinned wenv-src flake input; on a non-Nix
  # machine you'd instead `git clone https://github.com/dgrisham/wenv ~/src/wenv`
  # by hand.
  home.file."src/wenv".source = wenv;

  home.file.".config/wenv/template".source = "${wenv}/template";
  home.file.".config/wenv/extensions".source = "${wenv}/extensions";
  # `wenvs/` holds your individual project definitions; this repo's real
  # wenv/wenvs/ directory (see ./wenv/wenvs) is used instead of a separate
  # Nix-only copy — add your own project wenv files there.
  home.file.".config/wenv/wenvs".source = local "wenv/wenvs";

  ########################################
  # pi coding agent (github:earendil-works/pi)
  ########################################
  # Not packaged as a Nix derivation — pi's a multi-package npm monorepo with
  # no existing nixpkgs derivation, and building one (buildNpmPackage +
  # npmDepsHash for the whole workspace) was judged not worth the effort/risk
  # vs. just letting npm install it normally. Installed via a home-manager
  # activation script into a user-local npm prefix (~/.local/npm-global,
  # set via NPM_CONFIG_PREFIX in zsh/zprofile) instead of the Nix store.
  # This means `pi` itself is NOT reproducible/pinned by this flake — it's
  # whatever version npm resolves at each `home-manager switch`. `--ignore-scripts`
  # is used per pi's own install instructions (its packages don't need
  # postinstall scripts; photon-node's image resizing is WASM, not a native
  # build). Config lives at ~/.pi/agent/ (not managed by this profile).
  home.activation.installPiCodingAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="$HOME/.local/npm-global"
    $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  '';
}
