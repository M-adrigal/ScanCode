using System.Runtime.InteropServices;

namespace ScanCode.Interop;

/// <summary>
/// 抓屏前等 DWM 把"窗口已经隐藏"真正合成到屏幕上。
///
/// Hide() 只是让窗口从窗口管理器消失，屏幕缓冲要等下一次合成才更新；
/// 在这之间 CopyFromScreen 抓到的仍是旧画面，自己的窗口就会被拍进遮罩底图。
/// macOS 侧靠 orderOut 后异步抓屏天然避开了这一点，Windows 必须显式等一下。
/// </summary>
public static class Compositor
{
    private const int MinimumWaitMilliseconds = 90;

    [DllImport("dwmapi.dll")]
    private static extern int DwmFlush();

    /// <summary>
    /// 等两帧合成刷新，并保证总等待不少于 <paramref name="minimumMilliseconds"/>。
    /// 远程桌面等没有 DWM 的环境 DwmFlush 会失败，此时靠固定等待兜底。
    /// </summary>
    public static void WaitForWindowsToDisappear(int minimumMilliseconds = MinimumWaitMilliseconds)
    {
        var start = Environment.TickCount64;
        for (var i = 0; i < 2; i++)
        {
            try
            {
                if (DwmFlush() != 0) break;
            }
            catch (DllNotFoundException)
            {
                break;
            }
            catch (EntryPointNotFoundException)
            {
                break;
            }
        }

        var spent = (int)(Environment.TickCount64 - start);
        if (spent < minimumMilliseconds) Thread.Sleep(minimumMilliseconds - spent);
    }
}
