# chromium-bookmarks-nix

Transfer Chromium bookmarks between machines using JSON files. Chromium replaces
symlinks with regular files, so this tool provides simple export/import
commands.

## Usage

**List profiles:**

```bash
nix run .#list
```

**Export (get bookmarks OUT of Chromium):**

```bash
nix run .#export
```

This exports ALL Chromium profiles to `./bookmarks/<profile-name>.json` files.

**Import (put bookmarks INTO Chromium):**

```bash
nix run .#import
```

This imports ALL JSON files from `./bookmarks/` into matching Chromium profiles.
If a profile doesn't exist, you'll need to create it in Chromium first.

## Workflow

1. **On Linux machine:**
   ```bash
   nix run .#export
   ```

2. **Transfer to MacBook:**
   ```bash
   scp -r bookmarks/ macbook:~/chromium-bookmarks-nix/
   # or use USB, cloud storage, etc.
   ```

3. **On MacBook:**
   ```bash
   nix run .#import
   ```

## Features

- Automatically exports/imports all profiles
- JSON validation and timestamped backups
- Chromium running detection
- Profile name matching (case-insensitive)
- Bookmarks directory is gitignored by default
