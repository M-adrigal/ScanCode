using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace ScanCode.App;

public sealed class HudWindow : Window
{
    private readonly DispatcherTimer _timer;

    public HudWindow(string message)
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ShowActivated = false;
        ResizeMode = ResizeMode.NoResize;
        SizeToContent = SizeToContent.WidthAndHeight;

        var border = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(238, 17, 20, 24)),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(18, 10, 18, 10),
            Child = new TextBlock
            {
                Text = message,
                Foreground = Brushes.White,
                FontSize = 13
            }
        };
        Content = border;

        Loaded += (_, _) => Position();
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2.4) };
        _timer.Tick += (_, _) =>
        {
            _timer.Stop();
            Close();
        };
        _timer.Start();
    }

    private void Position()
    {
        var work = SystemParameters.WorkArea;
        Left = work.Left + (work.Width - ActualWidth) / 2;
        Top = work.Bottom - ActualHeight - 48;
    }
}
