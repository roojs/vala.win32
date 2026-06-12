WinUI3 hello+button = upstream sample, not hand-rolled main.cpp.

Source:  ~/git/winui3-without-xaml  (sotanakamura)
Build:   ./scripts/agent-remote-winui3-reference-build.sh
Run:     C:\msys64\tmp\winui3-without-xaml\x64\Release\winui3-without-xaml.exe

The old build-msvc.ps1 / main.cpp sandbox only proved labels/bootstrap;
it cannot deploy themeresources.xaml (needs WindowsAppSDKSelfContained).

Open winui3-without-xaml.sln in Visual Studio on Windows for local dev.
