using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;
using ScanCode.Capture;
using ScanCode.Core;
using ScanCode.Interop;

namespace ScanCode.App;

public sealed class AppController : IDisposable
{
    private readonly AppRegistry _registry = new();
    private readonly Dispatcher _dispatcher;
    private TrayController? _tray;
    private HotkeyService? _hotkey;
    private WelcomeWindow? _welcome;
    private OverlayController? _overlay;
    private ResultWindow? _result;
    private HudWindow? _hud;
    private bool _capturing;
    private bool _disposed;
    private CapturedMonitor? _lastMonitor;
    private PixelRect _lastSelection;

    public AppController()
    {
        _dispatcher = new Dispatcher(_registry);
    }

    public void Start()
    {
        Log.Write("app: start");
        _tray = new TrayController();
        _tray.OpenRequested += ShowWelcome;
        _tray.StartRequested += BeginCapture;
        _tray.ExitRequested += Quit;

        _hotkey = new HotkeyService();
        _hotkey.Pressed += BeginCapture;
        try
        {
            if (!_hotkey.Register())
            {
                Log.Write("hotkey: register failed");
                Alerts.Info("全局快捷键 Ctrl+Alt+Q 注册失败，可能被其他程序占用。\n仍可以从托盘菜单开始识别。");
            }
        }
        catch (Exception ex)
        {
            Alerts.Info($"全局快捷键初始化失败：{ex.Message}\n仍可以从托盘菜单开始识别。");
        }

        ShowWelcome();
    }

    private void ShowWelcome()
    {
        // 隐藏后复用同一个窗口：重新 Show() 比重新构造更省事，也不会留下两个实例。
        if (_welcome is { IsLoaded: true })
        {
            _welcome.Show();
            _welcome.Activate();
            return;
        }

        _welcome = new WelcomeWindow(_registry);
        // 走和热键同一条路：由 BeginCapture 负责先隐藏再抓屏。这里不要 Close()，
        // 否则窗口是被销毁而不是隐藏，既无法复用，也来不及从画面里消失。
        _welcome.StartRequested += BeginCapture;
        _welcome.QuitRequested += Quit;
        _welcome.Closed += (_, _) => _welcome = null;
        _welcome.Show();
        _welcome.Activate();
    }

    private void BeginCapture()
    {
        if (_capturing || _disposed) return;
        Log.Write("capture: begin");
        CloseResult();
        CloseOverlay();
        _capturing = true;

        // 和 macOS 一致：抓屏前先把自己的窗口全部藏起来。
        HideOwnWindows();
        Compositor.WaitForWindowsToDisappear();

        try
        {
            var monitors = ScreenCaptureService.CaptureAll();

            // 兜底：万一合成器还是慢半拍、把刚藏掉的窗口留在了画面里，就重抓一次。
            for (var attempt = 0; attempt < 2 && WelcomeStillInScreenshot(monitors); attempt++)
            {
                Log.Write($"capture: retry attempt={attempt + 1} own window still in frame");
                Thread.Sleep(120);
                monitors = ScreenCaptureService.CaptureAll();
            }

            var controller = new OverlayController();
            controller.SelectionConfirmed += OnSelectionConfirmed;
            controller.HotspotSelected += OnHotspotSelected;
            controller.Cancelled += CloseOverlay;
            _overlay = controller;
            controller.Show(monitors);
        }
        catch (Exception ex)
        {
            _capturing = false;
            Log.Write($"capture: failed {ex}");
            Alerts.CaptureFailed(ex.Message);
        }
    }

    private void OnSelectionConfirmed(CapturedMonitor monitor, PixelRect rect)
    {
        _lastMonitor = monitor;
        _lastSelection = rect;
        Log.Write($"selection: {rect}");

        IReadOnlyList<DecodedQr> decoded;
        try
        {
            decoded = QrDecoder.Decode(monitor, rect);
        }
        catch (Exception ex)
        {
            CloseOverlay();
            Alerts.DispatchFailed($"二维码解析失败：{ex.Message}");
            return;
        }

        Log.Write($"decode: count={decoded.Count}");
        if (decoded.Count == 0)
        {
            CloseOverlay();
            if (Alerts.RetryQr()) BeginCapture();
            return;
        }

        if (decoded.Count > 1)
        {
            _overlay?.ShowHotspots(monitor, decoded);
            return;
        }

        ShowPayload(monitor, rect, decoded[0].Raw);
    }

    private void OnHotspotSelected(DecodedQr qr)
    {
        var monitor = _lastMonitor;
        if (monitor == null) return;
        ShowPayload(monitor, _lastSelection, qr.Raw);
    }

    private void ShowPayload(CapturedMonitor monitor, PixelRect anchor, string raw)
    {
        var payload = ContentParser.Parse(raw);
        Log.Write($"payload: provider={payload.Provider} code={!string.IsNullOrWhiteSpace(payload.ExtractCode)}");
        CloseOverlay();
        CloseResult();

        var app = KnownApps.ForProvider(payload.Provider);
        var state = app == null ? AppState.NotInstalled : _registry.GetState(app);
        var window = new ResultWindow(payload, app, state);
        window.AppSelected += selected => Dispatch(payload, selected);
        window.CopyRequested += () =>
        {
            ClipboardService.SetText(payload.ClipboardText);
            ShowHud("已复制");
        };
        window.Closed += (_, _) =>
        {
            if (ReferenceEquals(_result, window)) _result = null;
        };

        _result = window;
        window.ShowNear(anchor, monitor.Scale);
    }

