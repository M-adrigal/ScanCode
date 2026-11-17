using System.Windows;

namespace ScanCode.App;

public static class Program
{
    private const string InstanceLockName = @"Local\ScanCode.SingleInstance";

    [STAThread]
    public static void Main()
    {
        Log.Write($"starting {Environment.OSVersion} dotnet={Environment.Version}");

        // 第二个实例抢不到全局热键，还会多出一个托盘图标，所以直接退出。
        using var instanceLock = new Mutex(true, InstanceLockName, out var isFirstInstance);
        if (!isFirstInstance)
        {
            Alerts.Info("扫码助手已经在运行，请看任务栏右下角的托盘图标。");
            return;
        }

        var application = new Application
        {
            ShutdownMode = ShutdownMode.OnExplicitShutdown
        };

        var controller = new AppController();
        application.Startup += (_, _) => controller.Start();
        application.Exit += (_, _) => controller.Dispose();
        application.Run();
    }
}
