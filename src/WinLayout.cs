using System;
using System.Globalization;
using System.IO;
using System.Windows;

namespace MaintOps;

/// <summary>Persists the main window geometry so the console reopens exactly where the
/// master left it (master request 261120). Stored as plain key=value under _data\,
/// separate from the hand-edited ysk_maint_console.ini so machine state never dirties it.
/// "Restore window" button clears this file and snaps back to the built-in default.</summary>
public sealed class WinLayout
{
    public double Left, Top, Width, Height;
    public bool Maximized;

    // built-in default: 800x600 centered on screen
    public const double DefaultWidth = 800, DefaultHeight = 600;

    private static string FilePath(string exeDir) =>
        Path.Combine(exeDir, "_data", "ysk_win_layout.ini");

    public static WinLayout? Load(string exeDir)
    {
        try
        {
            var f = FilePath(exeDir);
            if (!File.Exists(f)) return null;
            double l = double.NaN, t = double.NaN, w = double.NaN, h = double.NaN;
            bool mx = false;
            foreach (var raw in File.ReadAllLines(f))
            {
                var line = raw.Trim();
                if (line.Length == 0 || line.StartsWith('#') || line.StartsWith(';')) continue;
                var i = line.IndexOf('=');
                if (i <= 0) continue;
                var k = line[..i].Trim();
                var v = line[(i + 1)..].Trim();
                switch (k.ToLowerInvariant())
                {
                    case "left":   l = D(v); break;
                    case "top":    t = D(v); break;
                    case "width":  w = D(v); break;
                    case "height": h = D(v); break;
                    case "maximized": mx = v == "1" || v.Equals("true", StringComparison.OrdinalIgnoreCase); break;
                }
            }
            if (double.IsNaN(l) || double.IsNaN(t) || double.IsNaN(w) || double.IsNaN(h)) return null;
            // sanity: plausible size, and the rect still intersects the virtual screen
            // (otherwise a unplugged monitor would strand the window off-screen forever)
            if (w < 200 || h < 150 || w > 20000 || h > 20000) return null;
            var vl = SystemParameters.VirtualScreenLeft;
            var vt = SystemParameters.VirtualScreenTop;
            var vw = SystemParameters.VirtualScreenWidth;
            var vh = SystemParameters.VirtualScreenHeight;
            if (l + w < vl + 40 || l > vl + vw - 40 || t + h < vt + 40 || t > vt + vh - 40) return null;
            return new WinLayout { Left = l, Top = t, Width = w, Height = h, Maximized = mx };
        }
        catch { return null; }

        static double D(string s) =>
            double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var d) ? d : double.NaN;
    }

    /// <summary>Capture the window's restore-bounds geometry (not the maximized bounds) so
    /// reopening after a maximized close lands back at the size the master dragged.
    /// RestoreBounds already means "current bounds unless maximized/minimized".</summary>
    public static WinLayout Of(Window w)
    {
        var b = w.RestoreBounds;
        return new WinLayout
        {
            Left = b.Left, Top = b.Top,
            Width = Math.Max(b.Width, 200), Height = Math.Max(b.Height, 150),
            Maximized = w.WindowState == WindowState.Maximized,
        };
    }

    public void Save(string exeDir)
    {
        try
        {
            var f = FilePath(exeDir);
            Directory.CreateDirectory(Path.GetDirectoryName(f)!);
            File.WriteAllText(f,
                "# window geometry saved on close - delete this file or press [reset window]\n" +
                $"left={L(Left)}\ntop={L(Top)}\nwidth={L(Width)}\nheight={L(Height)}\n" +
                $"maximized={(Maximized ? 1 : 0)}\n",
                new System.Text.UTF8Encoding(false));
        }
        catch { /* best-effort; console log records nothing important here */ }

        static string L(double v) => v.ToString("0.##", CultureInfo.InvariantCulture);
    }

    public static void Clear(string exeDir)
    {
        try { var f = FilePath(exeDir); if (File.Exists(f)) File.Delete(f); } catch { }
    }
}
