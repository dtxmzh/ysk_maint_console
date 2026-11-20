using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;

namespace MaintOps;

/// <summary>Entry point. Pure-code WPF (no XAML) — same lessons as the model-monitor
/// floatie: no App.xaml means no source-generated second Main, no CS0102 duel.
/// Single-instance: a second launch just activates the live window and exits (this also
/// keeps the sync-log writer unique and avoids the 261120 multi-instance confusion).</summary>
public static class Program
{
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    private const int SW_RESTORE = 9;

    [STAThread]
    public static int Main(string[] args)
    {
        using var mutex = new Mutex(true, @"Local\ysk_maint_console_single_instance", out bool isNew);
        if (!isNew)
        {
            try
            {
                var me = Environment.ProcessId;
                foreach (var p in Process.GetProcessesByName("ysk_maint_console"))
                {
                    try
                    {
                        if (p.Id == me) continue;
                        var h = p.MainWindowHandle;
                        if (h != IntPtr.Zero) { ShowWindow(h, SW_RESTORE); SetForegroundWindow(h); break; }
                    }
                    catch { }
                    finally { p.Dispose(); }
                }
            }
            catch { }
            return 0;   // another copy already owns the desk
        }

        var app = new Application();
        app.ShutdownMode = ShutdownMode.OnMainWindowClose;
        var win = new MainWindow(Config.Load());
        win.Show();
        return app.Run(win);
    }
}
