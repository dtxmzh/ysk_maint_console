using System;
using System.Collections.Generic;
using System.IO;

namespace MaintOps;

/// <summary>Runtime config. Optional ini file next to the exe:
///   [ysk_maint_console]
///   script=D:\...\ysk_maint_console.ps1
///   pwsh=C:\...\pwsh.exe
/// Missing ini = sane defaults for the master's machine, so the exe is drop-in.</summary>
public sealed class Config
{
    public string ScriptPath { get; }
    public string PwshPath { get; }
    public string ExeDir { get; }

    private Config(string script, string pwsh, string exeDir)
    { ScriptPath = script; PwshPath = pwsh; ExeDir = exeDir; }

    public static Config Load()
    {
        var exeDir = AppContext.BaseDirectory.TrimEnd('\\');
        var kv = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var ini = Path.Combine(exeDir, "ysk_maint_console.ini");
        if (File.Exists(ini))
        {
            try
            {
                foreach (var raw in File.ReadAllLines(ini))
                {
                    var line = raw.Trim();
                    if (line.Length == 0 || line.StartsWith('#') || line.StartsWith('[') || line.StartsWith(';')) continue;
                    var i = line.IndexOf('=');
                    if (i <= 0) continue;
                    kv[line[..i].Trim()] = line[(i + 1)..].Trim().Trim('"');
                }
            }
            catch { /* unreadable ini -> defaults */ }
        }

        var script = PickFirst(
            kv.GetValueOrDefault("script"),
            Path.Combine(exeDir, "ysk_maint_console.ps1"),                      // co-located copy (offline suites)
            @"D:\ProgramFiles\ysk_tools\run\ysk_maint_console.ps1");            // master box resident script

        var pwsh = PickFirst(
            kv.GetValueOrDefault("pwsh"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                         @"Microsoft\WindowsApps\pwsh.exe"),                    // Store PowerShell 7 (proven path on this box)
            @"C:\Program Files\PowerShell\7\pwsh.exe",
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                         @"WindowsPowerShell\v1.0\powershell.exe"));            // 5.1 fallback (plain rendering, still works)

        return new Config(script ?? "", pwsh ?? "", exeDir);
    }

    private static string? PickFirst(params string?[] cands)
    {
        foreach (var c in cands)
        {
            if (string.IsNullOrWhiteSpace(c)) continue;
            if (File.Exists(c)) return c;
        }
        // for the script we must end with something even if missing, so the UI can report the path clearly
        return cands.Length > 0 ? (cands[0] is { Length: > 0 } s0 ? s0 : cands[1]) : null;
    }
}
