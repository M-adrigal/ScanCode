using System.Windows;
using ScanCode.Capture;
using ScanCode.Core;

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
        if (_welcome is { IsVisible: true })
        {
            _welcome.Activate();
            return;
        }

        _welcome = new WelcomeWindow(_registry);
        _welcome.StartRequested += () =>
        {
            _welcome?.Close();
            BeginCapture();
        };
        _welcome.QuitRequested += Quit;
        _welcome.Closed += (_, _) => _welcome = null;
        _welcome.Show();
        _welcome.Activate();
    }

    private void BeginCapture()
    {
        if (_capturing || _disposed) return;
        CloseResult();
        CloseOverlay();
        _capturing = true;
        _welcome?.Hide();

        try
        {
            var monitors = ScreenCaptureService.CaptureAll();
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
            Alerts.CaptureFailed(ex.Message);
        }
    }

    private void OnSelectionConfirmed(CapturedMonitor monitor, PixelRect rect)
    {
        _lastMonitor = monitor;
        _lastSelection = rect;

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
        CloseOverlay();
        CloseResult();

        var app = KnownApps.ForProvider(payload.Provider);
        var state = app == null ? AppState.NotInstalled : _registry.GetState(app);
        var window = new ResultWindow(payload, app, state);
        window.AppSelected += selected => Dispatch(payload, selected, monitor, anchor);
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

    private void Dispatch(QrPayload payload, AppDescriptor app, CapturedMonitor monitor, PixelRect anchor)
    {
        try
        {
            var message = _dispatcher.Dispatch(payload, app);
            CloseResult();
            ShowHud(message);
        }
        catch (DispatchException ex)
        {
            Alerts.DispatchFailed(ex.Message);
        }
        catch (Exception ex)
        {
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
