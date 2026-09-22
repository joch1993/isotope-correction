#!/bin/bash
# Double-click to open the isotope app in your browser.
# Terminal minimizes while running, then closes when you close the browser tab.
#
# Keep this file next to app.R, OR put an alias/symlink of it on the Desktop —
# this script resolves to the real file location so app.R is still found.
set -e

# Resolve symlinks so a Desktop shortcut still finds app.R
SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
APP_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
cd "$APP_DIR"

if [ ! -f "$APP_DIR/app.R" ]; then
  echo "app.R not found next to the real launcher:"
  echo "  $APP_DIR"
  read -r -p "Press Enter to close..."
  exit 1
fi

if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found. Install R or add it to PATH."
  read -r -p "Press Enter to close..."
  exit 1
fi

# Minimize this Terminal window after a short delay
(sleep 0.8
 osascript -e 'tell application "Terminal" to set miniaturized of front window to true' \
   >/dev/null 2>&1) &

echo "Starting isotope_app (first run may install packages; close the browser tab to quit) ..."
Rscript --vanilla -e \
  "options(isotope_app.quit_on_close = TRUE); shiny::runApp('.', launch.browser = TRUE, host = '127.0.0.1')"

# Close this Terminal window when the app stops
osascript >/dev/null 2>&1 <<'EOF'
tell application "Terminal"
  try
    close front window saving no
  end try
end tell
EOF
