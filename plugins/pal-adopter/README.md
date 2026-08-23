# pal-adopter

Agent tooling for apps that build **on** Pal. Install it in your *app's* repository — not in Pal's.

It ships two skills and one reference document:

| Skill | Loads when |
|---|---|
| `/pal-adopter:pal` | You work in a project that imports Pal products — the conventions: mechanisms vs values, the `Loader`/`ViewState` screen shape, app-layer naming, the three feedback channels |
| `/pal-adopter:pal-screen` | You add a screen or feature — the canonical slice, in order, Domain through composition root |

`reference/ADOPTERS.md` is the full adopter brief, loaded on demand. It is a symlink to [`Documentation/ADOPTERS.md`](../../Documentation/ADOPTERS.md) in this repository, so the plugin can never carry a stale copy.

## Install

```bash
/plugin marketplace add Mesrine23/pal-mvvm-foundation
/plugin install pal-adopter@pal-foundation
```

## Install for everyone on the app

Commit this to your app's `.claude/settings.json`. Teammates get the plugin once they trust the folder — no separate install step:

```json
{
  "extraKnownMarketplaces": {
    "pal-foundation": {
      "source": { "source": "github", "repo": "Mesrine23/pal-mvvm-foundation" }
    }
  },
  "enabledPlugins": { "pal-adopter@pal-foundation": true }
}
```

## Versioning

The marketplace is served from Pal's `main` branch, which carries **tagged releases only** — so you track the latest release by default, never in-progress work on `develop`. The plugin's `version` is bumped to the Pal version it describes on every release, which is what triggers `/plugin update` for existing users.

To hold a specific release instead, add a `ref` to the source above naming the tag (for example `"ref": "v1.5.0"`) — the same discipline as pinning the package itself.

## Not for contributors

If you are working **on** Pal rather than on an app, you want the repository's own [`AGENTS.md`](../../AGENTS.md) and `.claude/` tooling instead. This plugin deliberately says nothing about Pal's internal rules.
