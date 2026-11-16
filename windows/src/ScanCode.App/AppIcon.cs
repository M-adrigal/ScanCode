using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace ScanCode.App;

internal static class AppIcon
{
    public static ImageSource Load()
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
            if (!File.Exists(path)) return new DrawingImage();
            using var stream = File.OpenRead(path);
            var image = new BitmapImage();
            image.BeginInit();
            image.StreamSource = stream;
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.EndInit();
            image.Freeze();
            return image;
        }
        catch
        {
            return new DrawingImage();
        }
    }
}
