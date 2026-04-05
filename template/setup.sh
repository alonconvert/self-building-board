#!/bin/bash
# setup.sh — Initialize a new project using the Claude Project System.
# Usage: bash setup.sh <project-name>
#   e.g.: bash setup.sh my-saas-app
#
# Run this from the dashboard directory after copying the template.

set -e

PROJECT_NAME="${1:?Usage: bash setup.sh <project-name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "=========================================="
echo "  Setting up: ${PROJECT_NAME}"
echo "=========================================="
echo ""

# 1. Create folder structure
echo "[1/5] Creating folder structure..."
mkdir -p docs/kanban docs/modules
echo "  Created docs/kanban/ and docs/modules/"

# 2. Make scripts executable
echo "[2/5] Setting permissions..."
chmod +x build-module.sh
echo "  build-module.sh is executable"

# 3. Compile and install ConvertyBuild.app (URL scheme handler)
echo "[3/5] Installing URL scheme handler..."
APP_DIR="$HOME/Applications/ConvertyBuild.app"

cat > /tmp/converty-build-handler.swift << SWIFT
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let module = url.host ?? url.path.replacingOccurrences(of: "/", with: "")
            guard !module.isEmpty else { continue }

            let script = """
            tell application "Terminal"
                activate
                do script "cd '\(ProcessInfo.processInfo.environment["DASHBOARD_DIR"] ?? "${SCRIPT_DIR}")' && bash build-module.sh \(module)"
            end tell
            """

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            try? task.run()
            task.waitUntilExit()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
SWIFT

# Compile
swiftc -o /tmp/ConvertyBuild /tmp/converty-build-handler.swift -framework Cocoa 2>/dev/null

# Create app bundle
mkdir -p "$APP_DIR/Contents/MacOS"
cp /tmp/ConvertyBuild "$APP_DIR/Contents/MacOS/ConvertyBuild"

# Write Info.plist with URL scheme
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>ConvertyBuild</string>
	<key>CFBundleIdentifier</key>
	<string>com.converty.build-launcher</string>
	<key>CFBundleName</key>
	<string>ConvertyBuild</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>LSBackgroundOnly</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>Converty Build Module</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>converty-build</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

# Register with macOS
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R -f "$APP_DIR"
echo "  ConvertyBuild.app installed and URL scheme registered"

# 4. Initialize git repo
echo "[4/5] Initializing git repo..."
if [ ! -d .git ]; then
  git init
  git add -A
  git commit -m "Initial project setup via Claude Project System"
  echo "  Git repo initialized"
else
  echo "  Git repo already exists, skipping"
fi

# 5. Summary
echo ""
echo "[5/5] Done!"
echo ""
echo "=========================================="
echo "  ${PROJECT_NAME} is ready"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Start a Claude Code session and run /grill-me"
echo "  2. Create kanban files in docs/kanban/"
echo "  3. Fill in modules.conf with your module mappings"
echo "  4. Run: node generate.js"
echo "  5. Deploy: git push && npx vercel deploy --prod --yes"
echo "  6. Click 'Build ALL' on the dashboard"
echo ""
