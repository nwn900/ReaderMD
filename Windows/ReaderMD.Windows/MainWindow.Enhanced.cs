using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;
using Microsoft.Win32;
using Wpf.Ui.Controls;

namespace ReaderMD.Windows;

public partial class MainWindow
{
    private bool _enhancedLoaded;
    private bool _primaryObserverAttached;
    private bool _secondaryWebReady;
    private bool _settingSecondarySelection;
    private bool _allowWindowClose;
    private bool _deferredClosePending;
    private long _themeGeneration;
    private string? _secondaryRenderKey;
    private WindowState _windowStateBeforeFocus = WindowState.Normal;

    private DocumentTab? SecondaryDocument => SecondaryDocumentBox?.SelectedItem as DocumentTab;

    private async void Enhanced_Loaded(object sender, RoutedEventArgs e)
    {
        if (_enhancedLoaded)
        {
            return;
        }

        _enhancedLoaded = true;
        SecondaryDocumentBox.ItemsSource = _documents;
        UpdateEnhancedWorkspaceState();
        UpdateSaveButtonState();
        UpdateSearchMatchCount();

        await EnsureEnhancedWebViewsAsync();
        EnsureSecondarySelection();
        await RenderSecondaryDocumentAsync(force: true);
        await ApplyExplicitThemeToWebViewsAsync();
    }

    private async Task EnsureEnhancedWebViewsAsync()
    {
        try
        {
            await PreviewWebView.EnsureCoreWebView2Async();
            if (!_primaryObserverAttached && PreviewWebView.CoreWebView2 is not null)
            {
                PreviewWebView.CoreWebView2.WebMessageReceived += EnhancedPrimary_WebMessageReceived;
                _primaryObserverAttached = true;
            }

            await SecondaryPreviewWebView.EnsureCoreWebView2Async();
            var core = SecondaryPreviewWebView.CoreWebView2;
            if (core is null)
            {
                return;
            }

            core.Settings.AreDefaultContextMenusEnabled = true;
            core.Settings.AreDevToolsEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.SetVirtualHostNameToFolderMapping(
                "readermd.local",
                AppContext.BaseDirectory,
                CoreWebView2HostResourceAccessKind.DenyCors);
            core.WebMessageReceived += SecondaryCore_WebMessageReceived;
            core.NavigationCompleted += SecondaryCore_NavigationCompleted;
            core.NavigationStarting += Core_NavigationStarting;
            core.NewWindowRequested += Core_NewWindowRequested;
            core.Navigate("https://readermd.local/Shell/renderer-shell.html");
        }
        catch
        {
            _secondaryWebReady = false;
        }
    }

    private void EnhancedPrimary_WebMessageReceived(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        try
        {
            using var message = JsonDocument.Parse(e.WebMessageAsJson);
            if (message.RootElement.TryGetProperty("name", out var nameNode) &&
                string.Equals(nameNode.GetString(), "editorChange", StringComparison.Ordinal))
            {
                Dispatcher.BeginInvoke(
                    DispatcherPriority.Background,
                    new Action(async () =>
                    {
                        UpdateSaveButtonState();
                        UpdateSearchMatchCount();
                        if (_displayMode == DisplayMode.Split && ReferenceEquals(SecondaryDocument, CurrentDocument))
                        {
                            await RenderSecondaryDocumentAsync(force: false);
                        }
                    }));
            }
        }
        catch
        {
        }
    }

    private async void SecondaryCore_NavigationCompleted(object? sender, CoreWebView2NavigationCompletedEventArgs e)
    {
        _secondaryWebReady = e.IsSuccess;
        _secondaryRenderKey = null;
        if (_secondaryWebReady)
        {
            await RenderSecondaryDocumentAsync(force: true);
            await ApplyExplicitThemeAsync(SecondaryPreviewWebView);
        }
    }

