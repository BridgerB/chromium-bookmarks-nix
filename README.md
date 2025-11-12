# chromium-bookmarks-nix

Sync Chromium bookmarks to git-tracked JSON files. Chromium replaces symlinks
with regular files, so this tool provides manual push/pull commands for version
control.

## Usage

**List profiles:**

```bash
nix run .#list
```

**Push (Chromium → Git):**

```bash
nix run .#push -- ~/.config/chromium/"Profile 1"/Bookmarks ~/git/bookmarks/home.json
```

**Pull (Git → Chromium):**

```bash
nix run .#pull -- ~/git/bookmarks/home.json ~/.config/chromium/"Profile 1"/Bookmarks
```

## Features

- JSON validation and timestamped backups
- Git diff display after push
- Chromium running detection
