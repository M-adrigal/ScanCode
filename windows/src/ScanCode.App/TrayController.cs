using System.Drawing;
using System.Windows.Forms;

namespace ScanCode.App;

public sealed class TrayController : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly Icon? _ownedIcon;

    public event Action? OpenRequested;
    public event Action? StartRequested;
    public event Action? ExitRequested;

    public TrayController()
    {
        // 图标来自程序集内嵌资源，不依赖 exe 旁边的文件。
        _ownedIcon = AppIcon.LoadTrayIcon();

        _icon = new NotifyIcon
        {
            Icon = _ownedIcon ?? SystemIcons.Application,
            Text = "扫码助手",
            Visible = true
        };

        var menu = new ContextMenuStrip();
        menu.Items.Add("打开扫码助手", null, (_, _) => OpenRequested?.Invoke());
        menu.Items.Add("开始识别二维码", null, (_, _) => StartRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("退出", null, (_, _) => ExitRequested?.Invoke());
        _icon.ContextMenuStrip = menu;
        _icon.MouseClick += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) OpenRequested?.Invoke();
        };
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
        _ownedIcon?.Dispose();
    }
}
