APP_NAME = QuitX
BUNDLE_ID = io.coreify.quitx
VERSION = 1.0.0
APP_DIR = .build/$(APP_NAME).app
CONTENTS = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES_DIR = $(CONTENTS)/Resources

.PHONY: all build bundle run clean test

## Default: build + bundle
all: bundle

## Compile with SPM (release)
build:
	swift build -c release --build-system native

## Wrap binary in a minimal .app bundle
bundle: build
	@echo "▶ Creating $(APP_NAME).app bundle..."
	@rm -rf $(APP_DIR)
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@chmod +x $(MACOS_DIR)/$(APP_NAME)
	@cp Support/Info.plist $(CONTENTS)/Info.plist
	@cp Support/Icons/* $(RESOURCES_DIR)/ 2>/dev/null || true
	@cp Support/Sounds/* $(RESOURCES_DIR)/ 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" $(CONTENTS)/Info.plist 2>/dev/null || true
	@echo "✅ Bundle ready: $(APP_DIR)"

## Launch the app bundle
run: bundle
	@echo "▶ Launching $(APP_NAME)..."
	@open $(APP_DIR)

## Build debug + run binary directly (fast iteration, no bundle)
dev:
	@swift build --build-system native 2>&1
	@.build/debug/$(APP_NAME)

## Run tests
test:
	@swift test --build-system native

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
