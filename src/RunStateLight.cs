using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace MaintOps;

/// <summary>Prominent run-state pill (master's spec, 2026-11-20):
/// 未运行[灰] / 运行中…[黄闪, 带不影响运行的提示则橙闪] / 运行错误已停止[红常亮] /
/// 运行完毕[绿常亮, 带提示则橙常亮] / 已手动停止[橙常亮]. Big bold heiti text so the
/// state reads across the desk at a glance.</summary>
public sealed class RunStateLight : Border
{
    private static SolidColorBrush F(Color c) { var b = new SolidColorBrush(c); b.Freeze(); return b; }
    private static SolidColorBrush Tint(Color c) { var b = new SolidColorBrush(Color.FromArgb(0x38, c.R, c.G, c.B)); b.Freeze(); return b; }

    private static readonly Color CGray = Color.FromRgb(0x9A, 0xA4, 0xB0);
    private static readonly Color CYellow = Color.FromRgb(0xE5, 0xC8, 0x4B);
    private static readonly Color COrange = Color.FromRgb(0xE8, 0xA0, 0x4E);
    private static readonly Color CRed = Color.FromRgb(0xE8, 0x5C, 0x5C);
    private static readonly Color CGreen = Color.FromRgb(0x6E, 0xC4, 0x76);

    private static readonly Brush Gray = F(CGray), Yellow = F(CYellow), Orange = F(COrange),
                                  Red = F(CRed), Green = F(CGreen);

    private readonly TextBlock _text = new()
    {
        FontFamily = new FontFamily("SimHei, Microsoft YaHei UI"),
        FontSize = 19,
        FontWeight = FontWeights.Bold,
        VerticalAlignment = VerticalAlignment.Center,
    };
    private readonly DispatcherTimer _blink;
    private bool _on = true;

    public RunStateLight()
    {
        Child = _text;
        Padding = new Thickness(12, 6, 12, 6);
        CornerRadius = new CornerRadius(6);
        BorderThickness = new Thickness(1.4);
        MinWidth = 158;
        HorizontalAlignment = HorizontalAlignment.Left;
        VerticalAlignment = VerticalAlignment.Center;
        _blink = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(450) };
        _blink.Tick += (_, _) => { _on = !_on; _text.Opacity = _on ? 1.0 : 0.35; };
        Show("未运行", Gray, F(Color.FromRgb(0x20, 0x26, 0x2E)), blink: false);
    }

    public void SetIdle()      => Show("未运行", Gray, F(Color.FromRgb(0x20, 0x26, 0x2E)), false);
    public void SetRunning(bool warn) => Show(warn ? "运行中… 有提示" : "运行中…",
        warn ? Orange : Yellow, warn ? Tint(COrange) : Tint(CYellow), true);
    public void SetError()     => Show("运行错误，已停止", Red, Tint(CRed), false);
    public void SetDone(bool warn) => Show(warn ? "运行完毕（有提示）" : "运行完毕",
        warn ? Orange : Green, warn ? Tint(COrange) : Tint(CGreen), false);
    public void SetKilled()    => Show("已手动停止", Orange, Tint(COrange), false);

    private void Show(string text, Brush fg, Brush bg, bool blink)
    {
        _blink.Stop();
        _on = true;
        _text.Opacity = 1.0;
        _text.Text = text;
        _text.Foreground = fg;
        Background = bg;
        BorderBrush = fg;
        if (blink) _blink.Start();
    }

    /// <summary>Stop the dispatcher timer before window teardown.</summary>
    public void Dispose() => _blink.Stop();
}
