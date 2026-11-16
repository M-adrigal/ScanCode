using ScanCode.Capture;
using ScanCode.Core;

namespace ScanCode.App;

public sealed class OverlayController
{
    private readonly List<OverlayWindow> _windows = new();

    public event Action<CapturedMonitor, PixelRect>? SelectionConfirmed;
    public event Action<DecodedQr>? HotspotSelected;
    public event Action? Cancelled;

    public bool IsOpen => _windows.Count > 0;

    public void Show(IReadOnlyList<CapturedMonitor> monitors)
    {
        foreach (var monitor in monitors)
        {
            var window = new OverlayWindow(monitor);
            window.SelectionConfirmed += (m, rect) => SelectionConfirmed?.Invoke(m, rect);
            window.HotspotSelected += qr => HotspotSelected?.Invoke(qr);
            window.Cancelled += () => Cancelled?.Invoke();
            _windows.Add(window);
            window.Show();
        }

        _windows.FirstOrDefault()?.Activate();
    }

    public void ShowHotspots(CapturedMonitor monitor, IReadOnlyList<DecodedQr> spots)
    {
        _windows.FirstOrDefault(w => ReferenceEquals(w.Monitor, monitor))?.ShowHotspots(spots);
    }

    public void Close()
    {
        foreach (var window in _windows.ToArray())
        {
            try { window.Close(); } catch { }
        }
        _windows.Clear();
    }
}
