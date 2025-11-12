{
  description = "Chromium bookmarks sync tool";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    apps.${system} = {
      push = {
        type = "app";
        program = toString (pkgs.writeShellScript "chromium-bookmarks-push" ''
          set -e

          if [ $# -ne 2 ]; then
            echo "Usage: nix run .#push -- <chromium-bookmarks-path> <git-json-path>"
            echo ""
            echo "Example:"
            echo "  nix run .#push -- ~/.config/chromium/Default/Bookmarks ~/git/bookmarks/work.json"
            exit 1
          fi

          CHROMIUM_PATH="$1"
          GIT_PATH="$2"

          # Expand tilde
          CHROMIUM_PATH="''${CHROMIUM_PATH/#\~/$HOME}"
          GIT_PATH="''${GIT_PATH/#\~/$HOME}"

          echo "Pushing bookmarks..."
          echo "  From: $CHROMIUM_PATH"
          echo "  To:   $GIT_PATH"
          echo ""

          # Check if source exists
          if [ ! -f "$CHROMIUM_PATH" ]; then
            echo "Error: Source file does not exist: $CHROMIUM_PATH"
            exit 1
          fi

          # Validate JSON
          if ! ${pkgs.jq}/bin/jq empty "$CHROMIUM_PATH" 2>/dev/null; then
            echo "Error: Source file is not valid JSON"
            exit 1
          fi

          # Create backup of destination if it exists
          if [ -f "$GIT_PATH" ]; then
            BACKUP="''${GIT_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
            echo "Creating backup: $BACKUP"
            cp "$GIT_PATH" "$BACKUP"
          fi

          # Copy the file
          cp "$CHROMIUM_PATH" "$GIT_PATH"

          echo ""
          echo "✓ Push complete!"
          echo ""

          # Show git diff if in a git repo
          GIT_DIR=$(dirname "$GIT_PATH")
          if git -C "$GIT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
            echo "Git changes:"
            git -C "$GIT_DIR" diff "$GIT_PATH" || true
          fi
        '');
      };

      pull = {
        type = "app";
        program = toString (pkgs.writeShellScript "chromium-bookmarks-pull" ''
          set -e

          if [ $# -ne 2 ]; then
            echo "Usage: nix run .#pull -- <git-json-path> <chromium-bookmarks-path>"
            echo ""
            echo "Example:"
            echo "  nix run .#pull -- ~/git/bookmarks/work.json ~/.config/chromium/Default/Bookmarks"
            exit 1
          fi

          GIT_PATH="$1"
          CHROMIUM_PATH="$2"

          # Expand tilde
          GIT_PATH="''${GIT_PATH/#\~/$HOME}"
          CHROMIUM_PATH="''${CHROMIUM_PATH/#\~/$HOME}"

          echo "Pulling bookmarks..."
          echo "  From: $GIT_PATH"
          echo "  To:   $CHROMIUM_PATH"
          echo ""

          # Check if source exists
          if [ ! -f "$GIT_PATH" ]; then
            echo "Error: Source file does not exist: $GIT_PATH"
            exit 1
          fi

          # Validate JSON
          if ! ${pkgs.jq}/bin/jq empty "$GIT_PATH" 2>/dev/null; then
            echo "Error: Source file is not valid JSON"
            exit 1
          fi

          # Warn if Chromium is running
          if pgrep -x chromium > /dev/null; then
            echo "Warning: Chromium is currently running!"
            echo "Changes may not take effect until you restart Chromium."
            echo ""
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
              echo "Cancelled."
              exit 0
            fi
          fi

          # Create backup of destination if it exists
          if [ -f "$CHROMIUM_PATH" ]; then
            BACKUP="''${CHROMIUM_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
            echo "Creating backup: $BACKUP"
            cp "$CHROMIUM_PATH" "$BACKUP"
          fi

          # Create directory if it doesn't exist
          mkdir -p "$(dirname "$CHROMIUM_PATH")"

          # Copy the file
          cp "$GIT_PATH" "$CHROMIUM_PATH"

          echo ""
          echo "✓ Pull complete!"
          echo "  Restart Chromium to see changes."
        '');
      };

      list = {
        type = "app";
        program = toString (pkgs.writeShellScript "chromium-bookmarks-list" ''
          echo "Chromium Profiles:"
          echo ""

          CHROMIUM_DIR="$HOME/.config/chromium"

          if [ ! -d "$CHROMIUM_DIR" ]; then
            echo "Error: Chromium directory not found at $CHROMIUM_DIR"
            exit 1
          fi

          # List Default profile
          if [ -f "$CHROMIUM_DIR/Default/Bookmarks" ]; then
            echo "📁 Default"
            echo "   Path: ~/.config/chromium/Default/Bookmarks"
            echo ""
          fi

          # List numbered profiles
          for profile_dir in "$CHROMIUM_DIR"/Profile*; do
            if [ -d "$profile_dir" ] && [ -f "$profile_dir/Bookmarks" ]; then
              profile_name=$(basename "$profile_dir")
              echo "📁 $profile_name"
              echo "   Path: ~/.config/chromium/\"$profile_name\"/Bookmarks"
              echo ""
            fi
          done
        '');
      };

      # Default app shows help
      default = {
        type = "app";
        program = toString (pkgs.writeShellScript "chromium-bookmarks-help" ''
          echo "Chromium Bookmarks Sync Tool"
          echo ""
          echo "Available commands:"
          echo "  nix run .#list                                  List Chromium profiles"
          echo "  nix run .#push -- <chromium-path> <git-path>    Push bookmarks from Chromium to git"
          echo "  nix run .#pull -- <git-path> <chromium-path>    Pull bookmarks from git to Chromium"
          echo ""
          echo "Examples:"
          echo "  nix run .#list"
          echo "  nix run .#push -- ~/.config/chromium/Default/Bookmarks ~/git/bookmarks/work.json"
          echo "  nix run .#pull -- ~/git/bookmarks/home.json ~/.config/chromium/\"Profile 1\"/Bookmarks"
        '');
      };
    };
  };
}
