using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace MaintOps;

// ---------- -BlocksState JSON model (single source of truth = $BLOCKS in the ps1) ----------

public sealed class BlockInfo
{
    [JsonPropertyName("id")]    public string  Id    { get; set; } = "";
    [JsonPropertyName("n")]     public string  N     { get; set; } = "";
    [JsonPropertyName("full")]  public string  Full  { get; set; } = "";
    [JsonPropertyName("port")]  public int     Port  { get; set; }
    [JsonPropertyName("st")]    public string  St    { get; set; } = "off";   // off|cpu|gpu|up
    [JsonPropertyName("zero")]  public bool    Zero  { get; set; }
    [JsonPropertyName("gate")]  public string  Gate  { get; set; } = "";
    [JsonPropertyName("g")]     public string  G     { get; set; } = "";
    [JsonPropertyName("gcur")]  public string  Gcur  { get; set; } = "none";  // none|off|armed|missing
    [JsonPropertyName("card")]  public string? Card  { get; set; }            // live physical seat: gpu0|gpu1|cpu|null
    [JsonPropertyName("dflt")]  public string  Dflt  { get; set; } = "";
    [JsonPropertyName("cards")] public string[] Cards { get; set; } = Array.Empty<string>();
}

public sealed class StrataProbe { [JsonPropertyName("alive")] public bool Alive { get; set; } }

public sealed class BlocksDump
{
    [JsonPropertyName("gpu")]    public string[] Gpu    { get; set; } = Array.Empty<string>();
    [JsonPropertyName("strata")] public StrataProbe StrataS { get; set; } = new();
    [JsonPropertyName("router")] public bool Router     { get; set; }
    [JsonPropertyName("blocks")] public BlockInfo[] Blocks { get; set; } = Array.Empty<BlockInfo>();
}

/// <summary>「开工装配」desk (GUI first tab, 261120 master's build-blocks design). One row per
/// block, ordered by assembly likelihood (ps1 $BLOCKS order): checkbox = keep it seated,
/// dropdown = which device (auto / GPU0 / GPU1 / CPU when the block supports it), a second
/// tiny checkbox arms/disarms that block's scheduled guard task. 启动Strata runs ONE
/// single-shot b>1: unchecked blocks are released, checked blocks mount (picked card) before
/// Strata, and every guard change is folded into one final elevated pass (single UAC).
/// Checkboxes/pick lists hold the USER's intent once touched; the live probe only refreshes
/// status chips, GPU headroom and the guard column, never stomping pending choices.</summary>
public sealed class BlocksPanel
{
    private static SolidColorBrush F(Color c) { var b = new SolidColorBrush(c); b.Freeze(); return b; }
    private static readonly Brush Panel  = MainWindow.Panel;
    private static readonly Brush Line   = MainWindow.Line;
    private static readonly Brush Fg     = MainWindow.Fg;
    private static readonly Brush FgDim  = MainWindow.FgDim;
    private static readonly Brush Ok     = MainWindow.Ok;
    private static readonly Brush Bad    = MainWindow.Bad;
    private static readonly Brush Warn   = MainWindow.Warn;
    private static readonly Brush Accent = MainWindow.Accent;
    private static readonly Brush BtnBg  = MainWindow.BtnBg;
    private static readonly Brush RowBg  = F(Color.FromRgb(0x20, 0x26, 0x2E));

    private static readonly Dictionary<string, string> CardLabel = new()
    {
        ["auto"] = "自动", ["gpu0"] = "GPU0", ["gpu1"] = "GPU1", ["cpu"] = "CPU",
    };

    private readonly MainWindow _main;
    private readonly StackPanel _rows = new();
    private readonly TextBlock _hint = new()
    {
        Text = "正在读取积木状态…", Foreground = FgDim, FontSize = 11,
        TextWrapping = TextWrapping.Wrap, Margin = new Thickness(6, 4, 6, 2),
    };
    private Button _go = null!;
    private Button _recheck = null!;
    private TextBlock _goHint = null!;
    private readonly List<Row> _rowList = new();

    private DateTime _lastProbe = DateTime.MinValue;
    private BlocksDump? _last;
    private bool _busy;

    private sealed class Row
    {
        public BlockInfo Info = null!;
        public CheckBox Main = null!;
        public ComboBox Pick = null!;
        public CheckBox? Guard;
        public TextBlock Chip = null!;
        public bool TouchMain, TouchGuard, TouchPick;
    }

    public BlocksPanel(MainWindow main) { _main = main; }

    private FrameworkElement? _root;
    public FrameworkElement Root => _root ??= Build();

