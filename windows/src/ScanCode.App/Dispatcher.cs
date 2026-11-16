using System.Diagnostics;
using ScanCode.Core;

namespace ScanCode.App;

public sealed class DispatchException : Exception
{
    public DispatchException(string message) : base(message) { }
}

public sealed class Dispatcher
{
    private readonly AppRegistry _registry;

    public Dispatcher(AppRegistry registry)
    {
        _registry = registry;
    }

    public string Dispatch(QrPayload payload, AppDescriptor app)
    {
        using var running = _registry.FindRunning(app);
        if (running == null)
        {
            Log.Write($"dispatch: {app.Id} not running");
            throw new DispatchException($"先打开{app.DisplayName}，再试一次。");
        }

        Log.Write($"dispatch: {app.Id} clipboard+activate");
        ClipboardService.SetText(payload.ClipboardText);
        if (!_registry.Activate(app, running))
        {
            throw new DispatchException($"已复制，但没能唤起{app.DisplayName}。");
        }

        if (app.Id == KnownApps.Quark.Id)
        {
            _registry.TryFocusAddressBar(running);
            return "已复制，已唤起夸克";
        }

        return "已复制，已唤起百度网盘";
    }
}
