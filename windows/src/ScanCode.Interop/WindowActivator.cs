using System.Text;

namespace ScanCode.Interop;

public static class WindowActivator
{
    /// <summary>Find a visible top-level window that belongs to the process.</summary>
    public static IntPtr FindMainWindow(uint processId)
    {
        var result = IntPtr.Zero;
        NativeMethods.EnumWindows((hwnd, _) =>
        {
            NativeMethods.GetWindowThreadProcessId(hwnd, out var pid);
            if (pid != processId || !NativeMethods.IsWindowVisible(hwnd)) return true;
            if (NativeMethods.GetWindowTextLength(hwnd) == 0) return true;

            // Prefer a window with a meaningful title; Windows' hidden message windows have none.
            var title = new StringBuilder(NativeMethods.GetWindowTextLength(hwnd) + 1);
            NativeMethods.GetWindowText(hwnd, title, title.Capacity);
            if (title.Length > 0)
            {
                result = hwnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }

    public static bool Activate(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return false;

        if (NativeMethods.IsIconic(hwnd))
        {
            NativeMethods.ShowWindowAsync(hwnd, NativeMethods.SwRestore);
        }

        var foreground = NativeMethods.GetForegroundWindow();
        if (foreground == hwnd) return true;

        var foregroundThread = NativeMethods.GetWindowThreadProcessId(foreground, out _);
        var targetThread = NativeMethods.GetWindowThreadProcessId(hwnd, out _);
        var currentThread = NativeMethods.GetCurrentThreadId();

        var attached = false;
        try
        {
            if (foregroundThread != 0 && targetThread != 0 && foregroundThread != targetThread)
            {
                attached = NativeMethods.AttachThreadInput(foregroundThread, targetThread, true);
            }

            var ok = NativeMethods.SetForegroundWindow(hwnd);
            if (!ok)
            {
                NativeMethods.BringWindowToTop(hwnd);
                NativeMethods.ShowWindowAsync(hwnd, NativeMethods.SwShow);
                ok = NativeMethods.SetForegroundWindow(hwnd);
            }
            return ok;
        }
        finally
        {
            if (attached)
            {
                NativeMethods.AttachThreadInput(foregroundThread, targetThread, false);
            }
            _ = currentThread;
        }
    }
}
