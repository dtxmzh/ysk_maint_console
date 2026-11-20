using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;

namespace MaintOps;

/// <summary>The terminal-ish output area: read-only RichTextBox (native mouse selection +
/// Ctrl+C), mirrored plain-text buffer for one-click export, semantic line coloring.</summary>
public sealed class TerminalView
{
    private const int MaxBlocks = 5000;
    private static readonly Regex AnsiRe = new(@"\x1b\[[0-9;?]*[A-Za-z]", RegexOptions.Compiled);

    // dark console palette
    private static readonly Brush Bg       = Frozen(new SolidColorBrush(Color.FromRgb(0x12, 0x16, 0x1B)));
    private static readonly Brush Fg       = Frozen(new SolidColorBrush(Color.FromRgb(0xD8, 0xDE, 0xE9)));
    private static readonly Brush FgDim    = Frozen(new SolidColorBrush(Color.FromRgb(0x7A, 0x86, 0x96)));
    private static readonly Brush FgTitle  = Frozen(new SolidColorBrush(Color.FromRgb(0x5C, 0xC8, 0xE8)));
    private static readonly Brush FgOk     = Frozen(new SolidColorBrush(Color.FromRgb(0x8F, 0xC8, 0x8F)));
    private static readonly Brush FgErr    = Frozen(new SolidColorBrush(Color.FromRgb(0xE8, 0x7A, 0x8A)));
    private static readonly Brush FgInfo   = Frozen(new SolidColorBrush(Color.FromRgb(0xB4, 0x8C, 0xDA)));
    private static readonly Brush FgCmd    = Frozen(new SolidColorBrush(Color.FromRgb(0x6F, 0xA3, 0xD8)));

    private static Brush Frozen(SolidColorBrush b) { b.Freeze(); return b; }

    public RichTextBox Control { get; }
    private readonly List<string> _plain = new();
    private int _plainTrimmed;
    private static readonly Regex TimeRe = new(@"^\[\d{2}:\d{2}:\d{2}\]", RegexOptions.Compiled);

    // ---- synchronized on-disk log (master's ask 261120: complete mirror, survives 清屏) ----
    private StreamWriter? _logW;
    public string? LogPath { get; private set; }
    public string? LogError { get; private set; }

    /// <summary>Start mirroring every displayed line to `path` (UTF-8, CRLF, per-line flush).
    /// Rotates a previous oversized log to <path>.old on startup; never throws.</summary>
    public void AttachLog(string path)
    {
        try
        {
            var dir = Path.GetDirectoryName(path)!;
            Directory.CreateDirectory(dir);
            var fi = new FileInfo(path);
            if (fi.Exists && fi.Length > 6L * 1024 * 1024)
            {
                var old = path + ".old";
                if (File.Exists(old)) File.Delete(old);
                File.Move(path, old);
            }
            _logW = new StreamWriter(new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite),
                                     new UTF8Encoding(false)) { AutoFlush = true, NewLine = "\r\n" };
            LogPath = path;
            Log("——— 维护操作台 会话开始 ———");
        }
        catch (Exception ex) { LogError = ex.Message; }
    }

    public void Log(string text)
    {
        if (_logW == null) return;
        try { _logW.WriteLine($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {text}"); }
        catch (Exception ex) { LogError = ex.Message; var w = _logW; _logW = null; try { w?.Dispose(); } catch { } }
    }

    public TerminalView(string fontFamilies)
    {
        Control = new RichTextBox
        {
            IsReadOnly = true,
            IsDocumentEnabled = true,
            FontFamily = new FontFamily(fontFamilies),
            FontSize = 11.5,
            Background = Bg,
            Foreground = Fg,
            BorderThickness = new Thickness(0),
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            Padding = new Thickness(8, 6, 8, 6),
        };
        Control.Document.PageWidth = 2000;   // let long lines scroll instead of wrapping everywhere
    }

    public int NextSeq { get; private set; }

    /// <summary>Prints the block header for a freshly launched run: seq + label + the exact command line.</summary>
    public void AppendCmd(string label, string cmdline)
    {
        NextSeq++;
        var stamp = DateTime.Now.ToString("HH:mm:ss");
        AddStyled($"━━━━ #{NextSeq} {stamp}  {label} ━━━━", FgTitle, bold: true);
        AddStyled("$ " + cmdline, FgDim);
    }

    public void AppendLine(string line, Brush? force = null)
    {
        var clean = AnsiRe.Replace(line, "");
        AddStyled(clean, force ?? Colorize(clean));
    }

    public void AppendNote(string text, bool err = false)
        => AddStyled("» " + text, err ? FgErr : FgInfo);

    public void AppendResult(string runKey, int exit, TimeSpan elapsed, bool killed)
    {
        var mins = elapsed.TotalMinutes >= 1 ? $"  用时 {elapsed.TotalMinutes:0.0} 分钟" : $"  用时 {elapsed.TotalSeconds:0.0} 秒";
        if (killed)      AddStyled($"—— [{runKey}] 已手动终止 (exit={exit}){mins} ——", FgErr, bold: true);
        else if (exit == 0) AddStyled($"—— [{runKey}] 完成 exit=0{mins} ——", FgOk, bold: true);
        else             AddStyled($"—— [{runKey}] 结束 exit={exit}{mins} ——", FgErr, bold: true);
    }

    public void ClearAll()
    {
        Control.Document.Blocks.Clear();
        _plain.Clear(); _plainTrimmed = 0; NextSeq = 0;
    }

    public void CloseLog()
    {
        try { Log("——— 会话结束 ———"); _logW?.Dispose(); } catch { }
        _logW = null;
    }

    public string PlainText() => string.Join(Environment.NewLine, _plain);

    public void CopyAllToClipboard()
    {
        try { Clipboard.SetText(PlainText()); } catch { }
    }

    // ---- internals ----

    private void AddStyled(string text, Brush brush, bool bold = false)
    {
        var run = new Run(text) { Foreground = brush };
        if (bold) run.FontWeight = FontWeights.Bold;
        var para = new Paragraph(run)
        {
            Margin = new Thickness(0, 0, 0, 1),
            LineHeight = 15,
            LineStackingStrategy = LineStackingStrategy.BlockLineHeight,
        };
        Control.Document.Blocks.Add(para);
        while (Control.Document.Blocks.Count > MaxBlocks)
        {
            Control.Document.Blocks.Remove(Control.Document.Blocks.FirstBlock!);
            _plainTrimmed++;
        }
        _plain.Add(text);
        Log(text);
        Control.ScrollToEnd();
    }

    private static Brush Colorize(string l)
    {
        if (l.Length == 0) return Fg;
        if (l.StartsWith("[stderr]")) return FgErr;
        if (l.Contains("!!") || l.Contains("失败") || l.Contains("中止") || l.Contains("不对账")
            || l.Contains("拒绝") || l.Contains("猝死") || l.Contains("无法")) return FgErr;
        if (l.Contains("====")) return FgTitle;
        if (l.StartsWith("--- ") || l.StartsWith("  ---")) return FgInfo;
        if (l.Contains("当前主力") || l.Contains("引擎:") || l.Contains("服务:")
            || Regex.IsMatch(l, @"GPU\d ?余") || l.Contains("在役")) return FgInfo;
        if (l.Contains("完成") || l.Contains("成功") || l.Contains("就绪") || l.Contains("MATCH")
            || l.Contains("healthy") || l.Contains("OK") || l.Contains("已写入") || l.Contains("已启用")
            || l.Contains("已恢复") || l.Contains("已定版")) return FgOk;
        if (TimeRe.IsMatch(l)) return Fg;
        return Fg;
    }
}
