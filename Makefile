APP_NAME := Shike
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SOURCES := Sources/main.m Sources/ShikeCore.m
CORE_SOURCE := Sources/ShikeCore.m
TEST_SOURCE := Tests/ShikeCoreTests.m
APP_TEST_SOURCE := Tests/ShikeAppTests.m
APP_TEST_BINARY := $(BUILD_DIR)/tests/ShikeAppTests
ICON_TOOL_SOURCE := Tools/CreateIcns.m
ICON_TOOL := $(BUILD_DIR)/tools/CreateIcns
COMMON_FLAGS := -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 -I Sources
APP_ARCH_FLAGS := -arch arm64 -arch x86_64
APP_FRAMEWORKS := -framework Cocoa -framework ServiceManagement -framework UserNotifications
TEST_FRAMEWORKS := -framework Foundation

.PHONY: all app test icon run release clean

all: test app

app:
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	xcrun clang $(APP_ARCH_FLAGS) $(COMMON_FLAGS) $(SOURCES) $(APP_FRAMEWORKS) -o "$(MACOS_DIR)/$(APP_NAME)"
	cp Resources/Info.plist "$(CONTENTS_DIR)/Info.plist"
	cp Resources/Shike.icns "$(RESOURCES_DIR)/Shike.icns"
	chmod +x "$(MACOS_DIR)/$(APP_NAME)"
	codesign --force --deep --sign - "$(APP_DIR)"
	@echo "✅ 已生成 $(APP_DIR)"

test:
	mkdir -p "$(BUILD_DIR)/tests"
	xcrun clang $(COMMON_FLAGS) $(CORE_SOURCE) $(TEST_SOURCE) $(TEST_FRAMEWORKS) -o "$(BUILD_DIR)/tests/ShikeCoreTests"
	"$(BUILD_DIR)/tests/ShikeCoreTests"
	xcrun clang $(COMMON_FLAGS) $(APP_TEST_SOURCE) $(CORE_SOURCE) $(APP_FRAMEWORKS) -o "$(APP_TEST_BINARY)"
	"$(APP_TEST_BINARY)"

icon:
	mkdir -p "$(BUILD_DIR)/tools"
	xcrun clang -fobjc-arc -mmacosx-version-min=13.0 $(ICON_TOOL_SOURCE) \
		-framework Foundation -framework CoreGraphics -framework ImageIO \
		-framework UniformTypeIdentifiers -o "$(ICON_TOOL)"
	"$(ICON_TOOL)" Resources/AppIcon.iconset Resources/Shike.icns

run: app
	open "$(APP_DIR)"

release:
	./Scripts/package-release.sh

clean:
	rm -rf "$(BUILD_DIR)"
