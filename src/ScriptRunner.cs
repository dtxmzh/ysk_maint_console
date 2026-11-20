using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace MaintOps;

public sealed record RunResult(int ExitCode, TimeSpan Elapsed, bool Killed);

/// <summary>Single-shot runner: every GUI click spawns ONE pwsh that executes one menu item
/// (-Run key) and exits. No stateful REPL, no prompt sniffing — the script itself prints
/// everything, we just stream stdout/stderr back line by line. stdin is closed right away
/// so any unfed Ask()/Read-Host falls to its null -> safe default branch (verified 261120).</summary>
public static class ScriptRunner
{
    static ScriptRunner()
    {
        // git-bash shims on PATH can shadow real tools for child processes; keep the env honest
        // (nothing here goes through the system proxy either — the script handles --noproxy itself)
    }

    public static async Task<RunResult> RunAsync(Config cfg, string runKey, string? arg,
        IProgress<string> onLine, CancellationToken cancel)
    {
        var psi = new ProcessStartInfo
        {
            FileName = cfg.PwshPath,
            WorkingDirectory = System.IO.Path.GetDirectoryName(cfg.ScriptPath) ?? cfg.ExeDir,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-ExecutionPolicy");
        psi.ArgumentList.Add("Bypass");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(cfg.ScriptPath);
        if (runKey.Length > 0)
        {
            psi.ArgumentList.Add("-Run");
            psi.ArgumentList.Add(runKey);
            if (!string.IsNullOrEmpty(arg))
            {
                psi.ArgumentList.Add("-Arg");
                psi.ArgumentList.Add(arg);
            }
        }

        var sw = Stopwatch.StartNew();
        using var proc = new Process { StartInfo = psi };
        var killed = false;
        proc.OutputDataReceived += (_, e) => { if (e.Data != null) onLine.Report(e.Data); };
        proc.ErrorDataReceived  += (_, e) => { if (e.Data != null) onLine.Report("[stderr] " + e.Data); };

        try { proc.Start(); }
        catch (Exception ex)
        {
            onLine.Report("!! 无法启动 " + cfg.PwshPath + " : " + ex.Message);
            return new RunResult(-1, sw.Elapsed, false);
        }

        try { proc.StandardInput.Close(); } catch { }   // EOF = Ask() falls back to safe null
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        using var reg = cancel.Register(() =>
        {
            killed = true;
            try { proc.Kill(true); } catch { try { proc.Kill(); } catch { } }
        });

        int code;
        try { await proc.WaitForExitAsync().ConfigureAwait(false); code = proc.ExitCode; }
        catch (Exception ex) { onLine.Report("!! 等待进程结束出错: " + ex.Message); code = -1; }

        sw.Stop();
        return new RunResult(code, sw.Elapsed, killed);
    }

    /// <summary>Quick synchronous-ish helper for JSON probes (-DumpMenu / -ListBak):
    /// returns whole stdout, capped by a timeout.</summary>
    public static async Task<(int Code, string Out)> CaptureAsync(Config cfg, string extraArg, int timeoutMs)
    {
        var psi = new ProcessStartInfo
        {
            FileName = cfg.PwshPath,
            WorkingDirectory = System.IO.Path.GetDirectoryName(cfg.ScriptPath) ?? cfg.ExeDir,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
        };
        foreach (var a in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", cfg.ScriptPath, extraArg })
            psi.ArgumentList.Add(a);
        using var proc = Process.Start(psi)!;
        try { proc.StandardInput.Close(); } catch { }
        var outTask = proc.StandardOutput.ReadToEndAsync();
        var errTask = proc.StandardError.ReadToEndAsync();
        using var cts = new CancellationTokenSource(timeoutMs);
        try { await proc.WaitForExitAsync(cts.Token).ConfigureAwait(false); }
        catch (OperationCanceledException) { try { proc.Kill(true); } catch { } }
        var o = await outTask.ConfigureAwait(false);
        var e = await errTask.ConfigureAwait(false);
        var code = proc.HasExited ? proc.ExitCode : -1;
        return (code, o.Length > 0 ? o : e);
    }
}
