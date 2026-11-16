using System.Text.RegularExpressions;

namespace ScanCode.Core;

public static partial class ContentParser
{
    private static readonly Regex UrlRegex = new(
        @"https?://[^\s<>""']+",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex CodeRegex = new(
        @"(?:提取码|访问码|密码|pwd|code)\s*[:：=]?\s*([A-Za-z0-9]{4,8})",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex PwdQueryRegex = new(
        @"[?&]pwd=([A-Za-z0-9]{4,8})",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public static QrPayload Parse(string raw)
    {
        var text = (raw ?? string.Empty).Trim();
        if (text.Length == 0)
        {
            return new QrPayload(string.Empty, string.Empty, Provider.Text, "文本内容", "空内容", null, string.Empty);
        }

        var match = UrlRegex.Match(text);
        if (!match.Success)
        {
            return new QrPayload(
                raw,
                string.Empty,
                Provider.Text,
                "文本内容",
                Truncate(OneLine(text), 160),
                null,
                raw);
        }

        var urlText = TrimUrl(match.Value);
        if (!Uri.TryCreate(urlText, UriKind.Absolute, out var uri))
        {
            return new QrPayload(raw, urlText, Provider.Web, "网页链接", urlText, null, urlText);
        }

        var provider = DetectProvider(uri);
        var code = ExtractCode(text, uri);
        var summary = provider == Provider.Web
            ? uri.ToString()
            : uri.Host + uri.AbsolutePath;
        if (provider != Provider.Web && !string.IsNullOrWhiteSpace(uri.Query))
        {
            summary = uri.Host + uri.AbsolutePath;
        }

        var title = provider switch
        {
            Provider.Baidu => "百度网盘分享链接",
            Provider.Quark => "夸克网盘分享链接",
            _ => "网页链接"
        };

        var clipboard = provider switch
        {
            Provider.Baidu when !string.IsNullOrWhiteSpace(code) => $"链接: {uri} 提取码: {code}",
            _ => uri.ToString()
        };

        return new QrPayload(raw, uri.ToString(), provider, title, summary, code, clipboard);
    }

    public static Provider DetectProvider(Uri uri)
    {
        var host = uri.Host.ToLowerInvariant();
        if ((host == "pan.baidu.com" || host.EndsWith(".baidu.com", StringComparison.Ordinal)) &&
            (uri.AbsolutePath.StartsWith("/s/", StringComparison.OrdinalIgnoreCase) ||
             uri.AbsolutePath.StartsWith("/share/", StringComparison.OrdinalIgnoreCase)))
        {
            return Provider.Baidu;
        }

        if (host == "pan.quark.cn" || host.EndsWith(".quark.cn", StringComparison.Ordinal))
        {
            return Provider.Quark;
        }

        return Provider.Web;
    }

    private static string? ExtractCode(string text, Uri uri)
    {
        var queryMatch = PwdQueryRegex.Match(uri.Query);
        if (queryMatch.Success)
        {
            return queryMatch.Groups[1].Value;
        }

        var match = CodeRegex.Match(text);
        return match.Success ? match.Groups[1].Value : null;
    }

    private static string TrimUrl(string value)
    {
        return value.Trim().TrimEnd('.', ',', '。', '，', '；', ';', ')', '）', ']', '】', '"', '\'');
    }

    private static string OneLine(string value) =>
        Regex.Replace(value, @"\s+", " ").Trim();

    private static string Truncate(string value, int max)
    {
        if (value.Length <= max) return value;
        return value[..Math.Max(0, max - 1)] + "…";
    }
}
