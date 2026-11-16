using System.Drawing;
using System.Windows.Media.Imaging;
using ScanCode.Core;

namespace ScanCode.Capture;

/// <summary>A frozen capture of one physical monitor.</summary>
public sealed record CapturedMonitor(
    Rectangle Bounds,
    BitmapSource Image,
    double Scale)
{
    public int PixelWidth => Bounds.Width;
    public int PixelHeight => Bounds.Height;

    /// <summary>Convert a rectangle in this monitor's image pixels to WPF DIPs.</summary>
    public System.Windows.Rect ToDips(PixelRect rect) => new(
        rect.X / Scale,
        rect.Y / Scale,
        rect.Width / Scale,
        rect.Height / Scale);
}
