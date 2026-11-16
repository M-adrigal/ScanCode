using System.Diagnostics;
using Microsoft.Win32;
using ScanCode.Core;
using ScanCode.Interop;

namespace ScanCode.App;

public sealed class AppRegistry
{
    private readonly string[] _registryRoots =
    {
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    };

    public AppState GetState(AppDescriptor app)
    {
        using var running = FindRunning(app);
        if (running != null) return AppState.Running;
        return FindInstallPath(app) != null ? AppState.NotRunning : AppState.NotInstalled;
    }

    public Process? FindRunning(AppDescriptor app)
    {
        foreach (var name in app.ProcessNames)
        {
            var processes = Process.GetProcessesByName(name);
            foreach (var process in processes)
            {
                if (!process.HasExited) return process;
                process.Dispose();
            }
        }
        return null;
    }

    public string? FindInstallPath(AppDescriptor app)
    {
        using var running = FindRunning(app);
        try
        {
            var path = running?.MainModule?.FileName;
            if (!string.IsNullOrWhiteSpace(path) && File.Exists(path)) return path;
        }
        catch
        {
            // The process may be elevated or protected; fall through to known paths.
        }

        foreach (var candidate in CommonPaths(app))
        {
            if (File.Exists(candidate)) return candidate;
        }

        return FindFromUninstallRegistry(app);
    }

    public bool Activate(AppDescriptor app, Process process)
    {
        if (process.HasExited) return false;

        process.Refresh();
        var hwnd = process.MainWindowHandle;
        if (hwnd == IntPtr.Zero)
        {
            hwnd = WindowActivator.FindMainWindow((uint)process.Id);
        }

        Log.Write($"activate: {app.Id} hwnd={(hwnd == IntPtr.Zero ? "0" : "ok")}");
        if (hwnd == IntPtr.Zero)
        {
            // The client may be alive only in the tray. Starting the already-running exe
            // asks its single-instance logic to show the main window; it is not a cold start.
            var path = FindInstallPath(app);
            using var stillRunning = FindRunning(app);
            if (path != null && stillRunning != null)
            {
                try
                {
                    Log.Write($"activate: reopen {app.Id}");
                    Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
                    Thread.Sleep(900);
                    process.Refresh();
                    hwnd = process.MainWindowHandle;
                    if (hwnd == IntPtr.Zero)
                    {
                        hwnd = WindowActivator.FindMainWindow((uint)process.Id);
                    }
                }
                catch
                {
                    return false;
                }
            }
        }

        var activated = hwnd != IntPtr.Zero && WindowActivator.Activate(hwnd);
        Log.Write($"activate: {app.Id} result={activated}");
        return activated;
    }

    /// <summary>Quark L1.5: after activation, focus its address bar and paste the copied link.</summary>
    public void TryFocusAddressBar(Process process)
    {
        var foreground = NativeMethods.GetForegroundWindow();
        NativeMethods.GetWindowThreadProcessId(foreground, out var pid);
        if (pid != (uint)process.Id) return;

        try
        {
            System.Windows.Forms.SendKeys.SendWait("^l");
            Thread.Sleep(90);
            System.Windows.Forms.SendKeys.SendWait("^v");
        }
        catch
        {
            // The client may not accept keyboard input; the link is already on the clipboard.
        }
    }

    private static IEnumerable<string> CommonPaths(AppDescriptor app)
    {
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);

        if (app.Id == KnownApps.Baidu.Id)
        {
            yield return Path.Combine(local, "BaiduNetdisk", "BaiduNetdisk.exe");
            yield return Path.Combine(programFiles, "BaiduNetdisk", "BaiduNetdisk.exe");
            yield return Path.Combine(programFilesX86, "BaiduNetdisk", "BaiduNetdisk.exe");
        }
        else if (app.Id == KnownApps.Quark.Id)
        {
            yield return Path.Combine(local, "Quark", "Quark.exe");
            yield return Path.Combine(programFiles, "Quark", "Quark.exe");
            yield return Path.Combine(programFilesX86, "Quark", "Quark.exe");
            yield return Path.Combine(local, "Programs", "Quark", "Quark.exe");
        }
    }

    private string? FindFromUninstallRegistry(AppDescriptor app)
    {
        foreach (var root in new[] { Registry.CurrentUser, Registry.LocalMachine })
        {
            foreach (var subKey in _registryRoots)
            {
                using var uninstall = root.OpenSubKey(subKey);
                if (uninstall == null) continue;

                foreach (var name in uninstall.GetSubKeyNames())
                {
                    using var entry = uninstall.OpenSubKey(name);
                    var displayName = entry?.GetValue("DisplayName") as string;
                    if (string.IsNullOrWhiteSpace(displayName)) continue;

                    var matches = app.Id == KnownApps.Baidu.Id
                        ? displayName.Contains("百度网盘", StringComparison.OrdinalIgnoreCase) ||
                          displayName.Contains("BaiduNetdisk", StringComparison.OrdinalIgnoreCase)
                        : displayName.Contains("夸克", StringComparison.OrdinalIgnoreCase) ||
                          displayName.Contains("Quark", StringComparison.OrdinalIgnoreCase);
                    if (!matches) continue;

                    var icon = entry?.GetValue("DisplayIcon") as string;
                    if (!string.IsNullOrWhiteSpace(icon))
                    {
                        var path = icon.Trim('"').Split(',')[0].Trim();
                        if (File.Exists(path)) return path;
                    }

                    var location = entry?.GetValue("InstallLocation") as string;
                    if (!string.IsNullOrWhiteSpace(location))
                    {
                        foreach (var candidate in CommonPaths(app)
                                     .Select(p => Path.GetFileName(p))
                                     .Where(n => !string.IsNullOrWhiteSpace(n)))
                        {
                            var path = Path.Combine(location, candidate!);
                            if (File.Exists(path)) return path;
                        }
                    }
                }
            }
        }
        return null;
    }
}
