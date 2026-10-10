APP_NAME = MacCopy
BUNDLE_ID = com.aking.MacCopy
VERSION = 1.0.0
BUILD_DIR = .build/release
RELEASE_DIR = release
APP_BUNDLE = $(RELEASE_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
DMG_NAME = $(RELEASE_DIR)/$(APP_NAME).dmg

.PHONY: all clean build package dmg run

all: package dmg

build:
	swift build -c release

package: build
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp $(BUILD_DIR)/$(APP_NAME) $(MACOS_DIR)/
	cp Info.plist $(CONTENTS_DIR)/
	cp AppIcon.icns $(RESOURCES_DIR)/
	echo "APPL????" > $(CONTENTS_DIR)/PkgInfo

dmg: package
	rm -f $(DMG_NAME)
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(APP_BUNDLE) -ov -format UDZO $(DMG_NAME)

run: package
	open $(APP_BUNDLE)

clean:
	rm -rf .build
	rm -rf $(RELEASE_DIR)
