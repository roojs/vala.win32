# include "pch.h"
# include <fstream>
# include <filesystem>

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Controls;
using namespace Microsoft::UI::Xaml::XamlTypeInfo;
using namespace Microsoft::UI::Xaml::Markup;
using namespace Windows::UI::Xaml::Interop;
using namespace Windows::Foundation;

namespace {

void diag_log(wchar_t const* msg)
{
	try {
		wchar_t path[MAX_PATH]{};
		GetModuleFileNameW(nullptr, path, MAX_PATH);
		auto const dir = std::filesystem::path(path).parent_path();
		std::wofstream out(dir / L"winui3-without-xaml-run.log", std::ios::app);
		out << msg << L"\n";
	} catch (...) {
	}
}

void diag_hresult(wchar_t const* step, winrt::hresult const& hr)
{
	wchar_t buf[256]{};
	swprintf_s(buf, L"%s HRESULT 0x%08X", step, static_cast<unsigned>(hr.value));
	diag_log(buf);
}

} // namespace

class MainWindow : public WindowT<MainWindow>
{
public:
	MainWindow()
	{
		StackPanel stackPanel;
		stackPanel.HorizontalAlignment(HorizontalAlignment::Center);
		stackPanel.VerticalAlignment(VerticalAlignment::Center);

		TextBlock title;
		try {
			title.Style(Application::Current().Resources().Lookup(box_value(L"TitleTextBlockStyle")).as<Style>());
		} catch (winrt::hresult_error const& e) {
			diag_hresult(L"TitleTextBlockStyle", e.code());
		}
		title.Text(L"WinUI 3 in C++ Without XAML!");
		title.HorizontalAlignment(HorizontalAlignment::Center);

		HyperlinkButton project;
		project.Content(box_value(L"Github Project Repository"));
		project.NavigateUri(Uri(L"https://github.com/sotanakamura/winui3-without-xaml"));
		project.HorizontalAlignment(HorizontalAlignment::Center);

		Button button;
		button.Content(box_value(L"Click"));
		button.Click([&](IInspectable const& sender, RoutedEventArgs) { sender.as<Button>().Content(box_value(L"Thank You!")); });
		button.HorizontalAlignment(HorizontalAlignment::Center);
		button.Margin(ThicknessHelper::FromUniformLength(20));

		Content(stackPanel);
		stackPanel.Children().Append(title);
		stackPanel.Children().Append(project);
		stackPanel.Children().Append(button);
		diag_log(L"MainWindow ctor done");
	}
};

class App : public ApplicationT<App, IXamlMetadataProvider>
{
public:
	void OnLaunched(LaunchActivatedEventArgs const&)
	{
		diag_log(L"OnLaunched enter");
		try {
			Resources().MergedDictionaries().Append(XamlControlsResources());
			diag_log(L"XamlControlsResources OK");
		} catch (winrt::hresult_error const& e) {
			diag_hresult(L"XamlControlsResources", e.code());
			if (!e.message().empty()) {
				diag_log(e.message().c_str());
			}
		}

		try {
			window = make<MainWindow>();
			window.Activate();
			diag_log(L"window Activate OK");
		} catch (winrt::hresult_error const& e) {
			diag_hresult(L"MainWindow", e.code());
			if (!e.message().empty()) {
				diag_log(e.message().c_str());
			}
		}
	}
	IXamlType GetXamlType(TypeName const& type)
	{
		return provider.GetXamlType(type);
	}
	IXamlType GetXamlType(hstring const& fullname)
	{
		return provider.GetXamlType(fullname);
	}
	com_array<XmlnsDefinition> GetXmlnsDefinitions()
	{
		return provider.GetXmlnsDefinitions();
	}
private:
	Window window{ nullptr };
	XamlControlsXamlMetaDataProvider provider;
};

int WINAPI wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int)
{
	diag_log(L"wWinMain enter");
	init_apartment();
	Application::Start([](auto&&) { make<App>(); });
	diag_log(L"wWinMain exit");
	return 0;
}
