# WinUI3 sandbox — MSVC primary (see build-msvc.ps1).
#
#   make              # MSVC → winui3-sandbox.exe
#   make mingw        # optional MinGW compare build
#   make run          # MSVC build + agent run script on Windows

REPO_ROOT ?= ..
SDK       := $(REPO_ROOT)/build/vendor/winui3

.PHONY: all msvc mingw clean run check-sdk

all: msvc

check-sdk:
	@test -f "$(SDK)/include/MddBootstrap.h" || \
		(echo "missing $(SDK) — run: cd $(REPO_ROOT) && ./scripts/vendor-winui3-sdk.sh" >&2; exit 1)

msvc: check-sdk
	powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
		-File build-msvc.ps1

mingw: check-sdk main.cpp
	g++ -std=c++20 -fcoroutines -Wno-deprecated-declarations \
		-I$(SDK)/include -I$(SDK)/cppwinrt \
		-o winui3-sandbox-mingw.exe main.cpp \
		-L$(SDK)/lib/x64 -lMicrosoft.WindowsAppRuntime.Bootstrap \
		-lole32 -loleaut32 -lruntimeobject -luuid \
		-mwindows -municode -static-libgcc -static-libstdc++
	cp -f "$(SDK)/bin/x64/Microsoft.WindowsAppRuntime.Bootstrap.dll" .
	@echo "OK: winui3-sandbox-mingw.exe"

run: msvc
	powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
		-File build-msvc.ps1 -Run

clean:
	rm -f winui3-sandbox.exe winui3-sandbox-mingw.exe *.obj winui3-sandbox.log
