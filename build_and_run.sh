#!/bin/bash

# Build in release mode
echo "Building app..."
swift build -c release

# Create app bundle
APP_DIR="../ProductScout.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/release/ProductScout "$APP_DIR/Contents/MacOS/"

# Copy icon if it exists
if [ -f "ProductScout.icns" ]; then
    cp ProductScout.icns "$APP_DIR/Contents/Resources/"
    echo "Icon added to app bundle"
elif [ -f "Tracker.icns" ]; then
    # Fallback to old name if new doesn't exist yet
    cp Tracker.icns "$APP_DIR/Contents/Resources/ProductScout.icns"
    echo "Icon added to app bundle"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ProductScout</string>
    <key>CFBundleIdentifier</key>
    <string>com.productscout.app</string>
    <key>CFBundleName</key>
    <string>ProductScout</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>ProductScout</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "App built successfully!"
echo "Launching app..."
open "$APP_DIR"