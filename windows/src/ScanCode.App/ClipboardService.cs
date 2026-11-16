using System.Runtime.InteropServices;
using System.Windows;

namespace ScanCode.App;

public static class ClipboardService
{
    public static void SetText(string text)
    {
        for (var attempt = 0; attempt < 4; attempt++)
        {
            try
            {
                Clipboard.SetDataObject(text, true);
                return;
            }
            catch (COMException) when (attempt < 3)
            {
                Thread.Sleep(60);
            }
        }
    }
}
