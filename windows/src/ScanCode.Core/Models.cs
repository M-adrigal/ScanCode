namespace ScanCode.Core;

public enum Provider
{
    Baidu,
    Quark,
    Web,
    Text
}

public enum AppState
{
    Running,
    NotRunning,
    NotInstalled
}

/// <summary>Rectangle in physical screen/image pixels.</summary>
public readonly record struct PixelRect(double X, double Y, double Width, double Height)
{
    public double Right => X + Width;
    public double Bottom => Y + Height;
    public double CenterX => X + Width / 2;
    public double CenterY => Y + Height / 2;

    public bool Intersects(PixelRect other, double padding = 0) =>
        X - padding < other.Right &&
        Right + padding > other.X &&
        Y - padding < other.Bottom &&
        Bottom + padding > other.Y;
}

public sealed record QrPayload(
    string Raw,
    string Url,
    Provider Provider,
    string Title,
    string Summary,
    string? ExtractCode,
    string ClipboardText);

/// <summary>A decoded QR code and its bounds in the captured monitor image.</summary>
public sealed record DecodedQr(string Raw, PixelRect Bounds);

/// <summary>A Windows application the scanner can hand a link to.</summary>
public sealed record AppDescriptor(
    string Id,
    string DisplayName,
    string[] ProcessNames)
{
    public bool MatchesProcessName(string processName) =>
        ProcessNames.Any(name => string.Equals(name, processName, StringComparison.OrdinalIgnoreCase));
}

public static class KnownApps
{
    public static readonly AppDescriptor Baidu = new(
        "baidu",
        "百度网盘",
        new[] { "BaiduNetdisk", "BaiduNetdiskHost" });

    public static readonly AppDescriptor Quark = new(
        "quark",
        "夸克",
        new[] { "Quark", "QuarkPC", "QuarkBrowser" });

    public static readonly IReadOnlyList<AppDescriptor> All = new[] { Baidu, Quark };

    public static AppDescriptor? ForProvider(Provider provider) => provider switch
    {
        Provider.Baidu => Baidu,
        Provider.Quark => Quark,
        _ => null
    };
}
