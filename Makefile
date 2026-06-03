# Thin wrappers around Meson. Default: regen vapi + build hello-window.exe in build/

BUILD_DIR ?= build

.PHONY: all vendor clean setup

all: setup
	meson compile -C $(BUILD_DIR)

setup:
	@if [ -f $(BUILD_DIR)/build.ninja ]; then \
		meson setup --reconfigure $(BUILD_DIR); \
	else \
		meson setup $(BUILD_DIR); \
	fi

vendor:
	./scripts/vendor-win32json.sh

clean:
	rm -rf $(BUILD_DIR) build-win
