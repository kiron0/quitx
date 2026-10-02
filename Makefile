APP_NAME = QuitX
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

BUNDLE_ID = io.coreify.quitx
VERSION = $(shell awk -F'"' '/"version"/ { print $$4; exit }' package.json)
APP_DIR = .build/$(APP_NAME).app
CONTENTS = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES_DIR = $(CONTENTS)/Resources
SWIFT_FLAGS ?=

.PHONY: all build bundle run clean test ship

## Default: build + bundle
all: bundle

## Compile with SPM (release)
build:
	@swift build -c release --build-system native $(SWIFT_FLAGS) 2>&1 | sed '/warning:.*build-system native.*deprecated/d'

## Wrap binary in a minimal .app bundle
bundle: build
	@echo "▶ Creating $(APP_NAME).app bundle..."
	@rm -rf $(APP_DIR)
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@chmod +x $(MACOS_DIR)/$(APP_NAME)
	@cp Support/Info.plist $(CONTENTS)/Info.plist
	@cp Support/Icons/*.png Support/Icons/*.icns $(RESOURCES_DIR)/
	@cp Support/Sounds/*.aiff $(RESOURCES_DIR)/
	@cp Support/Assets.car $(RESOURCES_DIR)/
	@/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" $(CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(CONTENTS)/Info.plist
	@codesign --force --deep --sign - $(APP_DIR)
	@echo "✅ Bundle ready: $(APP_DIR)"

## Create DMG installer
dmg: bundle
	@echo "▶ Creating $(APP_NAME).dmg..."
	@rm -rf .build/dmg-staging
	@mkdir -p .build/dmg-staging
	@cp -R $(APP_DIR) .build/dmg-staging/
	@ln -s /Applications .build/dmg-staging/Applications
	@hdiutil create -volname "$(APP_NAME)" -srcfolder .build/dmg-staging -ov -format UDZO .build/$(APP_NAME).dmg
	@rm -rf .build/dmg-staging
	@echo "✅ DMG ready: .build/$(APP_NAME).dmg"

## Launch the app bundle
run: bundle
	@echo "▶ Launching $(APP_NAME)..."
	@open $(APP_DIR)

## Build debug + run binary directly (fast iteration, no bundle)
dev:
	@swift build --build-system native $(SWIFT_FLAGS) 2>&1 | sed '/warning:.*build-system native.*deprecated/d'
	@.build/debug/$(APP_NAME)

## Run tests
test:
	@swift test --build-system native $(SWIFT_FLAGS) 2>&1 | sed '/warning:.*build-system native.*deprecated/d'

## Test, bundle, kill, install, and open in one go
ship:
	@Scripts/ship.sh

## Clean build artifacts
clean:
	@swift package clean
	@rm -rf .build/$(APP_NAME).app
	@echo "✅ Cleaned"

## Print project info
info:
	@echo "App:      $(APP_NAME)"
	@echo "Bundle:   $(BUNDLE_ID)"
	@echo "Version:  $(VERSION)"
	@swift --version
