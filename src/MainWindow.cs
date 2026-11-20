using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace MaintOps;

/// <summary>维护操作台 — window front-end for ysk_maint_console.ps1.
/// Left: grouped menu tree (loaded live from the script via -DumpMenu, so labels and
/// risk levels can never drift). Right: colored terminal echo (free Ctrl+C copy,
/// one-click export). Top-left: big bold run-state pill. Every click = one single-shot
/// pwsh -Run execution streamed back live.</summary>
public sealed class MainWindow : Window
{
    internal const string Version = "1.1.1";

    internal static SolidColorBrush F(Color c) { var b = new SolidColorBrush(c); b.Freeze(); return b; }
    internal static readonly Brush Bg    = F(Color.FromRgb(0x14, 0x18, 0x1D));
    internal static readonly Brush Panel = F(Color.FromRgb(0x1A, 0x1F, 0x26));
    internal static readonly Brush Line  = F(Color.FromRgb(0x33, 0x3D, 0x4A));
    internal static readonly Brush Fg    = F(Color.FromRgb(0xD8, 0xDE, 0xE9));
    internal static readonly Brush FgDim = F(Color.FromRgb(0x8A, 0x94, 0xA3));
    internal static readonly Brush Ok    = F(Color.FromRgb(0x6E, 0xC4, 0x76));
    internal static readonly Brush Bad   = F(Color.FromRgb(0xE0, 0x5C, 0x6E));
    internal static readonly Brush Warn  = F(Color.FromRgb(0xE8, 0xA0, 0x4E));
    internal static readonly Brush Accent= F(Color.FromRgb(0x5C, 0xC8, 0xE8));
    internal static readonly Brush BtnBg = F(Color.FromRgb(0x2A, 0x32, 0x3E));
    internal static readonly Brush BarGray   = F(Color.FromRgb(0x5A, 0x64, 0x70));
    internal static readonly Brush BarYellow = F(Color.FromRgb(0xE5, 0xC8, 0x4B));
    internal static readonly Brush BarOrange = F(Color.FromRgb(0xE8, 0xA0, 0x4E));
    internal static readonly Brush BarGreen  = F(Color.FromRgb(0x6E, 0xC4, 0x76));
    internal static readonly Brush BarRed    = F(Color.FromRgb(0xE0, 0x5C, 0x6E));

    private const string UiFont   = "Microsoft YaHei UI";
    private const string MonoFont = "Cascadia Mono, Consolas, Microsoft YaHei UI";

