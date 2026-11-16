using System.Runtime.InteropServices;
using System.Windows.Interop;
using ScanCode.Interop;

namespace ScanCode.App;

public sealed class HotkeyService : IDisposable
{
    private const int HotkeyId = 1;
    private HwndSource? _source;

    public event Action? Pressed;

    public bool Register()
    {
        if (_source != null) return true;

        var parameters = new HwndSourceParameters("ScanCodeHotkey")
        {
            Width = 0,
            Height = 0,
            WindowStyle = unchecked((int)0x80000000),
            ExtendedWindowStyle = 0x00000080
        };

        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);

        var ok = NativeMethods.RegisterHotKey(
            _source.Handle,
            HotkeyId,
            NativeMethods.ModControl | NativeMethods.ModAlt | NativeMethods.ModNoRepeat,
            NativeMethods.VkQ);

        Log.Write($"hotkey: register result={ok}");
        if (!ok)
        {
            _source.RemoveHook(WndProc);
            _source.Dispose();
            _source = null;
        }
        return ok;
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == NativeMethods.WmHotkey && wParam.ToInt32() == HotkeyId)
        {
            handled = true;
            Pressed?.Invoke();
        }
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        if (_source == null) return;
        NativeMethods.UnregisterHotKey(_source.Handle, HotkeyId);
        _source.RemoveHook(WndProc);
        _source.Dispose();
        _source = null;
    }
}
