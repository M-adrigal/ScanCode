using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace ScanCode.App;

/// <summary>
/// 图标嵌在程序集里，并按需要的尺寸从 .ico 的多帧中挑合适的一帧。
/// 直接用 BitmapImage 解码 .ico 只会拿到第一帧（16×16），放大到 88×88 就是糊的。
/// </summary>
internal static class AppIcon
{
    private const string ResourceName = "ScanCode.AppIcon.ico";

    /// <summary>托盘图标要一直能读到流，所以留一个静态引用。</summary>
    private static MemoryStream? _trayStream;

    private readonly record struct Frame(int Size, int Offset, int Length)
    {
        /// <summary>PNG 帧以 0x89 0x50 开头；老式 DIB 帧以 0x28 开头。</summary>
        public bool IsPng(byte[] ico) => ico[Offset] == 0x89 && ico[Offset + 1] == 0x50;
    }

    public static byte[]? Bytes()
    {
        try
        {
            using var stream = typeof(AppIcon).Assembly.GetManifestResourceStream(ResourceName);
            if (stream == null) return null;
            using var buffer = new MemoryStream();
            stream.CopyTo(buffer);
            return buffer.ToArray();
        }
        catch
        {
            return null;
        }
    }

    /// <summary>取最大一帧（本图标为 256×256），用于欢迎页这种大图。</summary>
    public static ImageSource Load() => Load(0);

    /// <summary>取不小于 pixelSize 的最小一帧；pixelSize ≤ 0 时取最大一帧。</summary>
    public static ImageSource Load(int pixelSize)
    {
        try
        {
            var bytes = Bytes();
            if (bytes == null) return new DrawingImage();

            var frames = ReadFrames(bytes);
            if (frames.Count == 0) return new DrawingImage();

            var frame = PickFrame(frames, pixelSize);
            return frame.IsPng(bytes)
                ? FromPngFrame(bytes, frame)
                : FromIconFrame(bytes, frame.Size);
        }
        catch
        {
            return new DrawingImage();
        }
    }

    /// <summary>取不到图标时返回 null，由调用方回退到系统默认图标。</summary>
    public static System.Drawing.Icon? LoadTrayIcon()
    {
        try
        {
            var bytes = Bytes();
            if (bytes == null) return null;

            var stream = new MemoryStream(bytes, writable: false);
            _trayStream = stream;

            // 按系统小图标尺寸取帧，托盘才不会把大图缩成糊的。
            return new System.Drawing.Icon(stream, System.Windows.Forms.SystemInformation.SmallIconSize);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>解析 ICONDIR，列出每一帧的尺寸和字节区间。</summary>
    private static List<Frame> ReadFrames(byte[] ico)
    {
        var frames = new List<Frame>();
        if (ico.Length < 6) return frames;

        var type = BitConverter.ToUInt16(ico, 2);
        var count = BitConverter.ToUInt16(ico, 4);
        if (type != 1 || count == 0) return frames;

        for (var i = 0; i < count; i++)
        {
            var entry = 6 + i * 16;
            if (entry + 16 > ico.Length) break;

            // ICONDIRENTRY 里宽高各占 1 字节，0 代表 256。
            var size = ico[entry] == 0 ? 256 : ico[entry];
            var length = BitConverter.ToInt32(ico, entry + 8);
            var offset = BitConverter.ToInt32(ico, entry + 12);
            if (length <= 0 || offset <= 0 || offset + length > ico.Length) continue;

            frames.Add(new Frame(size, offset, length));
        }

        return frames;
    }

    private static Frame PickFrame(List<Frame> frames, int pixelSize)
    {
        if (pixelSize <= 0) return frames.OrderByDescending(f => f.Size).First();

        foreach (var candidate in frames.OrderBy(f => f.Size))
        {
            if (candidate.Size >= pixelSize) return candidate;
        }

        return frames.OrderByDescending(f => f.Size).First();
    }

    private static ImageSource FromPngFrame(byte[] ico, Frame frame)
    {
        using var stream = new MemoryStream(ico, frame.Offset, frame.Length, writable: false);
        var image = new BitmapImage();
        image.BeginInit();
        image.StreamSource = stream;
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.EndInit();
        image.Freeze();
        return image;
    }

    /// <summary>老式 DIB 帧交给 System.Drawing 解码，避免自己拼位图头。</summary>
    private static ImageSource FromIconFrame(byte[] ico, int size)
    {
        using var stream = new MemoryStream(ico, writable: false);
        using var icon = new System.Drawing.Icon(stream, size, size);
        var source = System.Windows.Interop.Imaging.CreateBitmapSourceFromHIcon(
            icon.Handle,
            Int32Rect.Empty,
            BitmapSizeOptions.FromEmptyOptions());
        source.Freeze();
        return source;
    }
}
