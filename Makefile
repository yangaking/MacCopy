APP_NAME = MacCopy
BUNDLE_ID = com.aking.MacCopy
VERSION = 1.0.0
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: all clean build package run

all: package

build:
	swift build -c release

package: build
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp $(BUILD_DIR)/$(APP_NAME) $(MACOS_DIR)/
	cp Info.plist $(CONTENTS_DIR)/
	cp AppIcon.icns $(RESOURCES_DIR)/
	echo "APPL????" > $(CONTENTS_DIR)/PkgInfo

run: package
	open $(APP_BUNDLE)

clean:
	rm -rf .build
	rm -rf $(APP_BUNDLE)
