using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace MaintOps;

/// <summary>Small code-built dialogs (messagebox-style but themed + multiline + radio/text forms).
/// Kept deliberately plain: simple stack of labels/buttons, no styles to fight.</summary>
public static class Dialogs
{
    private static readonly Brush Bg      = Frozen(Color.FromRgb(0x1A, 0x1F, 0x26));
    private static readonly Brush Fg      = Frozen(Color.FromRgb(0xD8, 0xDE, 0xE9));
    private static readonly Brush FgDim   = Frozen(Color.FromRgb(0x8A, 0x94, 0xA3));
    private static readonly Brush FgErr   = Frozen(Color.FromRgb(0xE8, 0x7A, 0x8A));
    private static readonly Brush BtnBg   = Frozen(Color.FromRgb(0x2A, 0x32, 0x3E));
    private static readonly Brush BtnBrd  = Frozen(Color.FromRgb(0x3E, 0x4A, 0x5A));
    private static readonly Brush Danger  = Frozen(Color.FromRgb(0xB5, 0x3A, 0x4A));

    private static SolidColorBrush Frozen(Color c) { var b = new SolidColorBrush(c); b.Freeze(); return b; }

    public static bool Confirm(Window owner, string title, string body, bool danger)
    {
        var (win, panel) = NewWindow(owner, title, 560);
        panel.Children.Add(Text(body, danger ? FgErr : Fg, 13, wrap: true));
        var ok = Button(danger ? "确认执行" : "执行", danger ? Danger : BtnBg);
        var no = Button("取消", BtnBg);
        ok.IsDefault = true; no.IsCancel = true;
        ok.Click += (_, _) => { win.DialogResult = true; };
        no.Click += (_, _) => { win.DialogResult = false; };
        panel.Children.Add(Buttons(ok, no));
        return win.ShowDialog() == true;
    }

    /// <summary>Radio list; returns the chosen value or null on cancel.</summary>
    public static string? Radio(Window owner, string title, string hint, IReadOnlyList<(string val, string label)> opts)
    {
        if (opts.Count == 0) return null;
        var (win, panel) = NewWindow(owner, title, Math.Max(520, 0));
        if (hint.Length > 0) panel.Children.Add(Text(hint, FgDim, 12, wrap: true));
        var radios = new List<RadioButton>();
        foreach (var (val, label) in opts)
        {
            var rb = new RadioButton
            {
                Content = label,
                Tag = val,
                Foreground = Fg,
                Margin = new Thickness(2, 5, 2, 5),
                FontFamily = owner.FontFamily,
                GroupName = "opt",
            };
            radios.Add(rb);
            panel.Children.Add(rb);
        }
        radios[0].IsChecked = true;
        string? result = null;
        var go = Button("执行", BtnBg); var no = Button("取消", BtnBg);
        go.IsDefault = true; no.IsCancel = true;
        go.Click += (_, _) =>
        {
            foreach (var rb in radios)
                if (rb.IsChecked == true) { result = (string)rb.Tag!; break; }
            win.DialogResult = result != null;
        };
        no.Click += (_, _) => { win.DialogResult = false; };
        panel.Children.Add(Buttons(go, no));
        win.ShowDialog();
        return result;
    }

    /// <summary>One-line text input; returns null on cancel, the typed text (may be empty) on ok.</summary>
    public static string? TextPrompt(Window owner, string title, string hint, string watermark)
    {
        var (win, panel) = NewWindow(owner, title, 520);
        if (hint.Length > 0) panel.Children.Add(Text(hint, FgDim, 12, wrap: true));
        var tb = new TextBox
        {
            FontSize = 13,
            FontFamily = owner.FontFamily,
            Padding = new Thickness(4),
            Margin = new Thickness(2, 6, 2, 2),
        };
        panel.Children.Add(tb);
        string? result = null;
        var go = Button("确定", BtnBg); var no = Button("取消", BtnBg);
        go.IsDefault = true; no.IsCancel = true;
        go.Click += (_, _) => { result = tb.Text.Trim(); win.DialogResult = true; };
        no.Click += (_, _) => { win.DialogResult = false; };
        panel.Children.Add(Buttons(go, no));
        win.Loaded += (_, _) => { tb.Focus(); };
        win.ShowDialog();
        return result;
    }

    // ---- helpers ----

    private static (Window, StackPanel) NewWindow(Window owner, string title, double width)
    {
        var panel = new StackPanel { Margin = new Thickness(16, 12, 16, 12) };
        var scr = new ScrollViewer
        {
            Content = panel,
            MaxHeight = 560,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
        };
        var win = new Window
        {
            Title = title,
            Owner = owner,
            Content = scr,
            Width = width > 0 ? width : double.NaN,
            SizeToContent = SizeToContent.WidthAndHeight,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            ShowInTaskbar = false,
            Background = Bg,
            Foreground = Fg,
            FontFamily = owner.FontFamily,
            WindowStyle = WindowStyle.SingleBorderWindow,
        };
        return (win, panel);
    }

    private static TextBlock Text(string s, Brush fg, double size, bool wrap = false) => new()
    {
        Text = s,
        Foreground = fg,
        FontSize = size,
        TextWrapping = wrap ? TextWrapping.Wrap : TextWrapping.NoWrap,
        Margin = new Thickness(2, 2, 2, 8),
    };

    private static Button Button(string text, Brush bg) => new()
    {
        Content = text,
        MinWidth = 86,
        Padding = new Thickness(10, 5, 10, 5),
        Margin = new Thickness(6, 0, 0, 0),
        Background = bg,
        Foreground = Fg,
        BorderBrush = BtnBrd,
    };

    private static StackPanel Buttons(params Button[] btns)
    {
        var sp = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 12, 0, 0),
        };
        foreach (var b in btns) sp.Children.Add(b);
        return sp;
    }
}
