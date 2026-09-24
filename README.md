# dotfiles

Personal dotfiles — zsh + Zprezto, tmux, kakoune (+ kakoune-lsp), neovim, `kv`
(swap kakoune/neovim on the same file), lazygit, lf, git, ssh config, the
[wenv](https://github.com/dgrisham/wenv) shell tool, the
[pi](https://github.com/earendil-works/pi) coding agent, Claude Code, and a
handful of plain utilities (ncdu, jq, rsync, mosh).

Two ways to apply this repo to a machine — same files, your choice per
machine:

1. **Nix / home-manager** (`flake.nix` + `home.nix`) — declarative,
   reproducible, tracks upstream pins (Zprezto, wenv) automatically.
2. **Plain copy script** (`install-dotfiles.sh`) — no Nix required, just
   `cp`. Safe by default: never overwrites an existing file without asking.

Both read from the *same* source files (`zsh/`, `kak/`, `tmux/`, `nvim/`,
etc.) at the repo root — there's no separate Nix-only mirror to keep in sync,
which is what caused real drift bugs earlier in this repo's history.

This repo merges configs from two machines: BLADE (personal Arch laptop, now
on its own separate NixOS flake) and linux-tower (work Ubuntu desktop,
Anduril). Where they diverged, linux-tower's version generally won as the
superset — see "What's included" below for specifics.

## Option 1: Nix / home-manager

```sh
nix run home-manager -- switch --flake .#<system> --option sandbox relaxed
```

`<system>` is one of `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`,
`aarch64-darwin` (`nix eval --impure --expr 'builtins.currentSystem'` tells
you which). `--option sandbox relaxed` is needed because of `claude-code`'s
build — see "Claude Code" below.

Once home-manager is installed/on `$PATH`, subsequent updates are just:

```sh
home-manager switch --flake .#<system> --option sandbox relaxed
```

### Using this as a flake input from another repo

A NixOS (or nix-darwin) host config can pull this repo in as a flake input
and layer machine-specific config (X11, a window manager, audio, hardware)
on top of the *same* dotfiles, instead of maintaining a second copy that
drifts:

```nix
# in the other repo's flake.nix
inputs.dotfiles.url = "github:<you>/dotfiles";

# in that flake's outputs
home-manager.users.<name> = { imports = [ dotfiles.homeModule ]; };
home-manager.extraSpecialArgs = { wenv = dotfiles.inputs.wenv-src; };
```

`dotfiles.homeModule` is `./home.nix` from this repo, exposed as a flake
output so downstream flakes don't need to know this repo's internal layout.
`wenv` is a module argument `home.nix` expects — pass through
`dotfiles.inputs.wenv-src` so both configs stay pinned to the same wenv
revision.

### Using this on an offline machine

`nix copy` moves an already-built closure over SSH/LAN, so a machine with no
internet access (but on the same LAN as one that does) can still get the
full profile with zero fetches from `cache.nixos.org`. Best done from a
same-architecture, same-OS-family source machine — e.g. an Ubuntu box with
Nix installed, copying to a NixOS box, both `x86_64-linux` — so nothing
needs cross-compiling:

```sh
# On the machine WITH internet access:
git clone https://github.com/<you>/dotfiles ~/src/dotfiles
cd ~/src/dotfiles
nix build .#homeConfigurations.x86_64-linux.activationPackage
nix copy --to ssh://user@offline-host ./result
rsync -av ~/src/dotfiles/ user@offline-host:~/src/dotfiles/   # nix copy only moves /nix/store paths, not this repo — the out-of-store symlinks in home.nix need the real checkout on disk

# On the offline machine — run the already-built activation script directly,
# NOT `home-manager switch --flake .`, which would re-evaluate the flake and
# try to fetch nixpkgs/home-manager/wenv-src over the network:
ssh user@offline-host
/nix/store/.../activate   # path shown by `nix copy` / `readlink ./result`
```

The receiving machine's SSH user needs to be root or a Nix `trusted-users`
account, or the daemon will reject the copied paths on signature
verification. This is also how `rust-analyzer`/`codelldb` (see "neovim"
below) end up usable with no network at all — they're plain Nix packages,
so they travel with the rest of the closure.

**neovim's plugins are not part of the Nix closure and need a separate
copy.** lazy.nvim's plugin clones, mason's installed tools
(`lua-language-server`, `stylua`), and treesitter's per-language parsers all
live under `~/.local/nvim` (this repo's `XDG_DATA_HOME`, see below) —
plain `git clone`/downloads done by neovim itself on first launch, entirely
outside `/nix/store`, so `nix copy` doesn't touch any of it. Bring that
directory over the same way as the repo itself:

```sh
# On the machine WITH internet access, first make sure everything's
# installed. lazy.nvim's plugins install on first launch of a plain `nvim`;
# treesitter parsers install lazily per-filetype instead, so explicitly
# :TSInstall whichever languages you care about (this repo's home.packages
# already includes the `tree-sitter` CLI treesitter shells out to for the
# compile step — without it, installs fail silently with no highlighting,
# no error):
nvim --headless "+TSInstall! lua rust" "+lua vim.defer_fn(function() vim.cmd('qa!') end, 30000)"

# Then copy the whole directory over — ~90MB in practice, trivial over LAN:
rsync -av ~/.local/nvim/ user@offline-host:~/.local/nvim/
```

Do this *before* first launching neovim on the offline machine — if
`~/.local/nvim/lazy/lazy.nvim` doesn't exist yet, `init.lua`'s bootstrap
tries to `git clone` it and fails offline.


## Option 2: plain copy script (no Nix)

```sh
./install-dotfiles.sh --dry-run   # see what would happen, changes nothing
./install-dotfiles.sh              # copy anything missing
./install-dotfiles.sh --force      # also offer to overwrite existing files (asks per file)
```

Copies `zsh/`, `kak/`, `tmux/`, `wenv/`, `nvim/`, `kv/`, `lazygit/`, `lf/`,
`bin/`, `beets/`, `mpv/`, `newsboat/` to their expected home locations.
Never touches `~/.ssh/config` without asking, even under `--force` — that
file commonly has irreplaceable per-machine entries.

Not handled by the script (copy by hand if needed): `macos/`, `linux/`,
`X11/`, `systemd/`, `julia/`, `jupyter/`, `vim/`, `bbmp/` — either
platform-specific, for tools not everyone runs, or need manual review
(systemd units need root + `systemctl enable`, not a plain copy).

Under this path, `wenv` needs to be cloned manually:

```sh
git clone https://github.com/dgrisham/wenv ~/src/wenv
```

(Nix does this for you automatically — see below.)

## What's included

- **zsh + [Zprezto](https://github.com/sorin-ionescu/prezto)** —
  `zsh/zprofile`, `zsh/zshrc`, `zsh/zprezto/zpreztorc` are the three runcoms
  that are actually customized; `zshenv`/`zlogin`/`zlogout` are stock
  Zprezto (under Nix, symlinked straight from the fetched `zprezto` repo; on
  a plain-copy machine, Zprezto's own installer creates them). `zpreztorc`
  is trimmed to 9 of Prezto's modules — `directory`, `terminal`, and
  `utility` were dropped as unused (no bare-dirname `cd`/pushd habit, no
  tab-title watching, and `utility`'s ~60 aliases like `ll`/`la` are
  superseded by aliases already in `zshrc`). `zshrc` has `startx` on tty1,
  `wifi`/`open` aliases, `vim=nvim`, `skim`/`skif` (EDITOR=nvim variants),
  `skap` (copy a fzf pick into the tmux buffer), the wenv/skag/skak
  integration, and re-sources `zsh/zprezto/prompt_steeef_setup` right after
  Prezto loads, to override Prezto's stock `steeef` theme with this repo's
  customized one (`@`/`:` separators instead of `at`/`in`, no editor-mode
  indicator in the prompt).
- **tmux** — `tmux/tmux.conf`. Adds `focus-events`/`extended-keys` for
  nvim/tmux interop and a `choose-tree` session-sort binding. Reload is
  bound to `~/.tmux.conf` (this repo's actual convention — not
  `~/.config/tmux/tmux.conf`).
- **kakoune + kakoune-lsp** — `kak/kakrc`. Moonfly colorscheme, a
  `kakoune-lsp` plug block that self-builds via `cargo install` on first
  launch (rust-analyzer config included, LSP auto-enabled for
  json/kotlin/python/rust), a tmux-register clipboard hook, a
  format-selection binding. `kakrc` sources `plug.kak`
  (github:andreyorst/plug.kak), a self-installing plugin manager — first
  launch needs network access to bootstrap
  `kakoune-cd`/`kakoune-buffers`/`kakoune-lsp`.
- **neovim** — `nvim/init.lua` (+ `lazy-lock.json`, `.stylua.toml`). A
  kickstart.nvim-derived config: lazy.nvim plugin manager, LSP via
  mason/nvim-lspconfig, Telescope, blink.cmp completion, DAP debugging
  (Rust-focused via rustaceanvim/codelldb). First launch needs network
  access — lazy.nvim self-bootstraps via `git clone`, then installs every
  plugin pinned in `lazy-lock.json`. Rust LSP and debugging are the
  exception: `rust-analyzer` and `codelldb` (see below) are both installed
  via Nix and put on `$PATH`, which rustaceanvim's defaults pick up
  directly — no mason install, no network, works offline once the Nix
  closure itself is on the machine (e.g. copied over via `nix copy` — see
  "Using this on an offline machine" below). One hardcoded path
  (`/usr/lib/llvm-15/bin/lldb-vscode`, an unused fallback DAP adapter) is
  specific to a particular Ubuntu install; fix or remove it if you need that
  adapter.
- **kv** (`bin/kv` + `kv/swap.kak` + `kv/swap.lua`) — swaps between kakoune
  and neovim on the same file/cursor position via `<F8>`, sharing one daemon
  per wenv with `kak_session`. Both editors' servers outlive the terminal,
  so the next `kv` in the same wenv is instant.
- **lazygit** — `lazygit/config.yml`. Wires the editor integration to
  `kak_session` and copies to the tmux buffer instead of a system clipboard
  tool.
- **lf** — `lf/lfrc`. Includes `set cleaner`/`set previewer` pointing at
  ueberzug-based image preview scripts — those scripts (`lf/cleaner`,
  `lf/scope`) need `ueberzug` installed and only work under X11; harmless
  no-ops elsewhere.
- **ssh** — `ssh/config`, client config only (no keys). Deliberately does
  NOT include employer-specific proxy entries (e.g. Anduril's
  `*.dgi`/`*.lonestar` via `latticectl netrelay`) — add those to a local
  `~/.ssh/config.d/` file instead; this file has an
  `Include ~/.ssh/config.d/*` line to pull them in.
- **[wenv](https://github.com/dgrisham/wenv)** — under Nix, referenced
  directly from its GitHub repo (flake input `wenv-src`), with `~/src/wenv`
  symlinked to it — `nix flake update` pulls in new upstream commits
  automatically. Under the plain-copy path, clone it manually (see above).
  `wenv/template` and `wenv/wenvs/` in this repo hold the template and your
  own project-specific wenv definitions.
- **[pi coding agent](https://github.com/earendil-works/pi)** — see its own
  section below; NOT a Nix derivation, installed via `npm` at activation
  time (Nix path) or left to you to `npm install -g` (plain-copy path).
- **Claude Code** — the `claude-code` package from nixpkgs (Nix path only —
  install it yourself otherwise). No config managed by this repo; see
  "Claude Code" below.
- **git** — personal identity by default (`josie` / `josiahpohl@live.com`).
  Override per-machine with a local `git config --global user.email ...`
  for work contexts — this repo intentionally does not bake in any
  employer-specific git identity or URL rewrites.
- **ncdu, jq, rsync, mosh** — plain utility packages/tools, no config to
  speak of, useful on any terminal.

## btop — NOT included

Both source machines had a customized `~/.config/btop/btop.conf`, but the
differences were mostly cosmetic (box order, process sort mode, GPU/sensor
toggles) — not worth reconciling. `btop` isn't installed by this repo; add
it plus your own config if you want it.

## pi coding agent

[`pi`](https://github.com/earendil-works/pi) (`@earendil-works/pi-coding-agent`
on npm). Under Nix, installed via a home-manager activation script
(`home.activation.installPiCodingAgent` in `home.nix`), not a Nix derivation:

```sh
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

This runs on every `home-manager switch`, using the `nodejs_22` from
`home.packages` (pi requires Node >=22.19.0). `--ignore-scripts` matches
pi's own documented install instructions — none of its dependencies need
postinstall/native builds (the one package that does image work,
`photon-node`, ships as WASM).

**Why not a real Nix derivation?** pi is a multi-package npm monorepo with
no existing nixpkgs derivation. Packaging it properly means a
`buildNpmPackage` derivation plus generating an `npmDepsHash` for the whole
workspace — real effort, not done here. The tradeoff of the
activation-script approach: `pi`'s version isn't pinned by this flake — it's
whatever `npm install -g` resolves at each activation, and the install
happens outside the Nix store.

Installed to `$NPM_CONFIG_PREFIX/bin` (`~/.local/npm-global/bin`, set in
`zsh/zprofile`, which also adds it to `$PATH`). pi's own config/sessions
live at `~/.pi/agent/` (override with `$PI_CODING_AGENT_DIR`) — not managed
by this repo. Run `pi` and either export an API key (`ANTHROPIC_API_KEY`
etc.) or run `/login` inside it before first use.

## Claude Code

Just the `claude-code` package from nixpkgs (Nix path only) — no config
managed by this repo.

**Build note:** nixpkgs' `claude-code` derivation downloads the actual
`claude` binary from `downloads.claude.ai` at *build* time (it's a wrapped
prebuilt binary, not compiled from source), and is marked `__noChroot` to
allow that network access. If your Nix has a strict sandbox (`sandbox =
true` with no fallback), the build fails with `has '__noChroot' set, but
that's not allowed when 'sandbox' is 'true'`. Work around it with:

```sh
nix run home-manager -- switch --flake .#<system> --option sandbox relaxed
```

or set `sandbox-fallback = true` in your Nix config (many Linux installs
already default this way; it's macOS/strict-sandbox setups that tend to hit
this).

## Secrets NOT included

One of the source machines' `~/.zprofile` had live plaintext tokens (Jira,
Confluence, Quip, CircleCI, Cargo registry credentials) and a hardcoded
SSH/SCP password in a shell helper. None of that was ported — per-machine
secrets like these should be set outside this repo (a shell profile fragment
sourced conditionally, a password manager, sops-nix if paired with a NixOS
host, etc.), not committed to a shared dotfiles repo.

## Machine/employer-specific overrides: `~/.zprofile.local`, `~/.zshrc.local`

`zsh/zprofile` and `zsh/zshrc` both source `~/.zprofile.local` /
`~/.zshrc.local` if present, as their very last line. Neither file lives in
this repo or is created by it — they're plain, untracked files you create by
hand on any machine that needs something this repo shouldn't carry (an
internal `NIX_PATH`/`GOPATH` override, a company dev-tool version manager, a
hardcoded local library path, etc.). Same idea as `~/.ssh/config.d/*` for
ssh config.

`.zprofile.local` is sourced early (end of `zprofile`, before `zshrc` loads),
so env vars set there are available everywhere; `.zshrc.local` is sourced
last (end of `zshrc`), so it can override any alias/function defined above
it.

## Machine/employer-specific ssh config: `~/.ssh/config.d/`

This repo's `ssh/config` starts with `Include ~/.ssh/config.d/*`, before its
own `Host` entries — ssh applies the *first* matching value per host/option,
so `Include` has to come first to let files in `config.d/` take precedence.
Drop as many files as you want in `~/.ssh/config.d/` (any name — `work`,
`personal`, whatever), each a normal ssh config fragment (`Host` blocks,
`ProxyCommand`, etc.). None of them are tracked by this repo or touched by
`home-manager switch` / `install-dotfiles.sh` — they're exactly the kind of
per-machine, often-employer-specific content (VPN proxy routes, internal
host aliases) that shouldn't live in a public dotfiles repo.

If a machine already has host entries directly in `~/.ssh/config` from
before adopting this repo, move them into `~/.ssh/config.d/<name>` first —
otherwise `home-manager switch` (or `install-dotfiles.sh --force`) will
overwrite `~/.ssh/config` with this repo's version and those entries would
be lost.

## XDG variables

`zsh/zprofile` sets `XDG_CONFIG_HOME=$HOME/.config` and
`XDG_DATA_HOME=$HOME/.local` — note the latter is `~/.local`, not the
XDG-spec default of `~/.local/share`. This matches what's actually live on
the source machines; `zshrc`'s `fpath=($XDG_DATA_HOME/zsh/completions
$fpath)` and the `pi`/npm prefix (`$HOME/.local/npm-global`) both follow
from this.

## Important: `programs.zsh.enable` is intentionally NOT set

Home-manager's `programs.zsh` module generates its own
`.zshenv`/`.zprofile`/`.zshrc`/`.zlogin`/`.zlogout` via `home.file`. Since
Zprezto's runcoms are hand-managed here instead, turning on `programs.zsh`
would collide with the manual `home.file` entries for those same paths
(home-manager warns `"<path> conflicts with recursively symlinked file"`
and silently lets one clobber the other). `zsh` is installed as a plain
package in `home.packages` instead.

## Adding your own wenvs

`wenv/wenvs/` holds your individual project wenv definitions (just a
`.gitkeep` placeholder by default — git doesn't track empty directories, and
an empty `wenv/wenvs/` breaks the Nix build, so don't remove the last file
in it without adding another). Add your own files there directly; both the
Nix path (`home.nix` sources the whole `./wenv/wenvs` directory) and the
plain-copy path pick them up automatically.

If a wenv needs a secret (an API token, etc.), don't put it in the wenv file
directly — either read it from an already-decrypted secret elsewhere (e.g.
sops-nix on a NixOS host) or keep it out of version control entirely.
