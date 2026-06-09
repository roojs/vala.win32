/* Phase 9b: WinUI3 hello window via C++/WinRT (bootstrap + Application + Window + TextBlock). */

#include "win32-ui-winui3-host.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef GetCurrentTime

#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>
#include <winrt/base.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>

using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;

namespace {

void
show_error_message (const wchar_t* message)
{
	MessageBoxW (nullptr, message, L"vala.win32 WinUI3", MB_OK | MB_ICONERROR);
}

void
show_bootstrap_failure (HRESULT hr)
{
	wchar_t buf[640];
	swprintf (
		buf,
		640,
		L"MddBootstrapInitialize2 failed: 0x%08X\n\n"
		L"This app needs Windows App Runtime 2.1.x (built for 2.1.3).\n\n"
		L"Re-run the build (installs runtime automatically):\n"
		L"  ./scripts/build-win.sh\n\n"
		L"Or install manually:\n"
		L"  ./scripts/install-winui3-runtime.sh",
		(unsigned) hr);
	show_error_message (buf);
}

void
xaml_check_process_requirements (void)
{
	using pfn_t = void (WINAPI*) (void);
	const HMODULE module = LoadLibraryW (L"Microsoft.ui.xaml.dll");
	if (!module) {
		return;
	}
	const auto pfn = reinterpret_cast<pfn_t> (
		GetProcAddress (module, "XamlCheckProcessRequirements"));
	if (pfn) {
		pfn ();
	}
	FreeLibrary (module);
}

struct HelloApp : ApplicationT<HelloApp>
{
	HelloApp () = default;

	void
	OnLaunched (LaunchActivatedEventArgs const&)
	{
		m_window = Window ();
		TextBlock text;
		text.Text (L"Hello from Vala + WinUI 3");
		m_window.Content (text);
		m_window.Title (L"vala.win32 WinUI3");
		m_window.Activate ();
	}

private:
	Window m_window{ nullptr };
};

} /* anonymous namespace */

extern "C" int
winui3_run_hello_window (void)
{
	try {
		init_apartment (apartment_type::single_threaded);

		/* Empty min_version: accept any installed 2.1.x runtime >= major.minor. */
		const PACKAGE_VERSION min_version{};

		/* Runtime is installed by scripts/install-winui3-runtime.sh during build-win.sh */
		const HRESULT bootstrap_hr = MddBootstrapInitialize2 (
			WINDOWSAPPSDK_RELEASE_MAJORMINOR,
			WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
			min_version,
			MddBootstrapInitializeOptions_None);
		if (FAILED (bootstrap_hr)) {
			show_bootstrap_failure (bootstrap_hr);
			return (int) bootstrap_hr;
		}

		xaml_check_process_requirements ();

		Application app{ nullptr };
		Application::Start ([&app] (auto&&) {
			app = winrt::make<HelloApp> ();
		});

		MddBootstrapShutdown ();
		return 0;
	} catch (hresult_error const& ex) {
		const auto code = ex.code ().value;
		wchar_t buf[128];
		swprintf (
			buf,
			128,
			L"WinUI3 HRESULT error: 0x%08x",
			(unsigned) code);
		show_error_message (buf);
		return (int) code;
	} catch (...) {
		show_error_message (L"WinUI3 unknown error");
		return -1;
	}
}
