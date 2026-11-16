using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using ScanCode.Core;
using ScanCode.Interop;

namespace ScanCode.Capture;

public sealed class CaptureException : Exception
{
    public CaptureException(string message) : base(message) { }
}

public static class ScreenCaptureService
{
    /// <summary>
    /// GDI capture of every monitor. This is the P0 path: simple and dependable for
    /// normal desktop windows. WGC/DXGI can be added behind the same interface later
    /// for hardware-protected content.
    /// </summary>
    public static IReadOnlyList<CapturedMonitor> CaptureAll()
    {
        var screens = System.Windows.Forms.Screen.AllScreens;
        if (screens.Length == 0) throw new CaptureException("没有检测到显示器。");

        var result = new List<CapturedMonitor>(screens.Length);
        foreach (var screen in screens)
        {
            var bounds = screen.Bounds;
            if (bounds.Width <= 0 || bounds.Height <= 0) continue;
            try
            {
                result.Add(Capture(bounds));
            }
            catch (Exception ex)
            {
                throw new CaptureException($"截取显示器失败：{ex.Message}");
            }
        }

        if (result.Count == 0) throw new CaptureException("没有可截取的显示器。");
        return result;
    }

    private static CapturedMonitor Capture(Rectangle bounds)
    {
        using var bitmap = new Bitmap(bounds.Width, bounds.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.CopyFromScreen(
                bounds.Left,
                bounds.Top,
                0,
                0,
                bounds.Size,
                CopyPixelOperation.SourceCopy);
        }

        var data = bitmap.LockBits(
            new Rectangle(0, 0, bounds.Width, bounds.Height),
            ImageLockMode.ReadOnly,
            System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        try
        {
            var stride = data.Stride;
            var bytes = new byte[stride * bounds.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);

            var source = BitmapSource.Create(
                bounds.Width,
                bounds.Height,
                96,
                96,
                PixelFormats.Bgra32,
                null,
                bytes,
                stride);
            source.Freeze();

            var scale = DisplayDpi.GetScaleAt(
                bounds.Left + bounds.Width / 2,
                bounds.Top + bounds.Height / 2);
            return new CapturedMonitor(bounds, source, scale);
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

    /// <summary>Copy a region of a captured monitor to a BGRA byte array for ZXing.</summary>
    public static byte[] CopyPixels(CapturedMonitor monitor, PixelRect region, out int width, out int height, out int stride)
    {
        var source = monitor.Image;
        var x = Math.Max(0, (int)Math.Floor(region.X));
        var y = Math.Max(0, (int)Math.Floor(region.Y));
        var w = Math.Max(1, Math.Min((int)Math.Ceiling(region.Width), source.PixelWidth - x));
        var h = Math.Max(1, Math.Min((int)Math.Ceiling(region.Height), source.PixelHeight - y));

        var cropped = new CroppedBitmap(source, new System.Windows.Int32Rect(x, y, w, h));
        cropped.Freeze();

        var converted = new FormatConvertedBitmap(cropped, PixelFormats.Bgra32, null, 0);
        converted.Freeze();

        stride = w * 4;
        var bytes = new byte[stride * h];
        converted.CopyPixels(bytes, stride, 0);
        width = w;
        height = h;
        return bytes;
    }
}
