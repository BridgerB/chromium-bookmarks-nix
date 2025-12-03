{
  description = "Chromium bookmarks sync tool";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    self,
    nixpkgs,
    systems,
  }: let
    # Helper to iterate over each system (replaces flake-utils)
    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (
        system: f nixpkgs.legacyPackages.${system}
      );
  in {
    apps = eachSystem (pkgs: {
      export = {
        type = "app";
        program = toString (pkgs.writeShellScript "chromium-bookmarks-export" ''
          set -e

          # Auto-detect OS and set Chromium directory
          if [[ "$OSTYPE" == "darwin"* ]]; then
            CHROMIUM_DIR="$HOME/Library/Application Support/Chromium"
          else
            CHROMIUM_DIR="$HOME/.config/chromium"
          fi
          DATA_DIR="./bookmarks"

          if [ ! -d "$CHROMIUM_DIR" ]; then
            echo "Error: Chromium directory not found at $CHROMIUM_DIR"
            exit 1
          fi

          # Create bookmarks directory if it doesn't exist
          mkdir -p "$DATA_DIR"

          echo "Exporting bookmarks from all Chromium profiles..."
          echo ""

          EXPORTED_COUNT=0

          # Function to export a single profile
          export_profile() {
            local PROFILE_DIR="$1"
            local BOOKMARKS_FILE="$PROFILE_DIR/Bookmarks"

            if [ ! -f "$BOOKMARKS_FILE" ]; then
              return
            fi

            # Get profile name from Preferences
            local PREFS_FILE="$PROFILE_DIR/Preferences"
            local PROFILE_NAME=""

            if [ -f "$PREFS_FILE" ]; then
              PROFILE_NAME=$(${pkgs.jq}/bin/jq -r '.profile.name // ""' "$PREFS_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
            fi

            # Fallback to directory name if no custom name
            if [ -z "$PROFILE_NAME" ]; then
              PROFILE_NAME=$(basename "$PROFILE_DIR" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
            fi

            local OUTPUT_FILE="$DATA_DIR/$PROFILE_NAME.json"

            # Validate JSON
            if ! ${pkgs.jq}/bin/jq empty "$BOOKMARKS_FILE" 2>/dev/null; then
              echo "⚠️  Skipping $PROFILE_NAME: Invalid JSON"
              return
            fi

            # Copy the file
            cp "$BOOKMARKS_FILE" "$OUTPUT_FILE"
            echo "✓ Exported: $PROFILE_NAME → $OUTPUT_FILE"
            EXPORTED_COUNT=$((EXPORTED_COUNT + 1))
          }

          # Export Default profile
          if [ -d "$CHROMIUM_DIR/Default" ]; then
            export_profile "$CHROMIUM_DIR/Default"
          fi

          # Export numbered profiles
          for profile_dir in "$CHROMIUM_DIR"/Profile*; do
            if [ -d "$profile_dir" ]; then
              export_profile "$profile_dir"
            fi
          done

          echo ""
          echo "✓ Export complete! Exported $EXPORTED_COUNT profile(s) to $DATA_DIR/"
        '');
      };

      import = {
        type = "app";
        program = toString (pkgs.writeShellScript "chromium-bookmarks-import" ''
          set -e

          # Auto-detect OS and set Chromium directory
          if [[ "$OSTYPE" == "darwin"* ]]; then
            CHROMIUM_DIR="$HOME/Library/Application Support/Chromium"
          else
            CHROMIUM_DIR="$HOME/.config/chromium"
          fi
          DATA_DIR="./bookmarks"

          if [ ! -d "$DATA_DIR" ]; then
            echo "Error: Bookmarks directory not found at $DATA_DIR"
            echo "Nothing to import!"
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

          echo "Importing bookmarks from $DATA_DIR/ to Chromium profiles..."
          echo ""

          IMPORTED_COUNT=0

          # Function to find or create profile for a given name
          import_profile() {
            local JSON_FILE="$1"
            local PROFILE_NAME=$(basename "$JSON_FILE" .json | tr '[:upper:]' '[:lower:]')

            # Validate JSON
            if ! ${pkgs.jq}/bin/jq empty "$JSON_FILE" 2>/dev/null; then
              echo "⚠️  Skipping $PROFILE_NAME: Invalid JSON"
              return
            fi

            # Try to find existing profile with matching name
            local TARGET_DIR=""
            for profile_dir in "$CHROMIUM_DIR"/Default "$CHROMIUM_DIR"/Profile*; do
              if [ -d "$profile_dir" ]; then
                local PREFS_FILE="$profile_dir/Preferences"
                if [ -f "$PREFS_FILE" ]; then
                  local EXISTING_NAME=$(${pkgs.jq}/bin/jq -r '.profile.name // ""' "$PREFS_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
                  if [ "$EXISTING_NAME" = "$PROFILE_NAME" ]; then
                    TARGET_DIR="$profile_dir"
                    break
                  fi
                fi
              fi
            done

            # If no matching profile found, we can't auto-create (Chromium manages profiles)
            if [ -z "$TARGET_DIR" ]; then
              echo "⚠️  No profile found matching '$PROFILE_NAME'"
              echo "   Please create a profile named '$PROFILE_NAME' in Chromium first, or rename the JSON file"
              return
            fi

            local BOOKMARKS_FILE="$TARGET_DIR/Bookmarks"

            # Create backup if exists
            if [ -f "$BOOKMARKS_FILE" ]; then
              local BACKUP="''${BOOKMARKS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
              cp "$BOOKMARKS_FILE" "$BACKUP"
            fi

            # Copy bookmarks
            cp "$JSON_FILE" "$BOOKMARKS_FILE"
            echo "✓ Imported: $PROFILE_NAME → $TARGET_DIR/Bookmarks"
            IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
          }

          # Import all JSON files from bookmarks directory
          for json_file in "$DATA_DIR"/*.json; do
            if [ -f "$json_file" ]; then
              import_profile "$json_file"
            fi
          done

          if [ $IMPORTED_COUNT -eq 0 ]; then
            echo "No bookmarks were imported."
          else
            echo ""
            echo "✓ Import complete! Imported $IMPORTED_COUNT profile(s)"
            echo "  Restart Chromium to see changes."
          fi
        '');
      };

      list = {
        type = "app";
        program = toString (pkgs.writeShellScript "chromium-bookmarks-list" ''
          # Auto-detect OS and set Chromium directory
          if [[ "$OSTYPE" == "darwin"* ]]; then
            CHROMIUM_DIR="$HOME/Library/Application Support/Chromium"
          else
            CHROMIUM_DIR="$HOME/.config/chromium"
          fi

          echo "Chromium Profiles:"
          echo ""

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
          echo "  nix run .#list      List Chromium profiles"
          echo "  nix run .#export    Export ALL profiles → ./bookmarks/*.json"
          echo "  nix run .#import    Import ALL from ./bookmarks/*.json → Chromium"
          echo ""
          echo "Workflow:"
          echo "  1. Run 'nix run .#export' to save all bookmarks to ./bookmarks/"
          echo "  2. Transfer ./bookmarks/ directory to another machine"
          echo "  3. Run 'nix run .#import' to load bookmarks into Chromium"
        '');
      };
    });
  };
}
