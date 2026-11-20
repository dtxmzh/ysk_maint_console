using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace MaintOps;

/// <summary>One menu entry exactly as emitted by `pwsh -File ysk_maint_console.ps1 -DumpMenu`.
/// r = risk level for the confirm dialog (danger/confirm/none); p = dialog spec
/// (radio:v=label|... | text:hint | bak = dynamic rollback inventory); w = impact line.</summary>
public sealed class MenuEntry
{
    [JsonPropertyName("k")] public string K { get; set; } = "";
    [JsonPropertyName("t")] public string T { get; set; } = "";
    [JsonPropertyName("grp")] public string? Grp { get; set; }
    [JsonPropertyName("r")] public string? R { get; set; }
    [JsonPropertyName("w")] public string? W { get; set; }
    [JsonPropertyName("p")] public string? P { get; set; }

    [JsonIgnore] public bool IsGroup => Grp != null;
    [JsonIgnore] public bool IsQuit => K.Equals("q", System.StringComparison.OrdinalIgnoreCase);
    /// <summary>Full run key: "3" for main items, "u>8" for group items.</summary>
    [JsonIgnore] public string? RunKey => IsQuit || IsGroup ? null : K;
}

public sealed class MenuGroup
{
    [JsonPropertyName("title")] public string Title { get; set; } = "";
    [JsonPropertyName("items")] public List<MenuEntry> Items { get; set; } = new();
}

public sealed class MenuDump
{
    [JsonPropertyName("main")] public List<MenuEntry> Main { get; set; } = new();
    [JsonPropertyName("groups")] public Dictionary<string, MenuGroup> Groups { get; set; } = new();
}

/// <summary>One rollback candidate as emitted by `-ListBak`.</summary>
public sealed class BakItem
{
    [JsonPropertyName("i")] public int I { get; set; }
    [JsonPropertyName("ver")] public string Ver { get; set; } = "";
    [JsonPropertyName("file")] public string File { get; set; } = "";
    [JsonPropertyName("visFile")] public string VisFile { get; set; } = "";
    [JsonPropertyName("vision")] public bool Vision { get; set; }
    [JsonPropertyName("sizeMb")] public double SizeMb { get; set; }
    [JsonPropertyName("date")] public string Date { get; set; } = "";

    public string Label => $"[{I}]  {Ver}    {SizeMb:0}MB    {Date}    vision{(Vision ? "有" : "无")}";
}