    private readonly Config _cfg;
    private readonly TerminalView _term;
    private readonly TreeView _tree = new();
    // 261120 开工装配 desk: the LEFT COLUMN alone flips between the assembly panel (default
    // tab) and the menu tree; terminal echo, lights and progress bar stay shared (master).
    private BlocksPanel _blocks = null!;
    private ScrollViewer _blocksView = null!;
    private Border _treeWrap = null!;
    private Button _tabAsm = null!, _tabTree = null!;
    private bool _tabOnAsm = true;
    private readonly RunStateLight _state = new();
    private readonly TextBlock _runningInfo = new()
    {
        Foreground = Fg, FontSize = 12.5, VerticalAlignment = VerticalAlignment.Center,
        Margin = new Thickness(10, 0, 6, 0), TextTrimming = TextTrimming.CharacterEllipsis,
    };
    private readonly TextBlock _mainInfo = new() { Foreground = FgDim, FontSize = 11.5, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 10, 0) };
    private readonly TextBlock _gpuTb    = new() { Foreground = FgDim, FontSize = 11.5, VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis, MaxWidth = 150 };
    private Button _btnKill = null!;
    private ProgressBar _bar = new();
    private TextBlock _barText = new();
    private DateTime _runStart;
    private string _finalBarText = "未运行";
    private readonly List<(TextBlock dot, Func<StatusModel, bool> pick)> _lights = new();

    private MenuDump? _menu;
    private bool _statusBusy;
    private int _statusTick;
    private bool _quitting;

    private string? _criticalRun;          // run key of the current "real" (side-effecting) task
    private int _activeCount;              // incl. read-only parallel runs
    private bool _anyWarn;
    private CancellationTokenSource? _activeCts;
    private long _lastOutputTick;          // watchdog: a run that prints nothing for minutes is probably stuck
    private bool _stallNoted;

    /// <summary>Stopping these mid-run only detaches the front-end; the backend action may
    /// continue regardless — warn before obeying the Kill button.</summary>
    private static readonly HashSet<string> KillAsk = new() { "h>3" };

    public MainWindow(Config cfg)
    {
        _cfg = cfg;
        _term = new TerminalView(MonoFont);
        _term.AttachLog(Path.Combine(cfg.ExeDir, "_data", "ysk_maint_console.log"));

        Title = "维护操作台";
        // master 261120 #2: remember the size/position from the last run (saved on close into
        // _data\ysk_win_layout.ini); fall back to the fixed comfortable 800x600 centered.
        // The layout itself is fully stretchable, so pulling the window bigger just works.
        var lay = WinLayout.Load(cfg.ExeDir);
        if (lay != null)
        {
            Left = lay.Left; Top = lay.Top; Width = lay.Width; Height = lay.Height;
            WindowStartupLocation = WindowStartupLocation.Manual;
            if (lay.Maximized) WindowState = WindowState.Maximized;
        }
        else
        {
            Width = 800; Height = 600;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
        }
        MinWidth = 780; MinHeight = 560;
        Background = Bg; Foreground = Fg;
        FontFamily = new FontFamily(UiFont); FontSize = 13;
        TryLoadIcon();

        try { Application.Current.DispatcherUnhandledException += OnUnhandled; } catch { }

        var root = new DockPanel();

        var top = BuildTopBar();
        DockPanel.SetDock(top, Dock.Top);
        root.Children.Add(top);

        var bottom = BuildButtonBar();
        DockPanel.SetDock(bottom, Dock.Bottom);
        root.Children.Add(bottom);

        _blocks = new BlocksPanel(this);
        _treeWrap = new Border { Child = _tree, Background = Panel };
        _blocksView = new ScrollViewer
        {
            Content = _blocks.Root,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Background = Panel, Padding = new Thickness(2, 2, 2, 4),
            Visibility = Visibility.Collapsed,
        };
        var leftHost = new Grid();
        leftHost.Children.Add(_treeWrap);
        leftHost.Children.Add(_blocksView);
        var leftDock = new DockPanel();
        var tabStrip = BuildTabStrip();
        DockPanel.SetDock(tabStrip, Dock.Top);
        leftDock.Children.Add(tabStrip);
        leftDock.Children.Add(leftHost);
        var treeBox = new Border
        {
            Width = 340, Background = Panel,
            BorderBrush = Line, BorderThickness = new Thickness(0, 0, 1, 0),
            Child = leftDock,
        };
        DockPanel.SetDock(treeBox, Dock.Left);
        root.Children.Add(treeBox);
        SetTab(true);   // assembly desk opens first (master's call 261120)

        root.Children.Add(_term.Control);   // fills the rest
        Content = root;

        _tree.Background = Panel;
        _tree.Foreground = Fg;
        _tree.BorderThickness = new Thickness(0);
        _tree.FontSize = 12.5;
        ScrollViewer.SetHorizontalScrollBarVisibility(_tree, ScrollBarVisibility.Disabled); // wrap instead of h-scroll
        _tree.ItemContainerStyle = WrapStyle();
        _tree.PreviewKeyDown += OnTreeKeyDown;
        // primitive, bulletproof double-click: MouseDown's second down carries ClickCount==2
        // (do NOT rely on Control.MouseDoubleClick bubbling off TreeViewItem headers).
        _tree.PreviewMouseDown += OnTreeMouseDown;
        _tree.ToolTip = "双击行内任意位置执行；⚠ 红色 = 危险操作（会弹强确认）";

        Loaded += OnLoadedAsync;
        Closing += OnClosing;
        PreviewKeyDown += OnKey;

        _statusTimer.Tick += async (_, _) => await RefreshStatusAsync();
        _statusTimer.Start();
        _uiTimer.Tick += OnUiTick;
        _uiTimer.Start();
    }

    private readonly DispatcherTimer _statusTimer = new() { Interval = TimeSpan.FromSeconds(3) };
    private readonly DispatcherTimer _uiTimer     = new() { Interval = TimeSpan.FromSeconds(1) };

    // ================= UI build =================

    private UIElement BuildTabStrip()
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal, Background = Panel };
        _tabAsm = MkTab("▶ 开工装配");
        _tabAsm.Click += (_, _) => SetTab(true);
        _tabTree = MkTab("≡ 菜单树");
        _tabTree.Click += (_, _) => SetTab(false);
        sp.Children.Add(_tabAsm);
        sp.Children.Add(_tabTree);
        return new Border { Child = sp, Background = Panel, BorderBrush = Line, BorderThickness = new Thickness(0, 0, 0, 1) };
    }

    private Button MkTab(string t) => new()
    {
        Content = t, FontSize = 12.5, Margin = new Thickness(4, 4, 2, 0),
        Padding = new Thickness(10, 4, 10, 4), Background = BtnBg, Foreground = FgDim,
        BorderBrush = Line,
    };

    private void SetTab(bool asm)
    {
        if (_blocks == null) return;
        _tabOnAsm = asm;
        _treeWrap.Visibility = asm ? Visibility.Collapsed : Visibility.Visible;
        _blocksView.Visibility = asm ? Visibility.Visible : Visibility.Collapsed;
        _tabAsm.Background = asm ? BtnBg : Panel;  _tabAsm.Foreground = asm ? Accent : FgDim;
        _tabTree.Background = !asm ? BtnBg : Panel; _tabTree.Foreground = !asm ? Accent : FgDim;
        if (asm) _blocks.ForceProbe();   // back to the desk: fresh truth ASAP
    }

    /// <summary>Entry point of the 开工装配 button. Strong-confirm the full plan, then run the
    /// single-shot b>1 through the very same kernel the menu tree uses.</summary>
    public async Task RunAssemblyAsync(string spec, string label, string planBody)
    {
        if (_criticalRun != null)
        {
            _term.AppendNote($"操作「{_criticalRun}」正在执行，请等它结束（或点「停止当前」）", true);
            return;
        }
        var body = planBody + "\n\n将以单发 pwsh 进程运行，输出实时回显在右侧。";
        if (!Dialogs.Confirm(this, "开工装配 · 一键装配", body, true)) return;
        await LaunchCoreAsync("b>1", label, spec, true);
    }

    private UIElement BuildTopBar()
    {
        var bar = new Border { Background = Panel, BorderBrush = Line, BorderThickness = new Thickness(0, 0, 0, 1), Padding = new Thickness(8, 6, 8, 6) };
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        _state.Margin = new Thickness(0, 0, 4, 0);
        Grid.SetColumn(_state, 0);
        grid.Children.Add(_state);

        Grid.SetColumn(_runningInfo, 1);
        grid.Children.Add(_runningInfo);

        var right = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        foreach (var (name, tip, pick) in new (string, string, Func<StatusModel, bool>)[]
        {
            ("8080", "Strata 主力引擎 (8080)", m => m.Strata),
            ("18200", "KVMem 备胎引擎 (18200)", m => m.Kvmem),
            ("9210", "缘狐声线 yosuko-tts (9210)", m => m.Tts),
            ("10808", "VPN sing-box (10808)", m => m.Vpn),
        })
        {
            var dot = new TextBlock { Text = "●", FontSize = 14, Foreground = FgDim, Margin = new Thickness(0, 0, 2, 0), VerticalAlignment = VerticalAlignment.Center };
            var lb = new TextBlock { Text = name, Foreground = FgDim, FontSize = 11, Margin = new Thickness(0, 0, 9, 0), VerticalAlignment = VerticalAlignment.Center };
            ToolTipService.SetToolTip(dot, tip);
            ToolTipService.SetToolTip(lb, tip);
            _lights.Add((dot, pick));
            right.Children.Add(dot);
            right.Children.Add(lb);
        }
        right.Children.Add(_mainInfo);
        right.Children.Add(_gpuTb);
        Grid.SetColumn(right, 2);
        grid.Children.Add(right);

        bar.Child = grid;
        return bar;
    }

    private UIElement BuildButtonBar()
    {
        _btnKill = MkBtn("停止");
        _btnKill.IsEnabled = false;
        _btnKill.Foreground = Bad;
        ToolTipService.SetToolTip(_btnKill, "强制终止当前运行的 pwsh 进程树 (等同终端 Ctrl+C)；快捷键: 无选区时 Ctrl+C 或 F6");

        var sp = new StackPanel { Orientation = Orientation.Horizontal };
        var btnCopy = MkBtn("复制全部");
        ToolTipService.SetToolTip(btnCopy, "把输出区全部内容放入剪贴板 (小范围复制: 鼠标选中后 Ctrl+C)");
        btnCopy.Click += (_, _) => { _term.CopyAllToClipboard(); _term.AppendNote("已复制全部文本到剪贴板"); };
        var btnExport = MkBtn("导出日志");
        ToolTipService.SetToolTip(btnExport, "把输出区当前内容另存为文本文件 (全量历史另看 _data\\ysk_maint_console.log)");
        btnExport.Click += OnExport;
        var btnClear = MkBtn("清屏");
        btnClear.Click += (_, _) => { _term.ClearAll(); _term.AppendNote("已清屏（磁盘同步日志仍保留全部历史）"); };
        // master 261120 #2: undo remembered geometry -> back to 800x600 centered, and forget
        // the remembered layout so the next launch also starts from the default.
        var btnResetWin = MkBtn("恢复窗口");
        ToolTipService.SetToolTip(btnResetWin, "把窗口恢复为默认 800x600 并居中，同时清除记住的位置（下次启动也从默认开始）");
        btnResetWin.Click += (_, _) => ResetWindowGeometry();
        sp.Children.Add(_btnKill);
        sp.Children.Add(btnCopy);
        sp.Children.Add(btnExport);
        sp.Children.Add(btnClear);
        sp.Children.Add(btnResetWin);

        // progress strip (master 261120): indeterminate glide while running, solid result fill after
        _bar = new ProgressBar
        {
            Height = 18,
            Minimum = 0,
            Maximum = 100,
            BorderBrush = Line,
            BorderThickness = new Thickness(1),
            Background = F(Color.FromRgb(0x20, 0x26, 0x2E)),
            Foreground = BarGray,
            Value = 100,
        };
        _barText = new TextBlock
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = Fg,
            Text = "未运行",
        };
        var progGrid = new Grid { Margin = new Thickness(10, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center, Height = 18 };
        progGrid.Children.Add(_bar);
        progGrid.Children.Add(_barText);

        var dock = new DockPanel { LastChildFill = true };
        DockPanel.SetDock(sp, Dock.Left);
        dock.Children.Add(sp);
        dock.Children.Add(progGrid);

        return new Border
        {
            Background = Panel, BorderBrush = Line, BorderThickness = new Thickness(0, 1, 0, 0),
            Padding = new Thickness(10, 5, 10, 5), Child = dock,
        };
    }

    private void BarRun()
    {
        _runStart = DateTime.Now;
        _bar.IsIndeterminate = true;
        _bar.Foreground = BarYellow;
        _barText.Text = "运行中 00:00";
    }

    private void BarWarn() => _bar.Foreground = BarOrange;

    private void BarFinal(string text, Brush br)
    {
        _bar.IsIndeterminate = false;
        _bar.Value = 100;
        _bar.Foreground = br;
        _finalBarText = text;
        _barText.Text = text;
    }

    private static string ElapStr(TimeSpan t)
        => t.TotalMinutes >= 1 ? $"{(int)t.TotalMinutes}分{t.Seconds:00}秒" : $"{t.TotalSeconds:0}秒";

    private Button MkBtn(string text) => new()
    {
        Content = text,
        MinWidth = 66,
        Padding = new Thickness(9, 4, 9, 4),
        Margin = new Thickness(0, 0, 6, 0),
        Background = BtnBg,
        Foreground = Fg,
        BorderBrush = Line,
        FontSize = 12.5,
    };

    private static Style WrapStyle()
    {
        var st = new Style(typeof(TreeViewItem));
        st.Setters.Add(new Setter(TextBlock.TextWrappingProperty, TextWrapping.Wrap));
        // Root cause of "double-click misses the row" (主人 261120 目撃実錘): the stock
        // TreeViewItem template puts the header in an AUTO-sized column, so the clickable
        // area is only the text width and the rest of the row is a dead zone. A custom
        // template with a star column + full-row transparent Border fixes hit-testing AND
        // gives proper whole-row hover/selection paint via template triggers.
        st.Setters.Add(new Setter(Control.TemplateProperty, TreeItemTemplate()));
        return st;
    }

    private static readonly System.Windows.Media.Brush RowHover = Frozen(0x2D, 0x2D, 0x30);
    private static readonly System.Windows.Media.Brush RowSel   = Frozen(0x1F, 0x3A, 0x5F);

    private static System.Windows.Media.Brush Frozen(byte r, byte g, byte b)
    {
        var br = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(r, g, b));
        br.Freeze();
        return br;
    }

    /// <summary>Minimal hand-built TreeViewItem template: [16px toggle][header fills the
    /// rest of the row] / children underneath. Built with FrameworkElementFactory so the
    /// app stays 100% XAML-free.</summary>
    private static ControlTemplate TreeItemTemplate()
    {
        // --- tiny toggle button template: ▸ / ▾ glyph swap, hit-tests its 16px cell ---
        var ttCell = new FrameworkElementFactory(typeof(Border));
        ttCell.SetValue(Border.BackgroundProperty, System.Windows.Media.Brushes.Transparent);
        ttCell.SetValue(FrameworkElement.WidthProperty, 16.0);
        ttCell.SetValue(FrameworkElement.HeightProperty, 16.0);
        var ttGrid = new FrameworkElementFactory(typeof(Grid));
        var glyphR = new FrameworkElementFactory(typeof(TextBlock), "gR");
        glyphR.SetValue(TextBlock.TextProperty, "▸");
        glyphR.SetValue(TextBlock.FontSizeProperty, 9.0);
        glyphR.SetValue(TextBlock.ForegroundProperty, FgDim);
        glyphR.SetValue(TextBlock.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        glyphR.SetValue(TextBlock.VerticalAlignmentProperty, VerticalAlignment.Center);
        var glyphD = new FrameworkElementFactory(typeof(TextBlock), "gD");
        glyphD.SetValue(TextBlock.TextProperty, "▾");
        glyphD.SetValue(TextBlock.FontSizeProperty, 9.0);
        glyphD.SetValue(TextBlock.ForegroundProperty, FgDim);
        glyphD.SetValue(TextBlock.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        glyphD.SetValue(TextBlock.VerticalAlignmentProperty, VerticalAlignment.Center);
        glyphD.SetValue(UIElement.VisibilityProperty, Visibility.Collapsed);
        ttGrid.AppendChild(glyphR);
        ttGrid.AppendChild(glyphD);
        ttCell.AppendChild(ttGrid);
        var ttTemplate = new ControlTemplate(typeof(ToggleButton)) { VisualTree = ttCell };
        ttTemplate.Triggers.Add(new Trigger
        {
            Property = ToggleButton.IsCheckedProperty, Value = true,
            Setters =
            {
                new Setter { TargetName = "gR", Property = UIElement.VisibilityProperty, Value = Visibility.Collapsed },
                new Setter { TargetName = "gD", Property = UIElement.VisibilityProperty, Value = Visibility.Visible },
            },
        });

        var toggle = new FrameworkElementFactory(typeof(ToggleButton), "toggle");
        toggle.SetValue(ToggleButton.TemplateProperty, ttTemplate);
        toggle.SetValue(ToggleButton.ClickModeProperty, ClickMode.Press);
        toggle.SetBinding(ToggleButton.IsCheckedProperty,
            new Binding(nameof(TreeViewItem.IsExpanded)) { RelativeSource = new RelativeSource(RelativeSourceMode.TemplatedParent) });
        toggle.SetBinding(UIElement.VisibilityProperty,
            new Binding(nameof(TreeViewItem.HasItems)) { RelativeSource = new RelativeSource(RelativeSourceMode.TemplatedParent), Converter = new BooleanToVisibilityConverter() });
        toggle.SetValue(Grid.ColumnProperty, 0);
        toggle.SetValue(Grid.RowProperty, 0);

        // --- header cell: fills the remaining row width, transparent = clickable end to end ---
        var hdr = new FrameworkElementFactory(typeof(Border), "hdrBd");
        hdr.SetValue(Border.BackgroundProperty, System.Windows.Media.Brushes.Transparent);
        hdr.SetValue(Grid.ColumnProperty, 1);
        hdr.SetValue(Grid.RowProperty, 0);
        var cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.ContentSourceProperty, "Header");
        cp.SetValue(FrameworkElement.HorizontalAlignmentProperty, HorizontalAlignment.Stretch);
        cp.SetValue(FrameworkElement.VerticalAlignmentProperty, VerticalAlignment.Center);
        hdr.AppendChild(cp);

        var items = new FrameworkElementFactory(typeof(ItemsPresenter), "itemsHost");
        items.SetValue(FrameworkElement.MarginProperty, new Thickness(16, 0, 0, 0));   // child indent (the look the stock template gave us)

        // Header line: [16px toggle][header Border fills the remaining width]
        // DockPanel+LastChildFill gives us "whole row clickable" with no column-definition
        // plumbing (FEFactory + Grid column defs is a known gray zone; this is rock solid).
        var line = new FrameworkElementFactory(typeof(DockPanel));
        line.SetValue(DockPanel.LastChildFillProperty, true);
        toggle.SetValue(DockPanel.DockProperty, Dock.Left);
        line.AppendChild(toggle);
        line.AppendChild(hdr);

        var root = new FrameworkElementFactory(typeof(StackPanel));
        root.SetValue(StackPanel.OrientationProperty, Orientation.Vertical);
        root.AppendChild(line);
        root.AppendChild(items);

        var t = new ControlTemplate(typeof(TreeViewItem)) { VisualTree = root };
        t.Triggers.Add(new Trigger
        {
            Property = TreeViewItem.IsExpandedProperty, Value = false,
            Setters = { new Setter { TargetName = "itemsHost", Property = UIElement.VisibilityProperty, Value = Visibility.Collapsed } },
        });
        t.Triggers.Add(new Trigger
        {
            Property = TreeViewItem.IsSelectedProperty, Value = true,
            Setters = { new Setter { TargetName = "hdrBd", Property = Border.BackgroundProperty, Value = RowSel } },
        });
        t.Triggers.Add(new MultiTrigger
        {
            Conditions =
            {
                new Condition(Control.IsMouseOverProperty, true),
                new Condition(TreeViewItem.IsSelectedProperty, false),
            },
            Setters = { new Setter { TargetName = "hdrBd", Property = Border.BackgroundProperty, Value = RowHover } },
        });
        return t;
    }

    private void PopulateTree(MenuDump dump)
    {
        _tree.Items.Clear();
        foreach (var e in dump.Main)
        {
            if (e.IsQuit) continue;
            if (e.IsGroup)
            {
                if (!dump.Groups.TryGetValue(e.Grp!, out var g)) continue;
                var gi = new TreeViewItem
                {
                    Header = new TextBlock { Text = $"[{e.K}]  {g.Title}", FontWeight = FontWeights.Bold, Foreground = Accent, TextWrapping = TextWrapping.Wrap },
                    IsExpanded = true,
                };
                foreach (var it in g.Items)
                {
                    if (it.IsQuit) continue;
                    gi.Items.Add(MakeLeaf($"{e.K}>{it.K}", it));
                }
                _tree.Items.Add(gi);
            }
            else
            {
                _tree.Items.Add(MakeLeaf(e.K, e));
            }
        }
        var exitItem = new TreeViewItem
        {
            Header = new TextBlock { Text = "✕  退出操作台", Foreground = FgDim },
            Tag = "EXIT",
        };
        _tree.Items.Add(exitItem);
    }

    private static TreeViewItem MakeLeaf(string runKey, MenuEntry e)
    {
        var mark = e.R == "danger" ? "⚠ " : "";
        var tb = new TextBlock
        {
            Text = $"[{runKey}]  {mark}{ShortT(e.T)}",
            TextWrapping = TextWrapping.NoWrap,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Foreground = e.R == "danger" ? Bad : (e.R == "confirm" ? Warn : Fg),
        };
        var tip = e.T + (string.IsNullOrEmpty(e.W) ? "" : "\n" + e.W);
        tb.ToolTip = tip;
        if (e.R == "danger") tb.FontWeight = FontWeights.SemiBold;
        return new TreeViewItem { Header = tb, Tag = (runKey, e), ToolTip = tip };
    }

    /// <summary>Tree labels show just the leading phrase; the full label (with its parenthetical
    /// hints) lives in the tooltip, the confirm dialog and the terminal echo.</summary>
    private static string ShortT(string t)
    {
        int cut = t.Length;
        var i = t.IndexOf(" (", StringComparison.Ordinal);
        if (i < 0) i = t.IndexOf('（');
        if (i >= 6) cut = i;
        if (cut > 40) cut = 40;
        return t[..cut].TrimEnd();
    }

    // ================= events =================

    private async void OnLoadedAsync(object sender, RoutedEventArgs e)
    {
        _term.AppendNote($"维护操作台 v{Version} 启动 (前端) · 脚本 = {_cfg.ScriptPath}");
        _term.AppendNote($"pwsh = {_cfg.PwshPath} · 双击行内任意位置执行 / 选中后回车执行");
        if (_term.LogPath != null) _term.AppendNote("同步日志: " + _term.LogPath + "（逐行落盘, 清屏不丢历史）");
        else _term.AppendNote("!! 磁盘日志没开成: " + _term.LogError, true);
        await RefreshStatusAsync();   // first pass: loads menu + paints lights
    }

    // self-managed double-click detection: do NOT rely on the OS promoting the second
    // down to ClickCount==2 (synthetic/injected clicks often miss the timing window).
    // Two downs on the SAME row within 1.2s = double-click.
    private TreeViewItem? _lastDownRow;
    private DateTime _lastDownAt = DateTime.MinValue;

    private void OnTreeMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed) return;
        var src = e.OriginalSource as DependencyObject;
        if (FindAncestor<ToggleButton>(src) != null) return;   // 16px arrow cell: default toggle
        var tvi = FindAncestor<TreeViewItem>(src);
        if (tvi == null) return;

        bool dbl = e.ClickCount >= 2
                || (ReferenceEquals(tvi, _lastDownRow) && (DateTime.UtcNow - _lastDownAt).TotalMilliseconds <= 1200);

        if (tvi.Tag is not (string key, MenuEntry entry))
        {
            if (tvi.Tag is "EXIT")
            {
                // quit needs the same double-click guard as leaves (fat-finger protection)
                if (!dbl) { _lastDownRow = tvi; _lastDownAt = DateTime.UtcNow; return; }
                _lastDownRow = null;
                Close(); e.Handled = true;
            }
            else
            {
                tvi.IsExpanded = !tvi.IsExpanded;   // group row: one click anywhere toggles
                e.Handled = true;
            }
            return;
        }

        if (!dbl) { _lastDownRow = tvi; _lastDownAt = DateTime.UtcNow; return; }
        _lastDownRow = null;   // consume, so a third click doesn't retrigger
        _ = ExecuteAsync(key, entry);
        e.Handled = true;
    }

    /// <summary>Keyboard path: arrows navigate the tree, Enter executes the highlighted leaf
    /// (group nodes just expand/collapse via the tree's built-in keys).</summary>
    private void OnTreeKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        if (_tree.SelectedItem is not TreeViewItem tvi) return;
        if (tvi.Tag is string s && s == "EXIT") { Close(); e.Handled = true; return; }
        if (tvi.Tag is (string key, MenuEntry entry))
        {
            _ = ExecuteAsync(key, entry);
            e.Handled = true;
        }
    }

    private void OnUiTick(object? sender, EventArgs e)
    {
        if (_activeCount > 0)
        {
            var t = DateTime.Now - _runStart;
            _barText.Text = $"运行中 {(int)t.TotalMinutes:00}:{t.Seconds:00}";

            // stall watchdog: a live run silent for 3+ minutes gets flagged (never auto-killed)
            var idle = Environment.TickCount64 - _lastOutputTick;
            if (idle > 180_000 && !_stallNoted)
            {
                _stallNoted = true;
                _state.SetRunning(true);
                _runningInfo.Text = "执行中: " + (_criticalRun ?? "") + "   ⚠ 已 3 分钟无输出，疑似卡住";
                _term.AppendNote($"提醒: {(_criticalRun ?? "执行")} 已 3 分钟没有输出。长编译/大下载属正常；若判断卡死，Ctrl+C 或 F6 强制终止。");
            }
            else if (_stallNoted && idle <= 180_000)
            {
                _stallNoted = false;
                _runningInfo.Text = "执行中: " + (_criticalRun ?? "");
            }
        }
        else
        {
            _barText.Text = _finalBarText;
        }
    }

    private void OnKill(object sender, RoutedEventArgs e) => KillNow();

    /// <summary>Force-kill the current run's whole pwsh process tree (terminal Ctrl+C feel).
    /// Bound to the Kill button, bare Ctrl+C when nothing is selected, and F6.</summary>
    private void KillNow()
    {
        if (_activeCts == null) return;
        if (_criticalRun != null && KillAsk.Contains(_criticalRun))
        {
            if (!Dialogs.Confirm(this, "停止确认",
                    $"「{_criticalRun}」正在执行：停止只会终止本窗口发起的 pwsh 进程树，脚本已放出去独立运行的动作（如网关自重启）可能仍会完成。确定停止？", true))
                return;
        }
        _term.AppendNote("请求强制终止当前执行（杀 pwsh 进程树）…");
        _activeCts.Cancel();
    }

    private void OnKey(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.F6)
        {
            if (_activeCts != null) { KillNow(); e.Handled = true; }
            return;
        }
        if (e.Key == Key.C && Keyboard.Modifiers == ModifierKeys.Control)
        {
            var sel = _term.Control.Selection;
            if ((sel == null || sel.IsEmpty) && _activeCts != null)
            {
                KillNow();   // Ctrl+C with no selection = interrupt, like a real terminal
                e.Handled = true;
            }
            // with a selection -> fall through to the RichTextBox default copy
        }
    }

    private void OnExport(object sender, RoutedEventArgs e)
    {
        var dlg = new Microsoft.Win32.SaveFileDialog
        {
            Title = "导出操作台日志",
            FileName = "ysk_操作台日志_" + DateTime.Now.ToString("yyMMdd_HHmm") + ".txt",
            Filter = "文本文件 (*.txt)|*.txt|所有文件 (*.*)|*.*",
            InitialDirectory = Directory.Exists(@"F:\WorkStation\ysk_work") ? @"F:\WorkStation\ysk_work" : _cfg.ExeDir,
        };
        if (dlg.ShowDialog(this) == true)
        {
            try
            {
                File.WriteAllText(dlg.FileName, _term.PlainText(), new UTF8Encoding(true));
                _term.AppendNote("已导出: " + dlg.FileName);
            }
            catch (Exception ex) { _term.AppendNote("导出失败: " + ex.Message, true); }
        }
    }

    /// <summary>Revert to the built-in window layout (800x600 centered on the virtual screen)
    /// and forget the remembered one, so the next launch starts fresh too.</summary>
    private void ResetWindowGeometry()
    {
        WinLayout.Clear(_cfg.ExeDir);
        WindowState = WindowState.Normal;
        Width = WinLayout.DefaultWidth; Height = WinLayout.DefaultHeight;
        Left = SystemParameters.VirtualScreenLeft + (SystemParameters.VirtualScreenWidth - Width) / 2;
        Top = SystemParameters.VirtualScreenTop + (SystemParameters.VirtualScreenHeight - Height) / 2;
        try { WinLayout.Of(this).Save(_cfg.ExeDir); } catch { }  // default persists right away
        _term.AppendNote("窗口已恢复默认 800x600 并居中（位置记忆已清除）");
    }

    private void OnClosing(object? sender, CancelEventArgs e)
    {
        if (_activeCount > 0 && !_quitting)
        {
            if (!Dialogs.Confirm(this, "退出确认", $"{_activeCount} 个执行仍在进行，退出将终止它们。确定退出？", true))
            { e.Cancel = true; return; }
        }
        _quitting = true;
        try { WinLayout.Of(this).Save(_cfg.ExeDir); } catch { }   // remember geometry for next launch
        _statusTimer.Stop();
        _uiTimer.Stop();
        _state.Dispose();
        _activeCts?.Cancel();
        _term.CloseLog();
    }

    private void OnUnhandled(object sender, DispatcherUnhandledExceptionEventArgs exArgs)
    {
        try { _term.AppendNote("界面异常已兜住: " + exArgs.Exception.Message, true); } catch { }
        exArgs.Handled = true;
    }

    // ================= execution =================

    private async Task ExecuteAsync(string runKey, MenuEntry entry)
    {
        if (_menu == null) { _term.AppendNote("菜单还在装载中，稍等一下", true); return; }

        bool critical = entry.R != null || entry.P != null;
        if (_criticalRun != null && critical)
        {
            _term.AppendNote($"操作「{_criticalRun}」正在执行，请等它结束（或点「停止当前」）", true);
            return;
        }

        string? arg = null;
        var spec = entry.P ?? "";
        if (spec.StartsWith("radio:", StringComparison.Ordinal))
        {
            var opts = new List<(string, string)>();
            foreach (var pair in spec[6..].Split('|'))
            {
                var i = pair.IndexOf('=');
                if (i <= 0) continue;
                opts.Add((pair[..i], pair[(i + 1)..]));
            }
            if (opts.Count == 0) { _term.AppendNote("参数定义解析失败: " + spec, true); return; }
            arg = Dialogs.Radio(this, entry.T, "请选择（对应旧菜单里的选项号）:", opts);
            if (arg == null) return;
        }
        else if (spec.Equals("bak", StringComparison.OrdinalIgnoreCase))
        {
            _term.AppendNote("正在读取回滚清单 -ListBak …");
            var (code, outp) = await ScriptRunner.CaptureAsync(_cfg, "-ListBak", 20000);
            BakItem[]? items = null;
            try { items = JsonSerializer.Deserialize<BakItem[]>(outp.Trim()); } catch { }
            if (code != 0 || items == null || items.Length == 0)
            {
                _term.AppendNote($"读不到回滚清单 (exit={code})，已取消", true);
                return;
            }
            var opts = items.Select(b => (b.I.ToString(), b.Label)).ToList();
            var pick = Dialogs.Radio(this, "Strata 引擎回滚 · 选一件装回", "按新旧排序，[1] = 最近换下:", opts);
            if (pick == null) return;
            arg = pick;
        }
        else if (spec.StartsWith("text:", StringComparison.Ordinal))
        {
            var typed = Dialogs.TextPrompt(this, entry.T, spec[5..], "留空 = 默认/自动");
            if (typed == null) return;
            arg = typed.Length > 0 ? typed : null;
        }

        if (entry.R != null)
        {
            var body = new StringBuilder();
            if (!string.IsNullOrEmpty(entry.W)) body.AppendLine(entry.W).AppendLine();
            body.Append("执行: ").Append(Disp(runKey, arg));
            body.AppendLine().Append("将以单发 pwsh 进程运行，输出实时回显在下方。");
            var title = (entry.R == "danger" ? "危险操作 · " : "确认操作 · ") + entry.T;
            if (!Dialogs.Confirm(this, title, body.ToString(), entry.R == "danger")) return;
        }

        await LaunchCoreAsync(runKey, $"[{runKey}] {entry.T}", arg, critical);
    }

    /// <summary>Single-shot launch + live echo + lights/bar/watchdog state machine. Shared by
    /// the tree double-click path and the 开工装配 desk so both behave identically (261120).</summary>
    private async Task LaunchCoreAsync(string runKey, string label, string? arg, bool critical)
    {
        // ---- launch ----
        if (critical) _criticalRun = runKey;
        _activeCount++;
        _anyWarn = false;
        var cts = new CancellationTokenSource();
        _activeCts = cts;
        try { _blocks.SetBusy(true); } catch { }

        _term.AppendCmd(label, Disp(runKey, arg));
        _btnKill.IsEnabled = true;
        _runningInfo.Text = "执行中: " + runKey;
        _state.SetRunning(false);
        BarRun();

        var prog = new Progress<string>(line =>
        {
            _lastOutputTick = Environment.TickCount64;
            if (IsWarnLine(line) && !_anyWarn)
            {
                _anyWarn = true;
                if (_activeCount > 0) { _state.SetRunning(true); BarWarn(); }
            }
            _term.AppendLine(line);
        });
        _lastOutputTick = Environment.TickCount64;
        _stallNoted = false;

        var res = await ScriptRunner.RunAsync(_cfg, runKey, arg, prog, cts.Token);
        _term.AppendResult(runKey, res.ExitCode, res.Elapsed, res.Killed);

        _activeCount--;
        if (_criticalRun == runKey) _criticalRun = null;
        if (_activeCount <= 0)
        {
            _activeCts = null;
            _btnKill.IsEnabled = false;
            _runningInfo.Text = "";
            if (res.Killed) { _state.SetKilled(); BarFinal($"已手动停止 · {ElapStr(res.Elapsed)}", BarOrange); }
            else if (res.ExitCode != 0) { _state.SetError(); BarFinal($"运行错误 exit={res.ExitCode} · {ElapStr(res.Elapsed)}", BarRed); }
            else if (_anyWarn) { _state.SetDone(true); BarFinal($"运行完毕（有提示） · {ElapStr(res.Elapsed)}", BarOrange); }
            else { _state.SetDone(false); BarFinal($"运行完毕 · {ElapStr(res.Elapsed)}", BarGreen); }
            try { _blocks.SetBusy(false); _blocks.ForceProbe(); } catch { }
        }
        cts.Dispose();
    }

    private string Disp(string runKey, string? arg)
        => $"{Path.GetFileName(_cfg.PwshPath)} -NoProfile -ExecutionPolicy Bypass -File {Path.GetFileName(_cfg.ScriptPath)} -Run {runKey}"
           + (arg != null ? $" -Arg \"{arg}\"" : "");

    private static bool IsWarnLine(string l)
        => l.StartsWith("[stderr]") || l.Contains("!!") || l.Contains("失败")
           || l.Contains("不对账") || l.Contains("拒绝") || l.Contains("超时") || l.Contains("中止");

    // ================= status refresh =================

    private async Task RefreshStatusAsync()
    {
        if (_quitting || _statusBusy) return;
        _statusBusy = true;
        try
        {
            if (_menu == null)
            {
                var (code, outp) = await ScriptRunner.CaptureAsync(_cfg, "-DumpMenu", 25000);
                if (_quitting) return;
                MenuDump? dump = null;
                try { dump = JsonSerializer.Deserialize<MenuDump>(outp.Trim()); } catch { }
                if (dump != null && dump.Main.Count > 0)
                {
                    _menu = dump;
                    Dispatcher.Invoke(() => PopulateTree(dump));
                    _term.AppendNote($"菜单已装载: 一级 {dump.Main.Count} 项 · {dump.Groups.Count} 组");
                }
                else
                {
                    _term.AppendNote($"菜单装载失败 (exit={code})：{Short(outp)}", true);
                    _term.AppendNote($"请确认脚本存在: {_cfg.ScriptPath}", true);
                    Dispatcher.Invoke(() =>
                    {
                        MessageBox.Show(this,
                            "无法从脚本读取菜单 (-DumpMenu)。\n\n脚本路径: " + _cfg.ScriptPath +
                            "\n\n可在 exe 同目录 ysk_maint_console.ini 里用 script= 指定正确路径。",
                            "维护操作台 启动失败", MessageBoxButton.OK, MessageBoxImage.Error);
                        Close();
                    });
                    return;
                }
            }

            var m = await StatusProbe.SampleAsync(_cfg);

            // assembly desk feed: the full -BlocksState probe costs ~3s of pwsh, so it runs on
            // its own 10s cadence, never while a run is live, and only while the tab is open.
            if (_tabOnAsm && _activeCount == 0 && _blocks != null && _blocks.DueForProbe())
            {
                var (bc, bo) = await ScriptRunner.CaptureAsync(_cfg, "-BlocksState", 15000);
                BlocksDump? bd = null;
                try { bd = JsonSerializer.Deserialize<BlocksDump>(bo.Trim()); } catch { }
                if (bd != null && !_quitting) Dispatcher.Invoke(() => _blocks.ApplyDump(bd));
            }

            (string text, bool warn)? gpu = null;
            if (++_statusTick % 10 == 1) gpu = await StatusProbe.GpuAsync();
            if (_quitting) return;
            Dispatcher.Invoke(() =>
            {
                foreach (var (dot, pick) in _lights) dot.Foreground = pick(m) ? Ok : Bad;
                _mainInfo.Text = "主力: " + m.Main;
                if (gpu != null) { _gpuTb.Text = gpu.Value.text; _gpuTb.Foreground = gpu.Value.warn ? Warn : FgDim; }
            });
        }
        finally { _statusBusy = false; }
    }

    private static string Short(string s)
    {
        s = s.Replace("\r", " ").Replace("\n", " ").Trim();
        return s.Length > 200 ? s[..200] + "…" : s;
    }

    private void TryLoadIcon()
    {
        try { Icon = new BitmapImage(new Uri("pack://application:,,,/app.ico", UriKind.Absolute)); }
        catch { /* ico missing -> default app icon */ }
    }

    private static T? FindAncestor<T>(DependencyObject? o) where T : DependencyObject
    {
        while (o != null)
        {
            if (o is T t) return t;
            o = (o is System.Windows.Media.Media3D.Visual3D || o is Visual)
                ? VisualTreeHelper.GetParent(o)
                : LogicalTreeHelper.GetParent(o);
        }
        return null;
    }
}
