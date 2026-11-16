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
            var image = new BitmapImage();
            image.BeginInit();
            image.UriSource = new Uri(path);
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
