using System.Windows;

namespace ScanCode.App;

public static class Alerts
{
    public static void NoQr()
    {
        MessageBox.Show(
            "没识别到二维码。请重新框选，尽量贴近二维码边缘。",
            "扫码助手",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    public static bool RetryQr()
    {
        return MessageBox.Show(
            "没识别到二维码，重试？",
            "扫码助手",
            MessageBoxButton.YesNo,
            MessageBoxImage.Information) == MessageBoxResult.Yes;
    }

    public static void CaptureFailed(string message)
    {
        MessageBox.Show(message, "无法截取屏幕", MessageBoxButton.OK, MessageBoxImage.Warning);
    }

    public static void DispatchFailed(string message)
    {
        MessageBox.Show(message, "操作失败", MessageBoxButton.OK, MessageBoxImage.Warning);
    }

    public static void Info(string message)
    {
        MessageBox.Show(message, "扫码助手", MessageBoxButton.OK, MessageBoxImage.Information);
    }
}
