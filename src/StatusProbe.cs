using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace MaintOps;

/// <summary>Tiny live probe for the top status strip: engine ports + Hermes main provider +
/// GPU free VRAM. Deliberately dumb: TcpClient 400ms per port, config.yaml first lines,
/// one nvidia-smi every 30s. The ps1 console remains the authority; this is ambient light.</summary>
public sealed class StatusModel
{
    public bool Strata { get; set; }
    public bool Kvmem { get; set; }
    public bool Tts { get; set; }
    public bool Vpn { get; set; }
    public string Main { get; set; } = "?";
    public string Gpu { get; set; } = "GPU --";
    public bool GpuWarn { get; set; }
}

public static class StatusProbe
{
    private static readonly Regex ProviderRe = new(@"^\s*provider:\s*(\S+)", RegexOptions.Compiled);

    public static async Task<StatusModel> SampleAsync(Config cfg)
    {
        var m = new StatusModel();
        var s = PortAliveAsync(8080); var k = PortAliveAsync(18200);
        var t = PortAliveAsync(9210); var v = PortAliveAsync(10808);
        await Task.WhenAll(s, k, t, v).ConfigureAwait(false);
        m.Strata = s.Result; m.Kvmem = k.Result; m.Tts = t.Result; m.Vpn = v.Result;

        // mirror of the ps1's HermesMain(): first "provider:" line within the top 8 lines
        try
        {
            var cfgPath = @"D:\ProgramFiles\Hermes_Desktop\config.yaml";
            var lines = await Task.Run(() => File.ReadLines(cfgPath).Take(8)).ConfigureAwait(false);
            foreach (var l in lines)
            {
                var mm = ProviderRe.Match(l);
                if (mm.Success) { m.Main = mm.Groups[1].Value.Trim('"'); break; }
            }
        }
        catch { }

        return m;
    }

    private static async Task<bool> PortAliveAsync(int port)
    {
        try
        {
            using var c = new TcpClient();
            using var cts = new CancellationTokenSource(400);
            await c.ConnectAsync("127.0.0.1", port, cts.Token).ConfigureAwait(false);
            return true;
        }
        catch { return false; }
    }

    public static async Task<(string text, bool warn)> GpuAsync()
    {
        try
        {
            var psi = new ProcessStartInfo("nvidia-smi",
                "--query-gpu=index,memory.free --format=csv,noheader,nounits")
            { RedirectStandardOutput = true, UseShellExecute = false, CreateNoWindow = true };
            using var p = Process.Start(psi)!;
            var outp = await p.StandardOutput.ReadToEndAsync().ConfigureAwait(false);
            if (!p.WaitForExit(4000)) { try { p.Kill(); } catch { } return ("GPU --", false); }
            var parts = outp.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            var segs = new System.Collections.Generic.List<string>();
            var warn = false;
            foreach (var l in parts)
            {
                var f = l.Split(',');
                if (f.Length < 2) continue;
                if (!int.TryParse(f[1].Trim(), out var freeMb)) continue;
                var gb = freeMb / 1024.0;
                if (gb < 1.0) warn = true;   // Strata full-seat mode leaves ~1G per card by design
                segs.Add($"GPU{f[0].Trim()} 余{gb:0.0}G");
            }
            return segs.Count > 0 ? (string.Join("  ", segs), warn) : ("GPU --", false);
        }
        catch { return ("GPU --", false); }
    }
}
