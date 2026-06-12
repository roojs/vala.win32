/* WinUI3 MSVC sandbox — winui3-without-xaml pattern (no custom WindowT).
 * IXamlMetadataProvider required for XamlControlsResources / Button.
 * Build: ./build-msvc.ps1 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef GetCurrentTime

#include <cstdarg>
#include <cstdio>

#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.Xaml.Interop.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.XamlTypeInfo.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>

using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::XamlTypeInfo;
using namespace winrt::Microsoft::UI::Xaml::Markup;
using namespace winrt::Windows::UI::Xaml::Interop;

static FILE* g_log = nullptr;

static void
log_line (char const* msg)
{
	if (g_log != nullptr) {
		std::fputs (msg, g_log);
		std::fflush (g_log);
	}
	OutputDebugStringA (msg);
}

static void
log_fmt (char const* fmt, ...)
{
	char buf[256];
	va_list ap;
	va_start (ap, fmt);
	std::vsnprintf (buf, sizeof buf, fmt, ap);
	va_end (ap);
	log_line (buf);
}

static void
log_hresult (char const* step, hresult const hr)
{
	log_fmt ("[winui3-sandbox] %s HRESULT 0x%08x\n", step, (unsigned) hr.value);
}

struct WidgetSandboxApp : ApplicationT<WidgetSandboxApp, IXamlMetadataProvider>
{
	void
	OnLaunched (LaunchActivatedEventArgs const&)
	{
		try {
			log_line ("[winui3-sandbox] OnLaunched enter\n");

			Resources ().MergedDictionaries ().Append (XamlControlsResources ());
			log_line ("[winui3-sandbox] XamlControlsResources merged\n");

			m_window = Window ();
			m_window.Title (L"winui3 sandbox (MSVC)");

			StackPanel stack;
			stack.Padding (Thickness{16});
			stack.Spacing (8);
			stack.MinWidth (360);

			TextBlock title;
			title.Text (L"WinUI3 controls test");
			title.FontSize (22);

			TextBlock name_label;
			name_label.Text (L"Your name:");

			m_name_input = TextBox ();
			m_name_input.PlaceholderText (L"Type your name");

			m_greet_button = Button ();
			m_greet_button.Content (box_value (L"Greet"));
			auto const on_click = [this](
				IInspectable const&,
				RoutedEventArgs const&) -> void {
				on_greet_clicked ();
			};
			m_greet_button.Click (on_click);

			m_greeting = TextBlock ();
			m_greeting.Text (L"Hello, World!");
			m_greeting.FontSize (18);

			auto children = stack.Children ();
			children.Append (title);
			children.Append (name_label);
			children.Append (m_name_input);
			children.Append (m_greet_button);
			children.Append (m_greeting);

			m_window.Content (stack);
			m_window.Activate ();
			log_line ("[winui3-sandbox] OnLaunched OK (themed=1)\n");
		} catch (hresult_error const& ex) {
			log_hresult ("OnLaunched", ex.code ());
			if (!ex.message ().empty ()) {
				log_line ("[winui3-sandbox] message: ");
				std::wstring w (ex.message ().c_str ());
				for (wchar_t ch : w) {
					char narrow[8]{};
					WideCharToMultiByte (
						CP_UTF8, 0, &ch, 1, narrow, sizeof narrow, nullptr, nullptr);
					log_line (narrow);
				}
				log_line ("\n");
			}
			throw;
		}
	}

	void
	on_greet_clicked ()
	{
		log_line ("[winui3-sandbox] Greet clicked\n");
		hstring name = m_name_input.Text ();
		if (name.empty ()) {
			name = L"World";
		}
		m_greeting.Text (L"Hello, " + name + L"!");
	}

	IXamlType
	GetXamlType (TypeName const& type)
	{
		return m_provider.GetXamlType (type);
	}

	IXamlType
	GetXamlType (hstring const& fullname)
	{
		return m_provider.GetXamlType (fullname);
	}

	com_array<XmlnsDefinition>
	GetXmlnsDefinitions ()
	{
		return m_provider.GetXmlnsDefinitions ();
	}

	Window m_window{ nullptr };
	TextBox m_name_input{ nullptr };
	Button m_greet_button{ nullptr };
	TextBlock m_greeting{ nullptr };
	XamlControlsXamlMetaDataProvider m_provider;
};

static void
load_xaml_requirements ()
{
	using pfn_t = void (WINAPI*) (void);
	const HMODULE mod = LoadLibraryW (L"Microsoft.ui.xaml.dll");
	if (mod == nullptr) {
		log_fmt ("[winui3-sandbox] LoadLibrary xaml.dll failed %lu\n", GetLastError ());
		return;
	}
	const auto pfn = reinterpret_cast<pfn_t> (
		GetProcAddress (mod, "XamlCheckProcessRequirements"));
	if (pfn != nullptr) {
		pfn ();
		log_line ("[winui3-sandbox] XamlCheckProcessRequirements OK\n");
	}
	FreeLibrary (mod);
}

int WINAPI
wWinMain (HINSTANCE, HINSTANCE, PWSTR, int)
{
	g_log = std::fopen ("winui3-sandbox.log", "w");
	log_line ("[winui3-sandbox] start\n");

	try {
		init_apartment ();

		const PACKAGE_VERSION min_version{};
		const HRESULT hr = MddBootstrapInitialize2 (
			WINDOWSAPPSDK_RELEASE_MAJORMINOR,
			WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
			min_version,
			MddBootstrapInitializeOptions_None);
		if (FAILED (hr)) {
			log_fmt (
				"[winui3-sandbox] bootstrap failed 0x%08lX\n",
				(unsigned long) hr);
			MessageBoxA (
				nullptr,
				"bootstrap failed — see winui3-sandbox.log",
				"winui3 sandbox",
				MB_OK | MB_ICONERROR);
			return (int) hr;
		}
		log_line ("[winui3-sandbox] bootstrap OK\n");

		load_xaml_requirements ();

		log_line ("[winui3-sandbox] Application::Start\n");
		Application::Start ([] (auto&&) {
			make<WidgetSandboxApp> ();
		});

		MddBootstrapShutdown ();
		log_line ("[winui3-sandbox] exit normal\n");
	} catch (hresult_error const& ex) {
		log_hresult ("wWinMain", ex.code ());
		MessageBoxA (nullptr, "HRESULT error — see log", "winui3 sandbox", MB_OK | MB_ICONERROR);
		return (int) ex.code ().value;
	}

	if (g_log != nullptr) {
		std::fclose (g_log);
		g_log = nullptr;
	}
	return 0;
}
