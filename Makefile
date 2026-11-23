PROJECT_NAME ?= kyma
APP_NAME := $(shell sed -n "s/^ *name *= *'\([^']*\)'.*/\1/p" build.lua | head -n 1)
LOVE_VERSION ?= 11.5
LOVE_BUILD_VERSION ?= 1.0
BUILD_TOOL_DIR ?= love-build
UNAME := $(shell uname -s)
ifeq ($(UNAME),Darwin)
LOVE_BUILD_OS := macos
BUILD_TOOL ?= $(BUILD_TOOL_DIR)/love-build.app/Contents/MacOS/love
else
LOVE_BUILD_OS := linux
BUILD_TOOL ?= $(BUILD_TOOL_DIR)/AppRun
endif
APPIMAGETOOL ?= appimagetool.AppImage
DIST_DIR ?= dist
BUILD_DIR ?= build
VERSION := $(shell sed -n "s/^ *version *= *'\([^']*\)'.*/\1/p" build.lua | head -n 1)
MAIN_LUA := $(shell find . -maxdepth 1 -name "main.lua" | head -n 1)
ifeq ($(MAIN_LUA),)
$(error "main.lua unknow")
endif

all: build

build: $(BUILD_TOOL)
	@mkdir -p $(DIST_DIR)
	@$(BUILD_TOOL) $(abspath $(MAIN_LUA))

build-windows build-macos build-linux: $(BUILD_TOOL)
	@mkdir -p $(DIST_DIR)
	@$(BUILD_TOOL) $(abspath $(MAIN_LUA)) $(@:build-%=%)

$(BUILD_TOOL):
	@mkdir -p $(BUILD_TOOL_DIR)
	@curl -sSL -o $(BUILD_TOOL_DIR).zip "https://github.com/ellraiser/love-build/releases/download/v$(LOVE_BUILD_VERSION)/love-build-$(LOVE_BUILD_VERSION)-$(LOVE_BUILD_OS).zip"
	@unzip -q -o $(BUILD_TOOL_DIR).zip -d $(BUILD_TOOL_DIR)
	@rm -f $(BUILD_TOOL_DIR).zip
	@chmod -R u+rwX $(BUILD_TOOL_DIR)

$(APPIMAGETOOL):
	@curl -sSL -o $(APPIMAGETOOL) "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
	@chmod +x $(APPIMAGETOOL)

standalone: fclean build $(APPIMAGETOOL)
	@rm -rf $(BUILD_DIR)/$(PROJECT_NAME).AppDir
	@mkdir -p $(BUILD_DIR)/$(PROJECT_NAME).AppDir/lib
	@unzip -q -o $(DIST_DIR)/$(VERSION)/$(APP_NAME)-linux.zip -d $(BUILD_DIR)/$(PROJECT_NAME).AppDir
	@chmod -R u+rwX,go+rX,go-w $(BUILD_DIR)/$(PROJECT_NAME).AppDir
	@chmod a+rx $(BUILD_DIR)/$(PROJECT_NAME).AppDir/AppRun $(BUILD_DIR)/$(PROJECT_NAME).AppDir/bin/*
	@ARCH=x86_64 ./$(APPIMAGETOOL) $(BUILD_DIR)/$(PROJECT_NAME).AppDir ./$(PROJECT_NAME)
	@chmod +x ./$(PROJECT_NAME)

run:
	@love .

test:
	@love . --test

clean:
	@rm -rf $(DIST_DIR) $(BUILD_DIR) $(BUILD_TOOL_DIR)
	@rm -f $(APPIMAGETOOL)
	@find . -name "*.love" -type f -delete

fclean: clean
	@rm -f ./$(PROJECT_NAME)

dist: build
	@ls -1 $(DIST_DIR)/$(VERSION)/$(APP_NAME)-*.zip

.PHONY: all build build-windows build-macos build-linux run test clean fclean dist standalone
