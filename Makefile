# Thin wrappers around Meson (Ninja backend). Scripts stay in make for portability.
#
# Native Linux:  make check        (valac -C via ninja)
# Windows exe:  make win          (cross meson + ninja)
# Metadata:      make vendor
# Generator:     make regen
# Drift check:   make check-regen

BUILD_DIR     ?= build
BUILD_WIN_DIR ?= build-win
CROSS_FILE    ?= cross/mingw-w64.ini

MESON_SETUP   = meson setup $(BUILD_DIR)
MESON_SETUP_WIN = meson setup $(BUILD_WIN_DIR) --cross-file $(CROSS_FILE)

.PHONY: all check win vendor regen check-regen clean setup setup-win

all: check

setup:
	@if [ -f $(BUILD_DIR)/build.ninja ]; then \
		meson setup --reconfigure $(BUILD_DIR); \
	else \
		$(MESON_SETUP); \
	fi

setup-win:
	@if [ -f $(BUILD_WIN_DIR)/build.ninja ]; then \
		meson setup --reconfigure $(BUILD_WIN_DIR) --cross-file $(CROSS_FILE); \
	else \
		$(MESON_SETUP_WIN); \
	fi

check: setup
	meson compile -C $(BUILD_DIR) compile-check

win: setup-win
	meson compile -C $(BUILD_WIN_DIR) hello-window
	@echo "Built $(BUILD_WIN_DIR)/hello-window.exe (run on Windows)"

vendor:
	./scripts/vendor-win32json.sh

regen: setup vendor
	meson compile -C $(BUILD_DIR) generate-binding regen

check-regen: setup vendor
	meson compile -C $(BUILD_DIR) generate-binding check-regen

clean:
	rm -rf $(BUILD_DIR) $(BUILD_WIN_DIR)