    private async void SecondaryCore_WebMessageReceived(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
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
                    ApplySecondaryRenderedEditorChange(body);
                    break;
                case "pickImage":
                    await PickImageForSecondaryAsync();
                    break;
            }
        }
        catch
        {
        }
    }

    private void ApplySecondaryRenderedEditorChange(JsonElement body)
    {
        var document = SecondaryDocument;
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
        document.IsDirty = document.Content != document.LastSavedContent;
        RefreshTabHeader(document);

        if (ReferenceEquals(document, CurrentDocument))
        {
            _updatingSource = true;
            SourceEditor.Text = markdown;
            _updatingSource = false;
            RefreshOutline(markdown);
            UpdateDocumentStats(document);
            UpdateSaveButtonState();
            _ = RenderCurrentDocumentAsync(force: false);
        }
    }

    private async Task PickImageForSecondaryAsync()
    {
        var document = SecondaryDocument;
        if (document is null)
        {
            return;
        }

        var dialog = new OpenFileDialog
        {
            Title = "Insert Image",
            Filter = "Images|*.png;*.jpg;*.jpeg;*.gif;*.webp;*.svg;*.bmp|All files|*.*",
            Multiselect = false
        };

        if (dialog.ShowDialog(this) != true)
        {
            await ExecuteSecondaryScriptAsync("window.readermdCancelPickedImage && window.readermdCancelPickedImage();");
            return;
        }

        var source = MakeImageSource(dialog.FileName, document.Path);
        var alt = Path.GetFileNameWithoutExtension(dialog.FileName);
        await ExecuteSecondaryScriptAsync(
            $"window.readermdInsertPickedImage && window.readermdInsertPickedImage({JsonSerializer.Serialize(source)}, {JsonSerializer.Serialize(alt)});");
    }

    private async Task ExecuteSecondaryScriptAsync(string script)
    {
        if (!_secondaryWebReady || SecondaryPreviewWebView.CoreWebView2 is null)
        {
            return;
        }

        try
        {
            await SecondaryPreviewWebView.CoreWebView2.ExecuteScriptAsync(script);
        }
        catch
        {
        }
    }

    private async Task RenderSecondaryDocumentAsync(bool force)
    {
        if (!_secondaryWebReady || _displayMode != DisplayMode.Split || SecondaryDocument is not { } document)
        {
            return;
        }

        SecondaryPreviewWebView.CoreWebView2?.SetVirtualHostNameToFolderMapping(
            "readermd-document.local",
            Path.GetDirectoryName(document.Path) ?? AppContext.BaseDirectory,
            CoreWebView2HostResourceAccessKind.DenyCors);

        var systemDark = IsDarkTheme();
        var renderKey = $"{document.Id:N}:{document.Revision}:{RichEditCheckBox.IsChecked == true}:{SelectedTheme()}:{systemDark}:{FindBox.Text}";
        if (!force && string.Equals(renderKey, _secondaryRenderKey, StringComparison.Ordinal))
        {
            return;
        }
        _secondaryRenderKey = renderKey;

        var payload = new
        {
            documentID = document.Id.ToString(),
            markdown = document.Content,
            revision = document.Revision,
            editable = RichEditCheckBox.IsChecked == true,
            theme = SelectedTheme(),
            readingStyle = "modern",
            customReadingPreset = (object?)null,
            systemDark,
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

        await ExecuteSecondaryScriptAsync(
            $"window.readermdRender && window.readermdRender({JsonSerializer.Serialize(payload)});");
    }

    private async void Enhanced_DocumentTabs_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (e.Source != DocumentTabs)
        {
            return;
        }

        await ActivateCurrentDocumentAsync();
        EnsureSecondarySelection();
        UpdateEnhancedWorkspaceState();
        UpdateSaveButtonState();
        UpdateSearchMatchCount();
        await RenderSecondaryDocumentAsync(force: true);
    }

    private void EnsureSecondarySelection()
    {
        if (SecondaryDocumentBox is null || _settingSecondarySelection)
        {
            return;
        }

        var current = CurrentDocument;
        var selected = SecondaryDocument;
        var candidate = selected;

        if (candidate is null || (ReferenceEquals(candidate, current) && _documents.Count > 1))
        {
            candidate = _documents.FirstOrDefault(document => !ReferenceEquals(document, current)) ?? current;
        }

        if (!ReferenceEquals(candidate, selected))
        {
            _settingSecondarySelection = true;
            SecondaryDocumentBox.SelectedItem = candidate;
            _settingSecondarySelection = false;
        }
    }

    private async void Enhanced_SecondaryDocumentChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_settingSecondarySelection || !IsLoaded)
        {
            return;
        }

        _secondaryRenderKey = null;
        await RenderSecondaryDocumentAsync(force: true);
        await ApplyExplicitThemeAsync(SecondaryPreviewWebView);
    }

    private void Enhanced_DocumentMode_Click(object sender, RoutedEventArgs e) => SetEnhancedDisplayMode(DisplayMode.Document);
    private void Enhanced_SplitMode_Click(object sender, RoutedEventArgs e) => SetEnhancedDisplayMode(DisplayMode.Split);
    private void Enhanced_SourceMode_Click(object sender, RoutedEventArgs e) => SetEnhancedDisplayMode(DisplayMode.Source);

    private async void SetEnhancedDisplayMode(DisplayMode mode)
    {
        _displayMode = mode;
        SourceEditor.Visibility = mode == DisplayMode.Source ? Visibility.Visible : Visibility.Collapsed;
        PreviewWebView.Visibility = mode == DisplayMode.Source ? Visibility.Collapsed : Visibility.Visible;
        SecondaryPane.Visibility = mode == DisplayMode.Split ? Visibility.Visible : Visibility.Collapsed;

        SourceColumn.Width = new GridLength(1, GridUnitType.Star);
        SplitDividerColumn.Width = mode == DisplayMode.Split ? new GridLength(5) : new GridLength(0);
        PreviewColumn.Width = mode == DisplayMode.Split ? new GridLength(1, GridUnitType.Star) : new GridLength(0);

        EnsureSecondarySelection();
        UpdateModeButtonAppearance();
        if (mode != DisplayMode.Source)
        {
            await RenderCurrentDocumentAsync(force: true);
        }
        if (mode == DisplayMode.Split)
        {
            await RenderSecondaryDocumentAsync(force: true);
        }
    }

    private async void Enhanced_RichEditChanged(object sender, RoutedEventArgs e)
    {
        _lastRenderKey = null;
        _secondaryRenderKey = null;
        await RenderCurrentDocumentAsync(force: true);
        await RenderSecondaryDocumentAsync(force: true);
    }

    private async void Enhanced_WidthSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (!IsLoaded)
        {
            return;
        }

        var script = $"window.readermdSetLayout && window.readermdSetLayout({(int)WidthSlider.Value}, true, 0, false);";
        await ExecuteScriptAsync(script);
        await ExecuteSecondaryScriptAsync(script);
    }

    private async void Enhanced_ThemeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        ApplyNativeTheme();
        if (!IsLoaded)
        {
            return;
        }

        var generation = ++_themeGeneration;
        await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ContextIdle);
        if (generation != _themeGeneration)
        {
            return;
        }

        _lastRenderKey = null;
        _secondaryRenderKey = null;
        await ApplyExplicitThemeToWebViewsAsync();
        await RenderCurrentDocumentAsync(force: true);
        await RenderSecondaryDocumentAsync(force: true);

        if (generation == _themeGeneration)
        {
            await ApplyExplicitThemeToWebViewsAsync();
        }
    }

    private Task ApplyExplicitThemeToWebViewsAsync()
    {
        return Task.WhenAll(
            ApplyExplicitThemeAsync(PreviewWebView),
            ApplyExplicitThemeAsync(SecondaryPreviewWebView));
    }

    private async Task ApplyExplicitThemeAsync(WebView2 webView)
    {
        if (webView.CoreWebView2 is null)
        {
            return;
        }

        var theme = SelectedTheme();
        var systemDark = IsDarkTheme();
        var script =
            $"window.readermdForceTheme && window.readermdForceTheme({JsonSerializer.Serialize(theme)}, {(systemDark ? "true" : "false")});";
        try
        {
            await webView.CoreWebView2.ExecuteScriptAsync(script);
        }
        catch
        {
        }
    }

    private void Enhanced_SourceEditor_TextChanged(object sender, TextChangedEventArgs e)
    {
        SourceEditor_TextChanged(sender, e);
        UpdateSaveButtonState();
        UpdateSearchMatchCount();
    }

    private async void Enhanced_Save_Click(object sender, RoutedEventArgs e)
    {
        await SaveCurrentEnhancedAsync();
    }

    private async void Enhanced_SaveAs_Click(object sender, RoutedEventArgs e)
    {
        await SaveCurrentAsEnhancedAsync();
    }

    private async Task<bool> SaveCurrentEnhancedAsync()
    {
        if (CurrentDocument is not { } document)
        {
            return false;
        }
        return await SaveDocumentEnhancedAsync(document, document.Path);
    }

    private async Task<bool> SaveCurrentAsEnhancedAsync()
    {
        if (CurrentDocument is not { } document)
        {
            return false;
        }

        var dialog = new SaveFileDialog
        {
            Title = "Save Markdown",
            Filter = "Markdown file|*.md|Text file|*.txt|All files|*.*",
            FileName = document.Title
        };
        if (dialog.ShowDialog(this) != true)
        {
            return false;
        }

        return await SaveDocumentEnhancedAsync(document, dialog.FileName);
    }

    private async Task<bool> SaveDocumentEnhancedAsync(DocumentTab document, string path)
    {
        try
        {
            File.WriteAllText(path, document.Content);
            document.Path = path;
            document.Title = Path.GetFileName(path);
            document.LastSavedContent = document.Content;
            document.IsDirty = false;
            RefreshTabHeader(document);
            if (ReferenceEquals(document, CurrentDocument))
            {
                PathStatus.Text = document.Path;
                Title = $"{document.Title} - ReaderMD";
            }
            UpdateSaveButtonState();
            UpdateSearchMatchCount();
            return true;
        }
        catch (Exception ex)
        {
            await ShowFluentDialogAsync(
                "Could not save the document",
                ex.Message,
                "OK",
                string.Empty,
                string.Empty);
            return false;
        }
    }

    private void UpdateSaveButtonState()
    {
        if (SaveButton is null)
        {
            return;
        }

        var dirty = CurrentDocument?.IsDirty == true;
        SaveButton.IsEnabled = dirty;
        SaveButton.Appearance = dirty ? ControlAppearance.Primary : ControlAppearance.Secondary;
        SaveButton.ToolTip = dirty ? "Save changes" : "No unsaved changes";
    }

    private async void Enhanced_Find_Click(object sender, RoutedEventArgs e)
    {
        if (SearchModeBox.SelectedIndex < 0)
        {
            SearchModeBox.SelectedIndex = 0;
        }
        FindBox.Focus();
        FindBox.SelectAll();
        await HighlightSearchInBothViewsAsync();
    }

    private async void Enhanced_FindBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        UpdateSearchMatchCount();
        await HighlightSearchInBothViewsAsync();
    }

    private async Task HighlightSearchInBothViewsAsync()
    {
        var script = $"window.readermdFind && window.readermdFind({JsonSerializer.Serialize(FindBox.Text ?? string.Empty)});";
        await ExecuteScriptAsync(script);
        await ExecuteSecondaryScriptAsync(script);
    }

    private void Enhanced_SearchModeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ReplacePanel is null)
        {
            return;
        }

        ReplacePanel.Visibility = SearchModeBox.SelectedIndex == 1 ? Visibility.Visible : Visibility.Collapsed;
        UpdateSearchMatchCount();
    }

    private void Enhanced_SearchOptionsChanged(object sender, RoutedEventArgs e)
    {
        UpdateSearchMatchCount();
    }

    private void UpdateSearchMatchCount()
    {
        if (SearchCountText is null)
        {
            return;
        }

        var count = CurrentDocument is { } document
            ? CountMatches(document.Content, FindBox?.Text ?? string.Empty)
            : 0;
        SearchCountText.Text = string.IsNullOrWhiteSpace(FindBox?.Text)
            ? string.Empty
            : count == 1 ? "1 match" : $"{count} matches";
    }

    private int CountMatches(string text, string query)
    {
        if (string.IsNullOrEmpty(query))
        {
            return 0;
        }

        try
        {
            return BuildSearchRegex(query).Matches(text).Count;
        }
        catch (RegexMatchTimeoutException)
        {
            return 0;
        }
    }

    private Regex BuildSearchRegex(string query)
    {
        var pattern = Regex.Escape(query);
        if (WholeWordCheckBox?.IsChecked == true)
        {
            pattern = $@"(?<![\p{{L}}\p{{N}}_]){pattern}(?![\p{{L}}\p{{N}}_])";
        }

        var options = RegexOptions.CultureInvariant;
        if (MatchCaseCheckBox?.IsChecked != true)
        {
            options |= RegexOptions.IgnoreCase;
        }

        return new Regex(pattern, options, TimeSpan.FromMilliseconds(300));
    }

    private async void Enhanced_ReplaceNext_Click(object sender, RoutedEventArgs e)
    {
        await ReplaceMatchesAsync(replaceAll: false);
    }

    private async void Enhanced_ReplaceAll_Click(object sender, RoutedEventArgs e)
    {
        await ReplaceMatchesAsync(replaceAll: true);
    }

    private async Task ReplaceMatchesAsync(bool replaceAll)
    {
        if (CurrentDocument is not { } document)
        {
            return;
        }

        var query = FindBox.Text ?? string.Empty;
        if (string.IsNullOrWhiteSpace(query))
        {
            await ShowFluentDialogAsync(
                "Find text first",
                "Enter the text you want to replace.",
                "OK",
                string.Empty,
                string.Empty);
            return;
        }

        var count = CountMatches(document.Content, query);
        UpdateSearchMatchCount();
        if (count == 0)
        {
            await ShowFluentDialogAsync(
                "No matches",
                $"“{query}” does not appear in this document with the selected options.",
                "OK",
                string.Empty,
                string.Empty);
            return;
        }

        var replacement = ReplaceBox.Text ?? string.Empty;
        var requestedCount = replaceAll ? count : 1;
        var actionText = replaceAll ? $"Replace all {count}" : "Replace next";
        var description =
            $"ReaderMD found {count} {(count == 1 ? "match" : "matches")} for “{query}”.\n\n" +
            $"Replace {(replaceAll ? "all matches" : "the next match")} with “{replacement}”?\n\n" +
            $"Match case: {(MatchCaseCheckBox.IsChecked == true ? "On" : "Off")} · Whole word: {(WholeWordCheckBox.IsChecked == true ? "On" : "Off")}";

        var result = await ShowFluentDialogAsync(
            "Confirm find and replace",
            description,
            actionText,
            string.Empty,
            "Cancel");
        if (result != ContentDialogResult.Primary)
        {
            return;
        }

        var regex = BuildSearchRegex(query);
        var updated = regex.Replace(document.Content, _ => replacement, requestedCount);
        if (updated == document.Content)
        {
            return;
        }

        document.Content = updated;
        document.Revision++;
        document.IsDirty = document.Content != document.LastSavedContent;
        _updatingSource = true;
        SourceEditor.Text = updated;
        _updatingSource = false;
        RefreshTabHeader(document);
        RefreshOutline(updated);
        UpdateDocumentStats(document);
        UpdateSaveButtonState();
        UpdateSearchMatchCount();

        _lastRenderKey = null;
        await RenderCurrentDocumentAsync(force: true);
        if (ReferenceEquals(SecondaryDocument, document))
        {
            _secondaryRenderKey = null;
            await RenderSecondaryDocumentAsync(force: true);
        }
    }

    private void Enhanced_FileList_PreviewMouseRightButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (ItemsControl.ContainerFromElement(FileList, e.OriginalSource as DependencyObject) is ListBoxItem item)
        {
            item.IsSelected = true;
        }
    }

    private void Enhanced_OpenSourceFolder_Click(object sender, RoutedEventArgs e)
    {
        if (FileList.SelectedItem is not WorkspaceFile file)
        {
            return;
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "explorer.exe",
                Arguments = $"/select,\"{file.Path}\"",
                UseShellExecute = true
            });
        }
        catch
        {
        }
    }

    private async void Enhanced_CloseTab_Click(object sender, RoutedEventArgs e)
    {
        e.Handled = true;
        if (sender is not System.Windows.Controls.Button { Tag: TabItem tab } || tab.Tag is not DocumentTab document)
        {
            return;
        }

        if (!await ConfirmDocumentCloseAsync(document))
        {
            return;
        }

        RemoveDocumentTab(tab, document);
    }

    private async void Enhanced_CloseAllTabs_Click(object sender, RoutedEventArgs e)
    {
        if (_documents.Count == 0)
        {
            return;
        }

        var dirty = _documents.Where(document => document.IsDirty).ToArray();
        if (dirty.Length > 0)
        {
            var result = await ShowFluentDialogAsync(
                "Close all tabs?",
                dirty.Length == 1
                    ? $"{dirty[0].Title} has unsaved changes."
                    : $"{dirty.Length} open documents have unsaved changes.",
                "Save all",
                "Discard all",
                "Cancel");

            if (result == ContentDialogResult.None)
            {
                return;
            }
            if (result == ContentDialogResult.Primary)
            {
                foreach (var document in dirty)
                {
                    if (!await SaveDocumentEnhancedAsync(document, document.Path))
                    {
                        return;
                    }
                }
            }
        }

        _documents.Clear();
        DocumentTabs.Items.Clear();
        SecondaryDocumentBox.SelectedItem = null;
        _outline.Clear();
        _updatingSource = true;
        SourceEditor.Text = string.Empty;
        _updatingSource = false;
        PathStatus.Text = "No document";
        StatsStatus.Text = string.Empty;
        Title = "ReaderMD";
        UpdateWorkspaceState();
        UpdateEnhancedWorkspaceState();
        UpdateSaveButtonState();
        UpdateSearchMatchCount();
    }

    private async Task<bool> ConfirmDocumentCloseAsync(DocumentTab document)
    {
        if (!document.IsDirty)
        {
            return true;
        }

        var result = await ShowFluentDialogAsync(
            "Save changes?",
            $"Save your changes to {document.Title} before closing it?",
            "Save",
            "Don't save",
            "Cancel");

        if (result == ContentDialogResult.None)
        {
            return false;
        }
        if (result == ContentDialogResult.Primary)
        {
            return await SaveDocumentEnhancedAsync(document, document.Path);
        }
        return true;
    }

    private void RemoveDocumentTab(TabItem tab, DocumentTab document)
    {
        var index = DocumentTabs.Items.IndexOf(tab);
        _documents.Remove(document);
        DocumentTabs.Items.Remove(tab);

        if (DocumentTabs.Items.Count > 0)
        {
            DocumentTabs.SelectedIndex = Math.Min(Math.Max(0, index), DocumentTabs.Items.Count - 1);
        }

        EnsureSecondarySelection();
        UpdateWorkspaceState();
        UpdateEnhancedWorkspaceState();
        UpdateSaveButtonState();
        UpdateSearchMatchCount();
        _ = RenderSecondaryDocumentAsync(force: true);
    }

    private void UpdateEnhancedWorkspaceState()
    {
        if (TabStrip is null)
        {
            return;
        }

        TabStrip.Visibility = _documents.Count == 0 ? Visibility.Collapsed : Visibility.Visible;
        CloseAllTabsButton.Visibility = _documents.Count > 1 ? Visibility.Visible : Visibility.Collapsed;
    }

    private async Task<ContentDialogResult> ShowFluentDialogAsync(
        string title,
        string message,
        string primaryButtonText,
        string secondaryButtonText,
        string closeButtonText)
    {
        var dialog = new ContentDialog(RootContentDialogHost)
        {
            Title = title,
            Content = new TextBlock
            {
                Text = message,
                TextWrapping = TextWrapping.Wrap,
                MaxWidth = 480,
                Margin = new Thickness(0, 4, 0, 4)
            },
            PrimaryButtonText = primaryButtonText,
            SecondaryButtonText = secondaryButtonText,
            CloseButtonText = closeButtonText,
            PrimaryButtonAppearance = ControlAppearance.Primary,
            SecondaryButtonAppearance = ControlAppearance.Secondary,
            CloseButtonAppearance = ControlAppearance.Secondary,
            DialogMaxWidth = 560
        };

        var primaryVisibility = PreviewWebView.Visibility;
        var secondaryVisibility = SecondaryPreviewWebView.Visibility;
        PreviewWebView.Visibility = Visibility.Hidden;
        SecondaryPreviewWebView.Visibility = Visibility.Hidden;
        try
        {
            return await dialog.ShowAsync();
        }
        finally
        {
            PreviewWebView.Visibility = primaryVisibility;
            SecondaryPreviewWebView.Visibility = secondaryVisibility;
        }
    }

    private void Enhanced_FocusMode_Click(object sender, RoutedEventArgs e)
    {
        SetEnhancedFocusMode(!_isFocusMode);
    }

    private void SetEnhancedFocusMode(bool enabled)
    {
        if (_isFocusMode == enabled)
        {
            return;
        }

        if (enabled)
        {
            _windowStateBeforeFocus = WindowState == WindowState.Minimized ? WindowState.Normal : WindowState;
        }

        _isFocusMode = enabled;
        Toolbar.Visibility = enabled ? Visibility.Collapsed : Visibility.Visible;
        SidebarColumn.Width = enabled ? new GridLength(0) : new GridLength(250);
        OutlineColumn.Width = enabled ? new GridLength(0) : new GridLength(230);
        ExitFocusButton.Visibility = enabled ? Visibility.Visible : Visibility.Collapsed;

        if (enabled)
        {
            WindowState = WindowState.Maximized;
        }
        else
        {
            WindowState = _windowStateBeforeFocus;
        }

        EnsureIntegratedChrome();
    }

    private async void Enhanced_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.F11)
        {
            e.Handled = true;
            SetEnhancedFocusMode(!_isFocusMode);
            return;
        }

        if (e.Key == Key.Escape && _isFocusMode)
        {
            e.Handled = true;
            SetEnhancedFocusMode(false);
            return;
        }

        if ((Keyboard.Modifiers & ModifierKeys.Control) == 0)
        {
            return;
        }

        if (e.Key == Key.S)
        {
            e.Handled = true;
            if ((Keyboard.Modifiers & ModifierKeys.Shift) != 0)
            {
                await SaveCurrentAsEnhancedAsync();
            }
            else
            {
                await SaveCurrentEnhancedAsync();
            }
        }
        else if (e.Key == Key.F)
        {
            e.Handled = true;
            FindBox.Focus();
            FindBox.SelectAll();
        }
    }

    private void Enhanced_Closing(object? sender, CancelEventArgs e)
    {
        if (_allowWindowClose)
        {
            return;
        }

        var dirty = _documents.Where(document => document.IsDirty).ToArray();
        if (dirty.Length == 0)
        {
            return;
        }

        e.Cancel = true;
        foreach (var document in dirty)
        {
            document.IsDirty = false;
        }

        Dispatcher.BeginInvoke(
            DispatcherPriority.Background,
            new Action(() =>
            {
                foreach (var document in dirty.Where(_documents.Contains))
                {
                    document.IsDirty = document.Content != document.LastSavedContent;
                    RefreshTabHeader(document);
                }

                if (!_deferredClosePending)
                {
                    _deferredClosePending = true;
                    _ = CompleteDeferredWindowCloseAsync();
                }
            }));
    }

    private async Task CompleteDeferredWindowCloseAsync()
    {
        var dirty = _documents.Where(document => document.IsDirty).ToArray();
        if (dirty.Length == 0)
        {
            _deferredClosePending = false;
            return;
        }

        var result = await ShowFluentDialogAsync(
            "Close ReaderMD?",
            dirty.Length == 1
                ? $"Save changes to {dirty[0].Title} before closing ReaderMD?"
                : $"{dirty.Length} documents have unsaved changes. Save them before closing ReaderMD?",
            dirty.Length == 1 ? "Save" : "Save all",
            dirty.Length == 1 ? "Don't save" : "Discard all",
            "Cancel");

        if (result == ContentDialogResult.None)
        {
            _deferredClosePending = false;
            UpdateSaveButtonState();
            return;
        }

        if (result == ContentDialogResult.Primary)
        {
            foreach (var document in dirty)
            {
                if (!await SaveDocumentEnhancedAsync(document, document.Path))
                {
                    _deferredClosePending = false;
                    return;
                }
            }
        }
        else
        {
            foreach (var document in dirty)
            {
                document.IsDirty = false;
            }
        }

        _allowWindowClose = true;
        _deferredClosePending = false;
        Close();
    }
}
