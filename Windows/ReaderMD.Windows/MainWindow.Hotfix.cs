using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shell;
using System.Windows.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Win32;

namespace ReaderMD.Windows;

public partial class MainWindow
{
    private bool _hotfixLoaded;

    protected override void OnInitialized(EventArgs e)
    {
        base.OnInitialized(e);
        Loaded += Hotfix_Loaded;
    }

    private async void Hotfix_Loaded(object sender, RoutedEventArgs e)
    {
        if (_hotfixLoaded)
        {
            return;
        }

        _hotfixLoaded = true;
        RichEditCheckBox.Content = "Toggle editing";
        ApplyHotfixTitleBarSizing();
        ReplacePdfMenuHandler();

        DocumentTabs.SelectionChanged += Hotfix_DocumentTabs_SelectionChanged;
        RichEditCheckBox.Checked += Hotfix_RichEditChanged;
        RichEditCheckBox.Unchecked += Hotfix_RichEditChanged;

        // Collapse the HWND-backed document surfaces before WebView2 can paint over
        // the WPF welcome card. A selected document will restore the correct view.
        ApplyHotfixWorkspaceVisibility();

        await AttachHotfixDropHandlingAsync(PreviewWebView);
        await AttachHotfixDropHandlingAsync(SecondaryPreviewWebView);

        await Dispatcher.InvokeAsync(ApplyHotfixWorkspaceVisibility, DispatcherPriority.ContextIdle);
    }

    private void ApplyHotfixTitleBarSizing()
    {
        const double titleHeight = 50;
        IntegratedTitleBar.Height = titleHeight;

        var chrome = WindowChrome.GetWindowChrome(this);
        if (chrome is not null)
        {
            chrome.CaptionHeight = titleHeight;
        }

        var menu = FindVisualChild<Menu>(IntegratedTitleBar);
        if (menu is not null)
        {
            menu.Height = titleHeight;
            menu.Padding = new Thickness(0);
            menu.VerticalAlignment = VerticalAlignment.Stretch;

            foreach (var item in menu.Items.OfType<MenuItem>())
            {
                item.Height = titleHeight;
                item.MinHeight = titleHeight;
                item.Padding = new Thickness(14, 0, 14, 0);
                item.VerticalAlignment = VerticalAlignment.Stretch;
                item.VerticalContentAlignment = VerticalAlignment.Center;
            }
        }

        foreach (var button in FindVisualChildren<System.Windows.Controls.Button>(IntegratedTitleBar))
        {
            if (ReferenceEquals(button, ExitFocusButton))
            {
                button.Height = 34;
                button.Margin = new Thickness(6, 8, 0, 8);
                continue;
            }

            button.Height = titleHeight;
        }
    }

    private void ReplacePdfMenuHandler()
    {
        var menu = FindVisualChild<Menu>(IntegratedTitleBar);
        var fileMenu = menu?.Items.OfType<MenuItem>().FirstOrDefault();
        if (fileMenu is null)
        {
            return;
        }

        var exportItem = fileMenu.Items.OfType<MenuItem>()
            .FirstOrDefault(item => (item.Header?.ToString() ?? string.Empty)
                .Replace("_", string.Empty, StringComparison.Ordinal)
                .StartsWith("Export PDF", StringComparison.OrdinalIgnoreCase));
        if (exportItem is null)
        {
            return;
        }

        exportItem.Click -= ExportPdfPolished_Click;
        exportItem.Click += Hotfix_ExportPdf_Click;
    }

    private static T? FindVisualChild<T>(DependencyObject root) where T : DependencyObject
    {
        return FindVisualChildren<T>(root).FirstOrDefault();
    }