    private void Dispatch(QrPayload payload, AppDescriptor app)
    {
        try
        {
            Log.Write($"dispatch: {app.Id}");
            var message = _dispatcher.Dispatch(payload, app);
            CloseResult();
            ShowHud(message);
        }
        catch (DispatchException ex)
        {
            Log.Write($"dispatch: failed {ex.Message}");
            Alerts.DispatchFailed(ex.Message);
        }
        catch (Exception ex)
        {
            Log.Write($"dispatch: exception {ex}");
            Alerts.DispatchFailed($"唤起失败：{ex.Message}");
        }
    }

    private void ShowHud(string message)
    {
        _hud?.Close();
        _hud = new HudWindow(message);
        _hud.Closed += (_, _) => _hud = null;
        _hud.Show();
    }

    /// <summary>
    /// 抓屏前收起自己所有还在屏幕上的窗口：欢迎页和提示条（结果条已由 CloseResult 关闭）。
    ///
    /// 只调 Hide() 是不够的：WPF 的可见性变更要走 Dispatcher 队列，Win32 层的 SW_HIDE
    /// 才真正下发。如果紧接着就在 UI 线程上 Sleep 或抓屏，队列没机会执行，窗口仍留在
    /// 屏幕上，就会被拍进遮罩底图——看起来像"一个半透明的窗口压在二维码上"。
    /// 所以这里 Hide() 之后先跑一轮消息泵，再补一刀 Win32 级的强制隐藏。
    /// </summary>
    private void HideOwnWindows()
    {
        var handles = new List<IntPtr>();
        foreach (var window in new Window?[] { _welcome, _hud })
        {
            if (window is not { IsLoaded: true }) continue;
            window.Hide();
            var handle = new WindowInteropHelper(window).Handle;
            if (handle != IntPtr.Zero) handles.Add(handle);
        }

        PumpDispatcher();

        foreach (var handle in handles)
        {
            if (NativeMethods.IsWindowVisible(handle)) NativeMethods.ShowWindowAsync(handle, NativeMethods.SwHide);
        }

        PumpDispatcher();
        var stillVisible = handles.Count(h => NativeMethods.IsWindowVisible(h));
        Log.Write($"capture: windows hidden, still visible={stillVisible}");
    }

    /// <summary>跑一轮消息泵，让排队中的可见性变更真正落到 Win32。</summary>
    private static void PumpDispatcher()
    {
        // 注意：本命名空间里有个同名的 Dispatcher（负责唤起应用），这里必须写全名。
        var frame = new DispatcherFrame();
        System.Windows.Threading.Dispatcher.CurrentDispatcher.BeginInvoke(
            DispatcherPriority.Background,
            new Action(() => frame.Continue = false));
        System.Windows.Threading.Dispatcher.PushFrame(frame);
    }

    /// <summary>
    /// 抓到的画面里是否还留着欢迎页。用它的窗口背景色（246,247,249）判断：
    /// 在窗口左边距内取一小区块，接近纯白且中性的就是它，壁纸和普通网页不会这么白。
    /// </summary>
    private bool WelcomeStillInScreenshot(IReadOnlyList<CapturedMonitor> monitors)
    {
        if (_welcome is not { IsLoaded: true }) return false;
        var handle = new WindowInteropHelper(_welcome).Handle;
        if (handle == IntPtr.Zero) return false;
        if (!NativeMethods.GetWindowRect(handle, out var rect)) return false;

        var x = rect.Left + 10;
        var y = rect.Top + rect.Height / 2;

        foreach (var monitor in monitors)
        {
            var bounds = monitor.Bounds;
            var left = x - bounds.Left - 8;
            var top = y - bounds.Top - 8;
            var image = monitor.Image;
            if (left < 0 || top < 0 || left + 16 > image.PixelWidth || top + 16 > image.PixelHeight) continue;

            var buffer = new byte[16 * 16 * 4];
            image.CopyPixels(new Int32Rect(left, top, 16, 16), buffer, 16 * 4, 0);

            long blue = 0, green = 0, red = 0;
            for (var i = 0; i < buffer.Length; i += 4)
            {
                blue += buffer[i];
                green += buffer[i + 1];
                red += buffer[i + 2];
            }

            const int count = 16 * 16;
            return red / count > 232 && green / count > 232 && blue / count > 232;
        }

        return false;
    }

    private void CloseOverlay()
    {
        _overlay?.Close();
        _overlay = null;
        _capturing = false;
    }

    private void CloseResult()
    {
        _result?.Close();
        _result = null;
    }

    private void Quit()
    {
        Dispose();
        Application.Current.Shutdown();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _overlay?.Close();
        _result?.Close();
        _hud?.Close();
        _welcome?.Close();
        _hotkey?.Dispose();
        _tray?.Dispose();
    }
}
