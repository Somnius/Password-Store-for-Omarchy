# Password Store for Omarchy

An [Omarchy](https://omarchy.org/) shell plugin that puts your password vault in a dedicated desktop window — **Bitwarden**, **Vaultwarden** (self-hosted), **1Password** or **LastPass** — without installing anything from those vendors.

A key glyph sits in the bar (default: right side):

- **Left-click** — panel: pick your provider, open the vault window.
- **Hover** — tooltip with the active provider.
- **IPC `launch`** — open the vault window immediately.

<img width="404" height="546" alt="image" src="https://github.com/user-attachments/assets/4e0359d1-eac4-47e5-b2a9-b6cc2c815676" />

## Why a dedicated vault window

Browser-extension popups are bundles inside each vendor's extension runtime (1Password's even requires its native-messaging desktop app) and cannot be loaded standalone. But every supported vendor ships a full-featured **web vault**, and this plugin gives that web vault a proper home:

- **Standalone app window**: Chromium `--app` mode — chromeless, no tabs, reads like a native vault app.
- **Isolated profile per provider**: `~/.local/share/omarchy/password-store/<provider>-profile`. Sign in once; the session persists across opens. Vault cookies never touch your daily browser profile.
- Falls back to `xdg-open` when no Chromium-family browser is found.

## Security model

The plugin is deliberately minimal:

- **No credentials stored.** No passwords, no master password, no TOTP seeds, no encrypted blob, nothing — not in config, not in memory, not on disk.
- **Unlocking happens inside the web vault.** Search, copy and autofill-within-the-vault are protected by your provider's own 2FA, device approvals and lock timers.
- **One file written**: `~/.config/omarchy/password-store/config.json` — provider name, optional self-hosted URL, optional browser override. Nothing else.

If a password-manager plugin offers you an "encrypted local cache" of secrets, it has also offered you a key-management problem. This one refuses the premise.

## Install

```sh
omarchy plugin add https://github.com/Somnius/Password-Store-for-Omarchy.git --enable
```

Then place the widget in the bar:

```sh
omarchy bar plugin add lef.password-store --section right
```

### From a local checkout (development)

If you already have a copy of this repository on disk, link it into the plugins folder:

```sh
ln -s "$PWD" ~/.config/omarchy/plugins/lef.password-store
omarchy-shell shell rescanPlugins
```

> **Dev loop caveat:** Quickshell's file watcher does not follow symlinks; after edits run `omarchy restart shell`.

Validate at any time with:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/lef.password-store
```

## Configuration

`~/.config/omarchy/password-store/config.json` — hot-reloads:

```json
{
  "primaryVault": "vaultwarden",
  "vaultUrl": "https://vault.example.com"
}
```

| Key | Values | Notes |
|---|---|---|
| `primaryVault` | `bitwarden` \| `vaultwarden` \| `1password` \| `lastpass` | Default: `bitwarden` |
| `vaultUrl` | any https URL | Optional override; **required for Vaultwarden** |
| `browser` | executable name or path | Default: auto-detect (`chromium`, then `brave`) |

## IPC & keybindings

```sh
omarchy-shell lef.password-store status    # JSON state incl. resolved URL + browser
omarchy-shell lef.password-store launch    # open the vault window now
omarchy-shell lef.password-store toggle    # panel
```

Hyprland binding example (`~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER + ALT + P", "Open password vault", "omarchy-shell lef.password-store launch")
```

## External dependencies

- A Chromium-family browser for the app window: `chromium` or `brave` (auto-detected), otherwise any browser via `xdg-open`.
- Network access to your chosen vault provider (the web vault itself handles all cryptography).

## Uninstall

```sh
omarchy plugin remove lef.password-store
```

(If installed via symlink, remove the symlink instead. The vault session lives under `~/.local/share/omarchy/password-store/<provider>-profile`; delete it to log out everywhere at once.)

## License

[MIT](LICENSE)