    private static IEnumerable<T> FindVisualChildren<T>(DependencyObject root) where T : DependencyObject
    {
        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < count; index++)
        {
            var child = VisualTreeHelper.GetChild(root, index);
            if (child is T match)
            {
                yield return match;
            }

            foreach (var descendant in FindVisualChildren<T>(child))
            {
                yield return descendant;
            }
        }
    }

    private void Hotfix_DocumentTabs_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (e.Source != DocumentTabs)
        {
            return;
        }

        Dispatcher.BeginInvoke(
            DispatcherPriority.ContextIdle,
            new Action(async () =>
            {
                ApplyHotfixWorkspaceVisibility();
                if (RichEditCheckBox.IsChecked == true && CurrentDocument is not null)
                {
                    await ForceRenderedEditingStateAsync();
                }
            }));
    }

    private void ApplyHotfixWorkspaceVisibility()
    {
        var hasDocument = CurrentDocument is not null;
        EmptyState.Visibility = hasDocument ? Visibility.Collapsed : Visibility.Visible;

        if (!hasDocument)
        {
            PreviewWebView.Visibility = Visibility.Collapsed;
            SecondaryPane.Visibility = Visibility.Collapsed;
            SourceEditor.Visibility = Visibility.Collapsed;
            return;
        }

        switch (_displayMode)
        {
            case DisplayMode.Source:
                PreviewWebView.Visibility = Visibility.Collapsed;
                SecondaryPane.Visibility = Visibility.Collapsed;
                SourceEditor.Visibility = Visibility.Visible;
                break;
            case DisplayMode.Split:
                PreviewWebView.Visibility = Visibility.Visible;
                SecondaryPane.Visibility = Visibility.Visible;
                SourceEditor.Visibility = Visibility.Collapsed;
                break;
            default:
                PreviewWebView.Visibility = Visibility.Visible;
                SecondaryPane.Visibility = Visibility.Collapsed;
                SourceEditor.Visibility = Visibility.Collapsed;
                break;
        }
    }

    private async void Hotfix_RichEditChanged(object sender, RoutedEventArgs e)
    {
        await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ContextIdle);
        await ForceRenderedEditingStateAsync();
    }

    private async Task ForceRenderedEditingStateAsync()
    {
        if (CurrentDocument is null || _displayMode == DisplayMode.Source)
        {
            return;
        }

        var editable = RichEditCheckBox.IsChecked == true;
        _lastRenderKey = null;
        _secondaryRenderKey = null;
        await RenderCurrentDocumentAsync(force: true);
        if (_displayMode == DisplayMode.Split)
        {
            await RenderSecondaryDocumentAsync(force: true);
        }

        var script = editable
            ? "window.readermdSetEditable && window.readermdSetEditable(true); var a=document.getElementById('preview-document'); if(a){a.focus();}"
            : "window.readermdSetEditable && window.readermdSetEditable(false);";
        await ExecuteScriptAsync(script);
        if (_displayMode == DisplayMode.Split)
        {
            await ExecuteSecondaryScriptAsync(script);
        }
    }

    private async Task AttachHotfixDropHandlingAsync(Microsoft.Web.WebView2.Wpf.WebView2 webView)
    {
        try
        {
            webView.AllowExternalDrop = true;
            await webView.EnsureCoreWebView2Async();
            if (webView.CoreWebView2 is not null)
            {
                webView.CoreWebView2.NavigationStarting -= Hotfix_DroppedFileNavigationStarting;
                webView.CoreWebView2.NavigationStarting += Hotfix_DroppedFileNavigationStarting;
            }
        }
        catch
        {
        }
    }

    private void Hotfix_DroppedFileNavigationStarting(object? sender, CoreWebView2NavigationStartingEventArgs e)
    {
        if (!Uri.TryCreate(e.Uri, UriKind.Absolute, out var uri) || !uri.IsFile)
        {
            return;
        }

        var path = uri.LocalPath;
        if (Directory.Exists(path))
        {
            e.Cancel = true;
            Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(() => LoadWorkspaceFolder(path)));
            return;
        }

        if (!File.Exists(path) || !IsMarkdownFile(path))
        {
            e.Cancel = true;
            return;
        }

        e.Cancel = true;
        Dispatcher.BeginInvoke(
            DispatcherPriority.Background,
            new Action(() => OpenDocument(path)));
    }

    private async void Hotfix_ExportPdf_Click(object sender, RoutedEventArgs e)
    {
        if (CurrentDocument is not { } document)
        {
            await ShowFluentDialogAsync(
                "Nothing to export",
                "Open a Markdown document before exporting a PDF.",
                "OK",
                string.Empty,
                string.Empty);
            return;
        }

        var dialog = new SaveFileDialog
        {
            Title = "Export PDF",
            Filter = "PDF file|*.pdf",
            FileName = Path.GetFileNameWithoutExtension(document.Title) + ".pdf"
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        try
        {
            if (!await EnsurePrimaryRendererReadyAsync())
            {
                throw new InvalidOperationException("The document renderer is not ready. Try the export again after the document is visible.");
            }

            await RenderCurrentDocumentAsync(force: true);
            var core = PreviewWebView.CoreWebView2
                ?? throw new InvalidOperationException("The document renderer is unavailable.");

            var resolvedTheme = IsDarkTheme() ? "dark" : "light";
            var expression =
                "(async function(){" +
                "if(window.readermdFlushEditor){await window.readermdFlushEditor();}" +
                "if(window.readermdPreparePrint){await window.readermdPreparePrint({theme:" +
                JsonSerializer.Serialize(resolvedTheme) +
                ",style:'modern'});}" +
                "return true;})()";
            await core.CallDevToolsProtocolMethodAsync(
                "Runtime.evaluate",
                JsonSerializer.Serialize(new
                {
                    expression,
                    awaitPromise = true,
                    returnByValue = true
                }));

            var settings = core.Environment.CreatePrintSettings();
            settings.ShouldPrintBackgrounds = true;
            settings.ShouldPrintHeaderAndFooter = false;
            settings.ShouldPrintSelectionOnly = false;
            settings.MarginTop = 0;
            settings.MarginBottom = 0;
            settings.MarginLeft = 0;
            settings.MarginRight = 0;
            settings.ScaleFactor = 1.0;

            var outputPath = Path.GetFullPath(dialog.FileName);
            var succeeded = await core.PrintToPdfAsync(outputPath, settings);
            if (!succeeded || !File.Exists(outputPath) || new FileInfo(outputPath).Length == 0)
            {
                throw new InvalidOperationException("WebView2 did not create the PDF file.");
            }
        }
        catch (Exception ex)
        {
            await ShowFluentDialogAsync(
                "PDF export failed",
                ex.Message,
                "OK",
                string.Empty,
                string.Empty);
        }
        finally
        {
            await ExecuteScriptAsync("window.readermdFinishPrint && window.readermdFinishPrint();");
            if (RichEditCheckBox.IsChecked == true)
            {
                await ForceRenderedEditingStateAsync();
            }
        }
    }

    private async Task<bool> EnsurePrimaryRendererReadyAsync()
    {
        await PreviewWebView.EnsureCoreWebView2Async();
        var core = PreviewWebView.CoreWebView2;
        if (core is null)
        {
            return false;
        }

        try
        {
            var readyState = await core.ExecuteScriptAsync("document.readyState");
            if (readyState.Contains("complete", StringComparison.OrdinalIgnoreCase) ||
                readyState.Contains("interactive", StringComparison.OrdinalIgnoreCase))
            {
                _webReady = true;
                return true;
            }
        }
        catch
        {
        }

        var completion = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        void NavigationCompleted(object? sender, CoreWebView2NavigationCompletedEventArgs args)
            => completion.TrySetResult(args.IsSuccess);

        core.NavigationCompleted += NavigationCompleted;
        try
        {
            core.Navigate("https://readermd.local/Shell/renderer-shell.html");
            var finished = await Task.WhenAny(completion.Task, Task.Delay(TimeSpan.FromSeconds(10)));
            if (!ReferenceEquals(finished, completion.Task) || !await completion.Task)
            {
                return false;
            }

            _webReady = true;
            return true;
        }
        finally
        {
            core.NavigationCompleted -= NavigationCompleted;
        }
    }
}
