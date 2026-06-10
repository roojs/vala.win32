/* Phase 9: WinUI3 demos via C++/WinRT (bootstrap + Application + controls). */

#include "win32-ui-winui3-host.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef GetCurrentTime

#include <cstdarg>
#include <cstdio>
#include <cstring>

#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Windows.UI.Text.h>
#include <winrt/Windows.UI.Xaml.Interop.h>

using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Windows::UI::Xaml::Interop;

namespace {

HANDLE g_winui3_log_handle{ INVALID_HANDLE_VALUE };
bool g_winui3_console_attached{ false };

void
winui3_log_bytes (const char* text, size_t len)
{
	if (text == nullptr || len == 0) {
		return;
	}
	fwrite (text, 1, len, stderr);
	fflush (stderr);
	if (g_winui3_log_handle != INVALID_HANDLE_VALUE) {
		DWORD written = 0;
		WriteFile (g_winui3_log_handle, text, (DWORD) len, &written, nullptr);
	}
}

void
winui3_logf (const char* fmt, ...)
{
	char buf[1024];
	va_list args;
	va_start (args, fmt);
	vsnprintf (buf, sizeof (buf), fmt, args);
	va_end (args);
	winui3_log_bytes (buf, strlen (buf));
}

void
winui3_log_wide (const wchar_t* text)
{
	if (text == nullptr) {
		return;
	}
	char utf8[1024];
	const int n = WideCharToMultiByte (
		CP_UTF8,
		0,
		text,
		-1,
		utf8,
		(int) sizeof (utf8),
		nullptr,
		nullptr);
	if (n > 0) {
		winui3_log_bytes (utf8, (size_t) (n - 1));
	}
}

void
winui3_setup_stdio (void)
{
	if (AttachConsole (ATTACH_PARENT_PROCESS)) {
		g_winui3_console_attached = true;
	} else if (AllocConsole ()) {
		g_winui3_console_attached = true;
		SetConsoleTitleW (L"vala.win32 WinUI3 debug");
	}

	if (g_winui3_console_attached) {
		(void) freopen ("CONOUT$", "w", stdout);
		(void) freopen ("CONOUT$", "w", stderr);
		(void) freopen ("CONIN$", "r", stdin);
	}

	wchar_t log_path[MAX_PATH]{};
	if (GetModuleFileNameW (nullptr, log_path, MAX_PATH) == 0) {
		winui3_logf ("[winui3] GetModuleFileNameW failed\n");
		return;
	}
	wchar_t* slash = wcsrchr (log_path, L'\\');
	if (slash != nullptr) {
		slash[1] = L'\0';
	}
	wcscat (log_path, L"winui3-debug.log");
	g_winui3_log_handle = CreateFileW (
		log_path,
		FILE_APPEND_DATA,
		FILE_SHARE_READ,
		nullptr,
		OPEN_ALWAYS,
		FILE_ATTRIBUTE_NORMAL,
		nullptr);
	if (g_winui3_log_handle == INVALID_HANDLE_VALUE) {
		winui3_logf ("[winui3] could not open log file\n");
		return;
	}
	winui3_logf ("[winui3] log file: ");
	winui3_log_wide (log_path);
	winui3_logf ("\n");
}

void
winui3_log_error (const char* message)
{
	winui3_logf ("[winui3] ERROR: %s\n", message);
}

void
winui3_log_hresult_utf8 (const char* context, winrt::hresult const hr)
{
	winui3_logf (
		"[winui3] ERROR: %s (HRESULT 0x%08x)\n",
		context,
		(unsigned) hr.value);
}

void
winui3_log_hresult_step (
	const wchar_t* step,
	winrt::hresult const hr,
	winrt::hstring const& message = {})
{
	char step_utf8[256];
	const int n = WideCharToMultiByte (
		CP_UTF8,
		0,
		step,
		-1,
		step_utf8,
		(int) sizeof (step_utf8),
		nullptr,
		nullptr);
	if (n > 0) {
		winui3_log_hresult_utf8 (step_utf8, hr);
	} else {
		winui3_log_hresult_utf8 ("<step>", hr);
	}
	if (!message.empty ()) {
		winui3_logf ("[winui3] message: ");
		winui3_log_wide (message.c_str ());
		winui3_logf ("\n");
	}
}

LONG WINAPI
winui3_unhandled_exception_filter (EXCEPTION_POINTERS* info)
{
	if (info != nullptr && info->ExceptionRecord != nullptr) {
		winui3_logf (
			"[winui3] FATAL: unhandled exception 0x%08lx\n",
			info->ExceptionRecord->ExceptionCode);
	}
	return EXCEPTION_EXECUTE_HANDLER;
}

void
log_bootstrap_failure (HRESULT hr)
{
	winui3_logf (
		"[winui3] ERROR: MddBootstrapInitialize2 failed 0x%08X "
		"(re-run ./scripts/build-win.sh)\n",
		(unsigned) hr);
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

template<typename AppT>
int
run_winui3_application ()
{
	try {
		winui3_setup_stdio ();
		SetUnhandledExceptionFilter (winui3_unhandled_exception_filter);
		winui3_logf ("[winui3] starting application\n");
		init_apartment (apartment_type::single_threaded);

		const PACKAGE_VERSION min_version{};
		const HRESULT bootstrap_hr = MddBootstrapInitialize2 (
			WINDOWSAPPSDK_RELEASE_MAJORMINOR,
			WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
			min_version,
			MddBootstrapInitializeOptions_None);
		if (FAILED (bootstrap_hr)) {
			log_bootstrap_failure (bootstrap_hr);
			return (int) bootstrap_hr;
		}
		winui3_logf (
			"[winui3] bootstrap OK (SDK 0x%08x tag %ls)\n",
			(unsigned) WINDOWSAPPSDK_RELEASE_MAJORMINOR,
			WINDOWSAPPSDK_RELEASE_VERSION_TAG_W);

		xaml_check_process_requirements ();
		winui3_logf ("[winui3] XamlCheckProcessRequirements done\n");

		Application app{ nullptr };
		Application::Start ([&app] (auto&&) {
			app = winrt::make<AppT> ();
		});

		MddBootstrapShutdown ();
		winui3_logf ("[winui3] application exited normally\n");
		return 0;
	} catch (hresult_error const& ex) {
		winui3_log_hresult_utf8 ("run_winui3_application", ex.code ());
		if (!ex.message ().empty ()) {
			winui3_logf ("[winui3] message: ");
			winui3_log_wide (ex.message ().c_str ());
			winui3_logf ("\n");
		}
		return (int) ex.code ().value;
	} catch (...) {
		winui3_log_error ("run_winui3_application unknown error");
		return -1;
	}
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

struct WidgetsApp : ApplicationT<WidgetsApp>
{
	WidgetsApp () = default;

	void
	log_step (const wchar_t* step)
	{
		winui3_logf ("[winui3] OnLaunched step: ");
		winui3_log_wide (step);
		winui3_logf ("\n");
	}

	void
	OnLaunched (LaunchActivatedEventArgs const&)
	{
		const wchar_t* step = L"start";
		try {
			/* Unpackaged demo: skip XamlControlsResources (needs ms-appx theme
			 * URIs from the Singleton MSIX; bootstrap + installed runtime is not
			 * enough for this executable layout). Button/TextBox use defaults. */
			step = L"Window";
			log_step (step);
			m_window = Window ();
			m_window.Title (L"vala.win32 WinUI3 widgets");

			step = L"StackPanel";
			log_step (step);
			m_root = StackPanel ();
			m_root.Padding (Thickness{24});

			step = L"TextBlock title";
			log_step (step);
			m_title = TextBlock ();
			m_title.Text (L"WinUI3 widgets demo");
			m_title.FontSize (22);

			step = L"TextBlock name label";
			log_step (step);
			m_name_label = TextBlock ();
			m_name_label.Text (L"Your name:");

			step = L"TextBox";
			log_step (step);
			m_name_input = TextBox ();

			step = L"Button";
			log_step (step);
			m_greet_button = Button ();
			m_greet_button.Content (box_value (L"Greet"));

			step = L"TextBlock greeting";
			log_step (step);
			m_greeting = TextBlock ();
			m_greeting.Text (L"Hello, World!");
			m_greeting.FontSize (18);

			step = L"Children.Append";
			log_step (step);
			auto children = m_root.Children ();
			children.Append (m_title);
			children.Append (m_name_label);
			children.Append (m_name_input);
			children.Append (m_greet_button);
			children.Append (m_greeting);

			step = L"Window.Content/Activate";
			log_step (step);
			m_window.Content (m_root);
			m_window.Activate ();

			step = L"Button.Click";
			log_step (step);
			m_greet_click = RoutedEventHandler {
				this, &WidgetsApp::on_greet_clicked};
			m_greet_button.Click (m_greet_click);

			winui3_logf ("[winui3] OnLaunched complete\n");
		} catch (hresult_error const& ex) {
			winui3_log_hresult_step (step, ex.code (), ex.message ());
		} catch (...) {
			winui3_logf ("[winui3] ERROR: ");
			winui3_log_wide (step);
			winui3_logf (" (unknown exception)\n");
		}
	}

	void
	on_greet_clicked (IInspectable const&, RoutedEventArgs const&)
	{
		winui3_logf ("[winui3] Greet clicked\n");
		hstring name = m_name_input.Text ();
		if (name.empty ()) {
			name = L"World";
		}
		m_greeting.Text (L"Hello, " + name + L"!");
	}

	Window m_window{ nullptr };
	StackPanel m_root{ nullptr };
	TextBlock m_title{ nullptr };
	TextBlock m_name_label{ nullptr };
	TextBox m_name_input{ nullptr };
	Button m_greet_button{ nullptr };
	TextBlock m_greeting{ nullptr };
	RoutedEventHandler m_greet_click{ nullptr };
};

} /* anonymous namespace */

extern "C" int
winui3_run_hello_window (void)
{
	return run_winui3_application<HelloApp> ();
}

extern "C" int
winui3_run_widgets_demo (void)
{
	return run_winui3_application<WidgetsApp> ();
}
