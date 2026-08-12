using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using Microsoft.Win32;

namespace ReaderMD.Windows;

public partial class MainWindow
{
    private DependencyPropertyDescriptor? _windowStyleDescriptor;

    private void IntegratedChrome_SourceInitialized(object? sender, EventArgs e)
    {
        _windowStyleDescriptor = DependencyPropertyDescriptor.FromProperty(WindowStyleProperty, typeof(Window));
        _windowStyleDescriptor?.AddValueChanged(this, IntegratedChrome_WindowStyleChanged);
        EnsureIntegratedChrome();
        UpdateCaptionState();
    }

    private void IntegratedChrome_WindowStyleChanged(object? sender, EventArgs e)
    {
        EnsureIntegratedChrome();
    }

    private void EnsureIntegratedChrome()
    {
        if (WindowStyle != WindowStyle.None)
        {
            WindowStyle = WindowStyle.None;
        }
    }

    private void IntegratedChrome_StateChanged(object? sender, EventArgs e)
    {
        UpdateCaptionState();
    }

    private void UpdateCaptionState()
    {
        if (MaximizeGlyph is null || MaximizeButton is null)
        {
            return;
        }

        var maximized = WindowState == WindowState.Maximized;
        MaximizeGlyph.Text = maximized ? "❐" : "□";
        MaximizeButton.ToolTip = maximized ? "Restore" : "Maximize";
    }

    private void TitleBarDrag_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left)
        {
            return;
        }

        if (e.ClickCount == 2)
        {
            ToggleMaximizeRestore();
            e.Handled = true;
            return;
        }

        try
        {
            DragMove();
        }
        catch (InvalidOperationException)
        {
            // A mouse-up can race DragMove when the user double-clicks quickly.
        }
    }

    private void MinimizeWindow_Click(object sender, RoutedEventArgs e)
    {
        SystemCommands.MinimizeWindow(this);
    }

    private void MaximizeWindow_Click(object sender, RoutedEventArgs e)
    {
        ToggleMaximizeRestore();
    }

    private void ToggleMaximizeRestore()
    {
        if (WindowState == WindowState.Maximized)
        {
            SystemCommands.RestoreWindow(this);
        }
        else
        {
            SystemCommands.MaximizeWindow(this);
        }
    }

    private void CloseWindow_Click(object sender, RoutedEventArgs e)
    {
        SystemCommands.CloseWindow(this);
    }

    private void CloseTab_Click(object sender, RoutedEventArgs e)
    {
        e.Handled = true;
        if (sender is not Button { Tag: TabItem tab } || tab.Tag is not DocumentTab document)
        {
            return;
        }

        if (!ConfirmDiscard(document))
        {
            return;
        }

        var index = DocumentTabs.Items.IndexOf(tab);
        _documents.Remove(document);
        DocumentTabs.Items.Remove(tab);

        if (DocumentTabs.Items.Count > 0)
        {
            DocumentTabs.SelectedIndex = Math.Min(Math.Max(0, index), DocumentTabs.Items.Count - 1);
        }

        UpdateWorkspaceState();
    }

    private async void ExportPdfPolished_Click(object sender, RoutedEventArgs e)
    {
        if (!_webReady || PreviewWebView.CoreWebView2 is null || CurrentDocument is not { } document)
        {
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
            var resolvedTheme = IsDarkTheme() ? "dark" : "light";
            var prepareScript =
                "(async function(){" +
                "if(window.readermdPreparePrint){await window.readermdPreparePrint({theme:" +
                JsonSerializer.Serialize(resolvedTheme) +
                ",style:'modern'});}" +
                "return true;})()";
            await PreviewWebView.CoreWebView2.ExecuteScriptAsync(prepareScript);

            var settings = PreviewWebView.CoreWebView2.Environment.CreatePrintSettings();
            settings.ShouldPrintBackgrounds = true;
            settings.ShouldPrintHeaderAndFooter = false;
            settings.ShouldPrintSelectionOnly = false;
            settings.MarginTop = 0;
            settings.MarginBottom = 0;
            settings.MarginLeft = 0;
            settings.MarginRight = 0;
            settings.ScaleFactor = 1.0;

            var succeeded = await PreviewWebView.CoreWebView2.PrintToPdfAsync(
                Path.GetFullPath(dialog.FileName),
                settings);
            if (!succeeded)
            {
                throw new InvalidOperationException("WebView2 did not complete the PDF export.");
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Export PDF", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            await ExecuteScriptAsync("window.readermdFinishPrint && window.readermdFinishPrint();");
        }
    }
}

public sealed class FileNameConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var path = value?.ToString() ?? string.Empty;
        var name = Path.GetFileName(path);
        return string.IsNullOrWhiteSpace(name) ? path : name;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        return Binding.DoNothing;
    }
}