    private FrameworkElement Build()
    {
        var head = new TextBlock
        {
            Text = "积木装配台 · 勾选=在岗，下拉=指定卡；「启动 Strata」一键落座（先小件后主力）",
            Foreground = FgDim, FontSize = 11, TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(6, 6, 6, 2),
        };

        var foot = new StackPanel { Orientation = Orientation.Vertical, Margin = new Thickness(4, 6, 4, 4) };
        _go = new Button
        {
            Content = "▶  启动 Strata",
            Background = F(Color.FromRgb(0x1E, 0x44, 0x52)),
            Foreground = Accent,
            BorderBrush = Accent,
            FontWeight = FontWeights.Bold,
            FontSize = 13.5,
            Padding = new Thickness(10, 8, 10, 8),
            Margin = new Thickness(0, 0, 0, 4),
        };
        ToolTipService.SetToolTip(_go, "一键装配：不勾的积木全部退出，勾选的按指定卡就位，最后拉起 Strata（已在岗则复用）。守护勾选集中在最后一次 UAC 处理。");
        _go.Click += (_, _) =>
        {
            if (_last == null || _busy) return;
            _ = _main.RunAssemblyAsync(BuildSpec(), "[b>1] 开工装配 · 一键装配", BuildPlan());
        };
        _recheck = new Button
        {
            Content = "重新读取", Background = BtnBg, Foreground = Fg, BorderBrush = Line,
            FontSize = 11.5, Padding = new Thickness(8, 4, 8, 4), Margin = new Thickness(0, 0, 0, 3),
        };
        ToolTipService.SetToolTip(_recheck, "放弃未执行的勾选改动，按最新实况重新摆好所有复选框/下拉");
        _recheck.Click += (_, _) => { ResetTouched(); _lastProbe = DateTime.MinValue; ForceApplyIfLoaded(); };
        _goHint = new TextBlock { Foreground = FgDim, FontSize = 10.5, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(2, 0, 2, 0), Text = "门槛只在点火一刻评估 —— 先小件后 Strata，Strata 弹性让步共存。" };
        foot.Children.Add(_go);
        foot.Children.Add(_recheck);
        foot.Children.Add(_goHint);

        var dock2 = new DockPanel { LastChildFill = true };
        DockPanel.SetDock(foot, Dock.Bottom);
        dock2.Children.Add(foot);
        var bodyStack = new StackPanel { Orientation = Orientation.Vertical };
        bodyStack.Children.Add(head);
        bodyStack.Children.Add(_rows);
        bodyStack.Children.Add(_hint);
        dock2.Children.Add(bodyStack);
        return dock2;
    }

    // ================= probe cadence =================

    public bool DueForProbe() => !_busy && (DateTime.Now - _lastProbe).TotalSeconds >= 10;
    public void ForceProbe() { _lastProbe = DateTime.MinValue; }

    public void SetBusy(bool busy)
    {
        _busy = busy;
        _go.IsEnabled = !busy && _last != null;
        _recheck.IsEnabled = !busy;
        _goHint.Text = busy ? "装配执行中… 实时回显在右侧终端" : "门槛只在点火一刻评估 —— 先小件后 Strata，Strata 弹性让步共存。";
        if (busy) _hint.Text = "装配执行中…（本面板在结束后 10 秒内自动刷新）";
    }

    // ================= render / refresh =================

    public void ApplyDump(BlocksDump d)
    {
        _lastProbe = DateTime.Now;
        _last = d;
        if (_rowList.Count == 0) BuildRows(d);
        else foreach (var r in _rowList)
        {
            var bi = d.Blocks.FirstOrDefault(b => b.Id == r.Info.Id);
            if (bi != null) r.Info = bi;   // script older/newer than the panel: keep last known row
        }

        foreach (var r in _rowList)
        {
            var b = r.Info;
            if (!r.TouchMain) r.Main.IsChecked = b.St != "off";
            if (!r.TouchPick) r.Pick.SelectedIndex = IndexOfCard(r, LiveCardOf(b));
            if (r.Guard != null && !r.TouchGuard && b.Gcur != "missing") r.Guard.IsChecked = b.Gcur == "armed";
            r.Chip.Text = ChipText(b);
            r.Chip.Foreground = ChipBrush(b);
        }
        _go.Content = Rows.Any(x => x.Info.Id == "comfy" && x.Main.IsChecked == true)
            ? "▶  装配 (ComfyUI 主卡 · 本轮不拉 Strata)"
            : "▶  启动 Strata";
        _hint.Text = HintText(d);
        UpdateGoEnabled();
    }

