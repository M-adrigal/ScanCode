using System.Windows;

namespace ScanCode.App;

public static class Program
{
    [STAThread]
    public static void Main()
    {
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
