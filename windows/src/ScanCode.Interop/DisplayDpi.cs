namespace ScanCode.Interop;

public static class DisplayDpi
{
    /// <summary>Effective DPI scale (1.0 = 96 DPI) at a physical screen point.</summary>
    public static double GetScaleAt(int x, int y)
    {
        var monitor = NativeMethods.MonitorFromPoint(
            new NativeMethods.Point(x, y), NativeMethods.MonitorDefaultToNearest);
        if (monitor == IntPtr.Zero) return 1.0;
        return NativeMethods.GetDpiForMonitor(
            monitor, NativeMethods.MdtEffectiveDpi, out var dpiX, out _) == 0 && dpiX > 0
            ? dpiX / 96.0
            : 1.0;
    }
}
