using System;
using ScanCode.Core;

static void Check(bool condition, string message)
{
    if (!condition) throw new Exception(message);
}

var baidu = ContentParser.Parse("链接: https://pan.baidu.com/s/1abc 提取码: ab12");
Check(baidu.Provider == Provider.Baidu, "baidu provider");
Check(baidu.ExtractCode == "ab12", "baidu code");
Check(baidu.ClipboardText.Contains("提取码: ab12", StringComparison.Ordinal), "baidu clipboard");
Check(baidu.Title == "百度网盘分享链接", "baidu title");

var quark = ContentParser.Parse("https://pan.quark.cn/s/1AbCdEf");
Check(quark.Provider == Provider.Quark, "quark provider");
Check(quark.Summary == "pan.quark.cn/s/1AbCdEf", "quark summary");
Check(quark.Title == "夸克网盘分享链接", "quark title");

var pwd = ContentParser.Parse("https://pan.baidu.com/s/1QrDemo8xK?pwd=8xk2");
Check(pwd.Provider == Provider.Baidu, "pwd provider");
Check(pwd.ExtractCode == "8xk2", "pwd code");

var web = ContentParser.Parse("https://example.com/hello");
Check(web.Provider == Provider.Web, "web provider");
Check(web.Title == "网页链接", "web title");
Check(web.Url == "https://example.com/hello", "web url");

var text = ContentParser.Parse("你好，世界");
Check(text.Provider == Provider.Text, "text provider");
Check(text.Title == "文本内容", "text title");
Check(text.ClipboardText == "你好，世界", "text clipboard");

Console.WriteLine("ScanCode.Core tests: ALL PASS");
