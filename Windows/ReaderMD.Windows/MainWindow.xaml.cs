using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Web.WebView2.Core;
using Microsoft.Win32;

namespace ReaderMD.Windows;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<DocumentTab> _documents = [];
    private readonly ObservableCollection<WorkspaceFile> _workspaceFiles = [];
    private readonly ObservableCollection<OutlineItem> _outline = [];
    private bool _webReady;
    private bool _updatingSource;
    private bool _isFocusMode;
    private DisplayMode _displayMode = DisplayMode.Document;

    public MainWindow()
    {
        InitializeComponent();
        FileList.ItemsSource = _workspaceFiles;
        OutlineList.ItemsSource = _outline;
        Loaded += MainWindow_Loaded;
        Closing += MainWindow_Closing;
        PreviewKeyDown += MainWindow_PreviewKeyDown;
    }

    private DocumentTab? CurrentDocument => DocumentTabs.SelectedItem is TabItem item ? item.Tag as DocumentTab : null;

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            await PreviewWebView.EnsureCoreWebView2Async();
            var core = PreviewWebView.CoreWebView2;
            core.Settings.AreDefaultContextMenusEnabled = true;
            core.Settings.AreDevToolsEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.SetVirtualHostNameToFolderMapping(
                "readermd.local",
                AppContext.BaseDirectory,
                CoreWebView2HostResourceAccessKind.DenyCors);
            MapDocumentFolder(AppContext.BaseDirectory);
            core.WebMessageReceived += Core_WebMessageReceived;
            core.NavigationCompleted += Core_NavigationCompleted;
            core.NavigationStarting += Core_NavigationStarting;
            core.NewWindowRequested += Core_NewWindowRequested;
            core.Navigate("https://readermd.local/Shell/renderer-shell.html");
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                this,
                "ReaderMD needs the Microsoft Edge WebView2 Runtime.\n\n" + ex.Message,
                "ReaderMD",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }

        UpdateWorkspaceState();
    }

    private void MainWindow_Closing(object? sender, CancelEventArgs e)
    {
        foreach (var document in _documents.ToArray())
        {
            if (!ConfirmDiscard(document))
            {
                e.Cancel = true;
                return;
            }
        }
    }

    private void MainWindow_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.F11)
        {
            ToggleFocusMode();
            e.Handled = true;
            return;
        }

        if (e.Key == Key.Escape && _isFocusMode)
        {
            ToggleFocusMode();
            e.Handled = true;
            return;
        }

        if ((Keyboard.Modifiers & ModifierKeys.Control) == 0)
        {
            return;
        }

        if (e.Key == Key.O)
        {
            OpenFile();
            e.Handled = true;
        }
        else if (e.Key == Key.S && (Keyboard.Modifiers & ModifierKeys.Shift) != 0)
        {
            SaveCurrentAs();
            e.Handled = true;
        }
        else if (e.Key == Key.S)
        {
            SaveCurrent();
            e.Handled = true;
        }
        else if (e.Key == Key.F)
        {
            FindBox.Focus();
            FindBox.SelectAll();
            e.Handled = true;
        }
    }

    private async void Core_NavigationCompleted(object? sender, CoreWebView2NavigationCompletedEventArgs e)
    {
        _webReady = e.IsSuccess;
        if (_webReady)
        {
            await RenderCurrentDocumentAsync(force: true);
        }
    }

    private void Core_NavigationStarting(object? sender, CoreWebView2NavigationStartingEventArgs e)
    {
        if (!Uri.TryCreate(e.Uri, UriKind.Absolute, out var uri))
        {
            return;
        }

        if (uri.Host is "readermd.local" or "readermd-document.local")
        {
            return;
        }

        if (uri.Scheme is "http" or "https" or "mailto")
        {
            e.Cancel = true;
            OpenExternal(uri.ToString());
        }
    }

    private void Core_NewWindowRequested(object? sender, CoreWebView2NewWindowRequestedEventArgs e)
    {
        e.Handled = true;
        if (Uri.TryCreate(e.Uri, UriKind.Absolute, out var uri) && uri.Scheme is "http" or "https" or "mailto")
        {
            OpenExternal(e.Uri);
        }
    }

    private async void Core_WebMessageReceived(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        try
        {
            using var message = JsonDocument.Parse(e.WebMessageAsJson);
            var root = message.RootElement;
            var name = root.GetProperty("name").GetString();
            var body = root.GetProperty("body");

            switch (name)
            {
                case "copyText":
                    if (body.ValueKind == JsonValueKind.String)
                    {
                        Clipboard.SetText(body.GetString() ?? string.Empty);
                    }
                    break;
                case "copyRichText":
                    CopyRichText(body);
                    break;
                case "editorChange":
                    ApplyRenderedEditorChange(body);
                    break;
                case "pickImage":
                    await PickImageAsync();
                    break;
            }
        }
        catch
        {
            // Ignore malformed messages from page content.
        }
    }

    private void CopyRichText(JsonElement body)
    {
        var plainText = body.TryGetProperty("plainText", out var plain) ? plain.GetString() ?? string.Empty : string.Empty;
        var html = body.TryGetProperty("html", out var htmlNode) ? htmlNode.GetString() ?? string.Empty : string.Empty;
        var data = new DataObject();
        data.SetData(DataFormats.UnicodeText, plainText);
        if (!string.IsNullOrWhiteSpace(html))
        {
            data.SetData(DataFormats.Html, html);
        }
        Clipboard.SetDataObject(data, true);
    }

    private void ApplyRenderedEditorChange(JsonElement body)
    {
        var document = CurrentDocument;
        if (document is null || !body.TryGetProperty("markdown", out var markdownNode))
        {
            return;
        }

        var markdown = markdownNode.GetString() ?? string.Empty;
        if (markdown == document.Content)
        {
            return;
        }

        document.Content = markdown;
        document.Revision++;
        document.IsDirty = true;
        _updatingSource = true;
        SourceEditor.Text = markdown;
        _updatingSource = false;
        RefreshTabHeader(document);
        RefreshOutline(document.Content);
        UpdateDocumentStats(document);
    }

    private async Task PickImageAsync()
    {
        var dialog = new OpenFileDialog
        {
            Title = "Insert Image",
            Filter = "Images|*.png;*.jpg;*.jpeg;*.gif;*.webp;*.svg;*.bmp|All files|*.*",
            Multiselect = false
        };
        if (dialog.ShowDialog(this) != true)
        {
            await ExecuteScriptAsync("window.readermdCancelPickedImage && window.readermdCancelPickedImage();");
            return;
        }

        var source = MakeImageSource(dialog.FileName, CurrentDocument?.Path);
        var alt = Path.GetFileNameWithoutExtension(dialog.FileName);
        await ExecuteScriptAsync($"window.readermdInsertPickedImage && window.readermdInsertPickedImage({JsonSerializer.Serialize(source)}, {JsonSerializer.Serialize(alt)});");
    }

    private static string MakeImageSource(string imagePath, string? documentPath)
    {
        if (string.IsNullOrWhiteSpace(documentPath))
        {
            return new Uri(imagePath).AbsoluteUri;
        }

        var baseFolder = Path.GetDirectoryName(documentPath)!;
        var relative = Path.GetRelativePath(baseFolder, imagePath).Replace('\\', '/');
        return Uri.EscapeUriString(relative);
    }

    private void OpenFile_Click(object sender, RoutedEventArgs e) => OpenFile();

    private void OpenFile()
    {
        var dialog = new OpenFileDialog
        {
            Title = "Open Markdown",
            Filter = "Markdown files|*.md;*.markdown;*.mdown;*.mkd;*.txt|All files|*.*",
            Multiselect = true
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        foreach (var file in dialog.FileNames)
        {
            OpenDocument(file);
        }
    }

    private void OpenFolder_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFolderDialog { Title = "Open Folder" };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }
        LoadWorkspaceFolder(dialog.FolderName);
    }

    private void LoadWorkspaceFolder(string folder)
    {
        _workspaceFiles.Clear();
        foreach (var file in Directory.EnumerateFiles(folder, "*", SearchOption.AllDirectories)
                     .Where(IsMarkdownFile)
                     .OrderBy(path => path, StringComparer.OrdinalIgnoreCase))
        {
            _workspaceFiles.Add(new WorkspaceFile(file, Path.GetRelativePath(folder, file)));
        }
    }

    private void FileList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (FileList.SelectedItem is WorkspaceFile file)
        {
            OpenDocument(file.Path);
        }
    }

    private void OpenDocument(string path)
    {
        path = Path.GetFullPath(path);
        var existing = _documents.FirstOrDefault(d => string.Equals(d.Path, path, StringComparison.OrdinalIgnoreCase));
        if (existing is not null)
        {
            SelectDocument(existing);
            return;
        }

        try
        {
            var content = File.ReadAllText(path);
            var document = new DocumentTab(path, content);
            _documents.Add(document);
            var tab = new TabItem { Tag = document };
            DocumentTabs.Items.Add(tab);
            RefreshTabHeader(document);
            DocumentTabs.SelectedItem = tab;
            UpdateWorkspaceState();
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Open Markdown", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void SelectDocument(DocumentTab document)
    {
        foreach (TabItem tab in DocumentTabs.Items)
        {
            if (ReferenceEquals(tab.Tag, document))
            {
                DocumentTabs.SelectedItem = tab;
                break;
            }
        }
    }

    private async void DocumentTabs_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (e.Source != DocumentTabs)
        {
            return;
        }
        await ActivateCurrentDocumentAsync();
    }

    private async Task ActivateCurrentDocumentAsync()
    {
        var document = CurrentDocument;
        _updatingSource = true;
        SourceEditor.Text = document?.Content ?? string.Empty;
        _updatingSource = false;

        if (document is not null)
        {
            MapDocumentFolder(Path.GetDirectoryName(document.Path) ?? AppContext.BaseDirectory);
            RefreshOutline(document.Content);
            UpdateDocumentStats(document);
            PathStatus.Text = document.Path;
            Title = $"{document.Title} - ReaderMD";
        }
        else
        {
            MapDocumentFolder(AppContext.BaseDirectory);
            _outline.Clear();
            PathStatus.Text = "No document";
            StatsStatus.Text = string.Empty;
            Title = "ReaderMD";
        }

        UpdateWorkspaceState();
        await RenderCurrentDocumentAsync(force: true);
    }

    private void SourceEditor_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (_updatingSource || CurrentDocument is not { } document)
        {
            return;
        }

        document.Content = SourceEditor.Text;
        document.Revision++;
        document.IsDirty = document.Content != document.LastSavedContent;
        RefreshTabHeader(document);
        RefreshOutline(document.Content);
        UpdateDocumentStats(document);
        _ = RenderCurrentDocumentAsync(force: false);
    }

    private void RefreshOutline(string markdown)
    {
        _outline.Clear();
        var insideFence = false;
        var index = 0;
        foreach (var line in markdown.Replace("\r\n", "\n").Split('\n'))
        {
            var trimmed = line.TrimStart();
            if (trimmed.StartsWith("```") || trimmed.StartsWith("~~~"))
            {
                insideFence = !insideFence;
                continue;
            }
            if (insideFence)
            {
                continue;
            }

            var match = Regex.Match(line, "^(#{1,6})\\s+(.+?)\\s*#*\\s*$");
            if (!match.Success)
            {
                continue;
            }
            var title = Regex.Replace(match.Groups[2].Value, "[*_`~\\[\\]]", string.Empty);
            _outline.Add(new OutlineItem($"heading-{index++}", match.Groups[1].Value.Length, title));
        }
    }

    private async void OutlineList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (OutlineList.SelectedItem is OutlineItem item)
        {
            await ExecuteScriptAsync($"window.readermdScrollTo && window.readermdScrollTo({JsonSerializer.Serialize(item.Id)});");
        }
    }

    private void Save_Click(object sender, RoutedEventArgs e) => SaveCurrent();

    private void SaveCurrent()
    {
        if (CurrentDocument is not { } document)
        {
            return;
        }
        SaveDocument(document, document.Path);
    }

    private void SaveAs_Click(object sender, RoutedEventArgs e) => SaveCurrentAs();

    private void SaveCurrentAs()
    {
        if (CurrentDocument is not { } document)
        {
            return;
        }
        var dialog = new SaveFileDialog
        {
            Title = "Save Markdown",
            Filter = "Markdown file|*.md|Text file|*.txt|All files|*.*",
            FileName = document.Title
        };
        if (dialog.ShowDialog(this) == true)
        {
            SaveDocument(document, dialog.FileName);
        }
    }

    private void SaveDocument(DocumentTab document, string path)
    {
        try
        {
            File.WriteAllText(path, document.Content);
            document.Path = path;
            document.Title = Path.GetFileName(path);
            document.LastSavedContent = document.Content;
            document.IsDirty = false;
            RefreshTabHeader(document);
            _ = ActivateCurrentDocumentAsync();
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Save Markdown", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private bool ConfirmDiscard(DocumentTab document)
    {
        if (!document.IsDirty)
        {
            return true;
        }
        var result = MessageBox.Show(
            this,
            $"Save changes to {document.Title}?",
            "ReaderMD",
            MessageBoxButton.YesNoCancel,
            MessageBoxImage.Warning);
        if (result == MessageBoxResult.Cancel)
        {
            return false;
        }
        if (result == MessageBoxResult.Yes)
        {
            SaveDocument(document, document.Path);
            return !document.IsDirty;
        }
        return true;
    }

    private async void ExportPdf_Click(object sender, RoutedEventArgs e)
    {
        if (!_webReady || CurrentDocument is not { } document)
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
            await PreviewWebView.CoreWebView2.PrintToPdfAsync(dialog.FileName);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Export PDF", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void Print_Click(object sender, RoutedEventArgs e)
    {
        if (_webReady)
        {
            PreviewWebView.CoreWebView2.ShowPrintUI(CoreWebView2PrintDialogKind.System);
        }
    }

    private async void Undo_Click(object sender, RoutedEventArgs e)
    {
        if (_displayMode == DisplayMode.Source)
        {
            SourceEditor.Undo();
        }
        else
        {
            await ExecuteScriptAsync("window.readermdUndo && window.readermdUndo();");
        }
    }

    private async void Redo_Click(object sender, RoutedEventArgs e)
    {
        if (_displayMode == DisplayMode.Source)
        {
            SourceEditor.Redo();
        }
        else
        {
            await ExecuteScriptAsync("window.readermdRedo && window.readermdRedo();");
        }
    }

    private void Find_Click(object sender, RoutedEventArgs e)
    {
        FindBox.Focus();
        FindBox.SelectAll();
    }

    private async void FindBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        await ExecuteScriptAsync($"window.readermdFind && window.readermdFind({JsonSerializer.Serialize(FindBox.Text)});");
    }

    private void DocumentMode_Click(object sender, RoutedEventArgs e) => SetDisplayMode(DisplayMode.Document);
    private void SplitMode_Click(object sender, RoutedEventArgs e) => SetDisplayMode(DisplayMode.Split);
    private void SourceMode_Click(object sender, RoutedEventArgs e) => SetDisplayMode(DisplayMode.Source);

    private void SetDisplayMode(DisplayMode mode)
    {
        _displayMode = mode;
        switch (mode)
        {
            case DisplayMode.Document:
                SourceColumn.Width = new GridLength(0);
                SplitDividerColumn.Width = new GridLength(0);
                PreviewColumn.Width = new GridLength(1, GridUnitType.Star);
                break;
            case DisplayMode.Split:
                SourceColumn.Width = new GridLength(1, GridUnitType.Star);
                SplitDividerColumn.Width = new GridLength(5);
                PreviewColumn.Width = new GridLength(1, GridUnitType.Star);
                break;
            case DisplayMode.Source:
                SourceColumn.Width = new GridLength(1, GridUnitType.Star);
                SplitDividerColumn.Width = new GridLength(0);
                PreviewColumn.Width = new GridLength(0);
                break;
        }
    }

    private async void RichEditChanged(object sender, RoutedEventArgs e)
    {
        await RenderCurrentDocumentAsync(force: false);
    }

    private async void ThemeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        ApplyNativeTheme();
        await RenderCurrentDocumentAsync(force: true);
    }

    private async void WidthSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (!IsLoaded)
        {
            return;
        }
        await ExecuteScriptAsync($"window.readermdSetLayout && window.readermdSetLayout({(int)WidthSlider.Value}, true, 0, false);");
    }

    private void ApplyNativeTheme()
    {
        var theme = SelectedTheme();
        var dark = theme == "dark";
        Resources["WindowBackgroundBrush"] = new System.Windows.Media.SolidColorBrush(
            (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(dark ? "#1D1E22" : "#F3F3F3"));
        Resources["PanelBrush"] = new System.Windows.Media.SolidColorBrush(
            (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(dark ? "#24252A" : "#FAFAFA"));
        Resources["BorderBrush"] = new System.Windows.Media.SolidColorBrush(
            (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(dark ? "#3B3D43" : "#D8D8D8"));
    }

    private string SelectedTheme() => (ThemeBox.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "system";

    private void FocusMode_Click(object sender, RoutedEventArgs e) => ToggleFocusMode();

    private void ToggleFocusMode()
    {
        _isFocusMode = !_isFocusMode;
        Toolbar.Visibility = _isFocusMode ? Visibility.Collapsed : Visibility.Visible;
        SidebarColumn.Width = _isFocusMode ? new GridLength(0) : new GridLength(240);
        OutlineColumn.Width = _isFocusMode ? new GridLength(0) : new GridLength(220);
        WindowStyle = _isFocusMode ? WindowStyle.None : WindowStyle.SingleBorderWindow;
        WindowState = _isFocusMode ? WindowState.Maximized : WindowState.Normal;
    }

    private void Exit_Click(object sender, RoutedEventArgs e) => Close();

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    private void Window_Drop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(DataFormats.FileDrop) is not string[] paths)
        {
            return;
        }
        foreach (var path in paths)
        {
            if (Directory.Exists(path))
            {
                LoadWorkspaceFolder(path);
            }
            else if (File.Exists(path) && IsMarkdownFile(path))
            {
                OpenDocument(path);
            }
        }
    }

    private void MapDocumentFolder(string folder)
    {
        if (!_webReady && PreviewWebView.CoreWebView2 is null)
        {
            return;
        }
        PreviewWebView.CoreWebView2?.SetVirtualHostNameToFolderMapping(
            "readermd-document.local",
            folder,
            CoreWebView2HostResourceAccessKind.DenyCors);
    }

    private async Task RenderCurrentDocumentAsync(bool force)
    {
        if (!_webReady || CurrentDocument is not { } document)
        {
            return;
        }

        var payload = new
        {
            documentID = document.Id.ToString(),
            markdown = document.Content,
            revision = document.Revision,
            editable = RichEditCheckBox.IsChecked == true,
            theme = SelectedTheme(),
            readingStyle = "modern",
            customReadingPreset = (object?)null,
            systemDark = false,
            readingWidth = (int)WidthSlider.Value,
            readingWidthIsFluid = false,
            paperCanvas = true,
            zoom = 1.0,
            searchText = FindBox.Text ?? string.Empty,
            outlineTarget = (string?)null,
            externalChanges = Array.Empty<object>(),
            externalChangeSelection = (int?)null,
            topInset = 0.0
        };
        var json = JsonSerializer.Serialize(payload);
        await ExecuteScriptAsync($"window.readermdRender && window.readermdRender({json});");
    }

    private async Task ExecuteScriptAsync(string script)
    {
        if (!_webReady || PreviewWebView.CoreWebView2 is null)
        {
            return;
        }
        try
        {
            await PreviewWebView.CoreWebView2.ExecuteScriptAsync(script);
        }
        catch
        {
            // Navigation can replace the page while a UI update is queued.
        }
    }

    private void RefreshTabHeader(DocumentTab document)
    {
        foreach (TabItem tab in DocumentTabs.Items)
        {
            if (ReferenceEquals(tab.Tag, document))
            {
                tab.Header = document.Title + (document.IsDirty ? " *" : string.Empty);
                break;
            }
        }
    }

    private void UpdateWorkspaceState()
    {
        EmptyState.Visibility = CurrentDocument is null ? Visibility.Visible : Visibility.Collapsed;
        DocumentTabs.Visibility = _documents.Count == 0 ? Visibility.Collapsed : Visibility.Visible;
    }

    private void UpdateDocumentStats(DocumentTab document)
    {
        var words = Regex.Matches(document.Content, @"\S+").Count;
        var minutes = Math.Max(1, (int)Math.Ceiling(words / 220.0));
        StatsStatus.Text = $"{words:N0} words · {document.Content.Length:N0} characters · {minutes} min read";
    }

    private static bool IsMarkdownFile(string path)
    {
        return Path.GetExtension(path).ToLowerInvariant() is ".md" or ".markdown" or ".mdown" or ".mkd" or ".txt";
    }

    private static void OpenExternal(string target)
    {
        try
        {
            Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
        }
        catch
        {
        }
    }

    private enum DisplayMode
    {
        Document,
        Split,
        Source
    }

    private sealed class DocumentTab
    {
        public DocumentTab(string path, string content)
        {
            Path = path;
            Title = System.IO.Path.GetFileName(path);
            Content = content;
            LastSavedContent = content;
        }

        public Guid Id { get; } = Guid.NewGuid();
        public string Path { get; set; }
        public string Title { get; set; }
        public string Content { get; set; }
        public string LastSavedContent { get; set; }
        public int Revision { get; set; }
        public bool IsDirty { get; set; }
    }

    private sealed record WorkspaceFile(string Path, string DisplayName)
    {
        public override string ToString() => DisplayName;
    }

    private sealed record OutlineItem(string Id, int Level, string Title)
    {
        public override string ToString() => new string(' ', Math.Max(0, Level - 1) * 2) + Title;
    }
}