    private void BuildRows(BlocksDump d)
    {
        foreach (var b in d.Blocks)
        {
            var row = new Row { Info = b };
            var border = new Border
            {
                Background = RowBg, BorderBrush = Line, BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(4), Margin = new Thickness(4, 2, 4, 2),
                Padding = new Thickness(6, 4, 6, 4),
            };
            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            row.Main = new CheckBox
            {
                Content = b.N, Foreground = Fg, FontSize = 12.5,
                VerticalAlignment = VerticalAlignment.Center,
                ToolTip = b.Full + "\n门槛: " + b.Gate,
            };
            row.Main.Checked += (_, _) => { row.TouchMain = true; UpdateGoContent(); UpdateGoEnabled(); };
            row.Main.Unchecked += (_, _) => { row.TouchMain = true; UpdateGoContent(); UpdateGoEnabled(); };
            Grid.SetColumn(row.Main, 0);
            grid.Children.Add(row.Main);

            if (b.Cards.Length > 1)
            {
                row.Pick = new ComboBox
                {
                    Width = 74, FontSize = 11.5, Margin = new Thickness(4, 0, 4, 0),
                    Background = BtnBg, Foreground = Fg, BorderBrush = Line,
                    Style = ComboSkin.Combo, ItemContainerStyle = ComboSkin.Item,
                    VerticalAlignment = VerticalAlignment.Center,
                    ToolTip = "载入到哪张卡: 自动 = 该件内置默认 (" + b.Dflt + ")；改卡会自动退出重拉起",
                };
                foreach (var c in b.Cards) row.Pick.Items.Add(CardLabel.GetValueOrDefault(c, c));
                row.Pick.SelectionChanged += (_, _) =>
                {
                    if (!_busy) { row.TouchPick = true; }
                };
                Grid.SetColumn(row.Pick, 1);
                grid.Children.Add(row.Pick);
            }
            else
            {
                row.Pick = new ComboBox { Visibility = Visibility.Collapsed, Width = 0 };
                row.Pick.Items.Add("CPU");   // single implicit option
            }

            row.Chip = new TextBlock
            {
                Text = "…", FontSize = 11, Foreground = FgDim,
                VerticalAlignment = VerticalAlignment.Center, MinWidth = 70, TextAlignment = TextAlignment.Right,
            };
            Grid.SetColumn(row.Chip, 2);
            grid.Children.Add(row.Chip);

            var stack = new StackPanel();
            stack.Children.Add(grid);
            if (b.G.Length > 0)
            {
                var sub = new Grid { Margin = new Thickness(20, 2, 0, 0) };
                sub.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                sub.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                row.Guard = new CheckBox
                {
                    // TextBlock content, NOT a bare string: '_' in a string Content is eaten as
                    // an Alt-mnemonic by WPF (yosuko task names are full of underscores).
                    Content = new TextBlock { Text = "守护 (" + b.G.Split('\\')[^1] + ")" },
                    FontSize = 10.5, Foreground = FgDim,
                    ToolTip = "开机自启+猝死复活。默认停用（手动挡政策 261120）；改动集中在装配末尾一次 UAC 处理。当前: " + b.Gcur,
                };
                row.Guard.Checked += (_, _) => row.TouchGuard = true;
                row.Guard.Unchecked += (_, _) => row.TouchGuard = true;
                Grid.SetColumn(row.Guard, 0);
                sub.Children.Add(row.Guard);
                var gate = new TextBlock
                {
                    Text = b.Zero ? "零显存" : b.Gate, FontSize = 10, Foreground = FgDim,
                    VerticalAlignment = VerticalAlignment.Center,
                };
                Grid.SetColumn(gate, 1);
                sub.Children.Add(gate);
                stack.Children.Add(sub);
            }
            border.Child = stack;
            _rows.Children.Add(border);
            _rowList.Add(row);
        }
    }

    private static string LiveCardOf(BlockInfo b) =>
        b.St == "off" ? "auto"
        : b.Card is not null && b.Cards.Contains(b.Card) ? b.Card
        : b.Cards.Length == 1 ? b.Cards[0]
        : "auto";

    private static int IndexOfCard(Row r, string card)
    {
        var cards = r.Info.Cards;
        int i = Array.IndexOf(cards, card);
        return i >= 0 ? i : (cards.Length > 0 ? 0 : -1);
    }

    private string SelectedCard(Row r)
    {
        var cards = r.Info.Cards;
        if (cards.Length == 0) return "auto";
        if (cards.Length == 1) return cards[0];
        int i = r.Pick.SelectedIndex;
        return i >= 0 && i < cards.Length ? cards[i] : "auto";
    }

