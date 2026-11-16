using ScanCode.Core;
using Xunit;

namespace ScanCode.Core.Tests;

public class ContentParserTests
{
    [Fact]
    public void ParsesBaiduLinkWithCode()
    {
        var payload = ContentParser.Parse("链接: https://pan.baidu.com/s/1abc 提取码: ab12");

        Assert.Equal(Provider.Baidu, payload.Provider);
        Assert.Equal("ab12", payload.ExtractCode);
        Assert.Contains("提取码: ab12", payload.ClipboardText);
        Assert.Equal("百度网盘分享链接", payload.Title);
    }

    [Fact]
    public void ParsesQuarkLink()
    {
        var payload = ContentParser.Parse("https://pan.quark.cn/s/1AbCdEf");

        Assert.Equal(Provider.Quark, payload.Provider);
        Assert.Equal("夸克网盘分享链接", payload.Title);
        Assert.Equal("pan.quark.cn/s/1AbCdEf", payload.Summary);
    }

    [Fact]
    public void ParsesPwdQuery()
    {
        var payload = ContentParser.Parse("https://pan.baidu.com/s/1QrDemo8xK?pwd=8xk2");

        Assert.Equal(Provider.Baidu, payload.Provider);
        Assert.Equal("8xk2", payload.ExtractCode);
    }

    [Fact]
    public void LeavesNormalWebLinkAlone()
    {
        var payload = ContentParser.Parse("https://example.com/hello");

        Assert.Equal(Provider.Web, payload.Provider);
        Assert.Equal("网页链接", payload.Title);
        Assert.Equal("https://example.com/hello", payload.Url);
    }

    [Fact]
    public void TreatsPlainTextAsText()
    {
        var payload = ContentParser.Parse("你好，世界");

        Assert.Equal(Provider.Text, payload.Provider);
        Assert.Equal("文本内容", payload.Title);
        Assert.Equal("你好，世界", payload.ClipboardText);
    }
}
