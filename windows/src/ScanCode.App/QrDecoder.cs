using ScanCode.Capture;
using ScanCode.Core;
using ZXing;
using ZXing.Common;

namespace ScanCode.App;

public static class QrDecoder
{
    public static IReadOnlyList<DecodedQr> Decode(CapturedMonitor monitor, PixelRect selection)
    {
        var bytes = ScreenCaptureService.CopyPixels(monitor, selection, out var width, out var height, out _);
        var source = new RGBLuminanceSource(
            bytes,
            width,
            height,
            RGBLuminanceSource.BitmapFormat.BGRA32);

        var reader = new BarcodeReaderGeneric
        {
            Options = new DecodingOptions
            {
                PossibleFormats = new[] { BarcodeFormat.QR_CODE },
                TryHarder = true,
                TryInverted = true
            }
        };

        var results = reader.DecodeMultiple(source);
        if (results == null || results.Length == 0)
        {
            var single = reader.Decode(source);
            if (single != null) results = new[] { single };
        }

        if (results == null) return Array.Empty<DecodedQr>();

        var decoded = new List<DecodedQr>();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var result in results)
        {
            if (result is null) continue;
            var raw = result.Text;
            if (string.IsNullOrWhiteSpace(raw) || !seen.Add(raw)) continue;

            var points = result.ResultPoints ?? Array.Empty<ResultPoint>();
            var bounds = points.Length == 0
                ? new PixelRect(0, 0, width, height)
                : new PixelRect(
                    points.Min(p => p.X),
                    points.Min(p => p.Y),
                    Math.Max(1, points.Max(p => p.X) - points.Min(p => p.X)),
                    Math.Max(1, points.Max(p => p.Y) - points.Min(p => p.Y)));

            // Coordinates are relative to the cropped region; move them into monitor space.
            decoded.Add(new DecodedQr(raw, new PixelRect(
                selection.X + bounds.X,
                selection.Y + bounds.Y,
                bounds.Width,
                bounds.Height)));
        }

        return decoded;
    }
}