    private static string ChipText(BlockInfo b) => b.St switch
    {
        "gpu" => "GPU在岗·" + CardShort(b.Card),
        "up"  => "在岗·" + CardShort(b.Card),
        "cpu" => "CPU在岗",
        _     => "离线",
    };
    private static string CardShort(string? card) => card switch
    {
        "gpu0" => "卡0", "gpu1" => "卡1", "cpu" => "CPU", _ => "?",
    };
    private static Brush ChipBrush(BlockInfo b) => b.St switch
    {
        "gpu" or "up" => Ok,
        "cpu"         => b.Zero ? FgDim : Warn,
        _             => FgDim,
    };

    private static string HintText(BlocksDump d)
    {
        var sb = new StringBuilder();
        foreach (var g in d.Gpu)
        {
            var p = g.Split(", ");
            if (p.Length >= 3 && int.TryParse(p[1], out var free) && int.TryParse(p[2], out var total))
                sb.Append($"GPU{p[0]} 空 {free / 1024.0:0.0}G/{total / 1024.0:0}G   ");
        }
        sb.Append(d.StrataS.Alive ? "Strata 在岗" : "Strata 离线");
        if (d.Router) sb.Append(" · 18207 网关在岗");
        return sb.ToString();
    }

    private void UpdateGoContent()
    {
        if (_last == null) return;
        _go.Content = Rows.Any(x => x.Info.Id == "comfy" && x.Main.IsChecked == true)
            ? "▶  装配 (ComfyUI 主卡 · 本轮不拉 Strata)"
            : "▶  启动 Strata";
    }
    private void UpdateGoEnabled() { _go.IsEnabled = !_busy && _last != null; }

    private void ResetTouched()
    {
        foreach (var r in _rowList) { r.TouchMain = r.TouchGuard = r.TouchPick = false; }
        if (_last != null) ApplyDump(_last);
    }
    private void ForceApplyIfLoaded() { if (_last != null) ApplyDump(_last); }

    private IEnumerable<Row> Rows => _rowList;

    // ================= spec + plan for b>1 =================

    public string BuildSpec()
    {
        if (_last == null) return "";
        var parts = new List<string>();
        foreach (var r in _rowList)
        {
            parts.Add($"{r.Info.Id}={(r.Main.IsChecked == true ? 1 : 0)}");
            if (r.Guard != null) parts.Add($"g.{r.Info.Id}={(r.Guard.IsChecked == true ? 1 : 0)}");
            var pick = SelectedCard(r);
            if (r.Info.Cards.Length > 1 && pick != "auto") parts.Add($"pick.{r.Info.Id}={pick}");
        }
        return string.Join(",", parts);
    }

    public string BuildPlan()
    {
        var up = Rows.Where(r => r.Main.IsChecked == true).OrderBy(r => r.Info.Id == "comfy")
            .Select(r =>
            {
                var pick = SelectedCard(r);
                var seat = pick == "auto" ? "默认卡(" + r.Info.Dflt + ")" : CardLabel.GetValueOrDefault(pick, pick);
                return $"  载入 {r.Info.N} → {seat}";
            });
        var down = Rows.Where(r => r.Main.IsChecked != true && r.Info.St != "off")
            .Select(r => $"  退出 {r.Info.N}");
        var guards = Rows.Where(r => r.Guard != null && r.Info.Gcur != "missing")
            .Select(r => $"  守护 {r.Info.G.Split('\\')[^1]} → {(r.Guard!.IsChecked == true ? "启用" : "停用")}"
                       + (r.Guard.IsChecked == (r.Info.Gcur == "armed") ? "（现状一致，不弹UAC）" : ""));
        var sb = new StringBuilder();
        sb.AppendLine("按勾选一键装配（先小件后 Strata，门槛在点火一刻评估）：");
        foreach (var s in up)   sb.AppendLine(s);
        foreach (var s in down) sb.AppendLine(s);
        foreach (var s in guards) sb.AppendLine(s);
        bool comfy = Rows.Any(r => r.Info.Id == "comfy" && r.Main.IsChecked == true);
        sb.AppendLine(comfy ? "  ComfyUI 勾选 → 本轮不拉 Strata（独吞一张卡）"
                            : "  最后: 拉起 Strata 8080（已在岗则复用不重载）");
        sb.AppendLine();
        sb.Append("守护变更集中在最后一次 UAC（普通权限改不动的任务才弹）；提权助手跑完自行退出。");
        return sb.ToString();
    }
}
