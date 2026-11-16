using System;
using System.IO;

namespace ScanCode.App;

internal static class Log
{
    private static readonly object Gate = new();
    private static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "ScanCode",
        "ScanCode.log");

    public static string FilePath => LogPath;

    public static void Write(string message)
    {
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);
                File.AppendAllText(LogPath, $"[ScanCode] {DateTimeOffset.Now:O} {message}\n");
            }
        }
        catch
        {
            // Diagnostics must never take the app down.
        }
    }
}
