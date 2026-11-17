using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using ScanCode.Core;

namespace ScanCode.App;

public sealed class ResultWindow : Window
{
    public event Action<AppDescriptor>? AppSelected;
    public event Action? CopyRequested;

    private readonly AppDescriptor? _app;

    public ResultWindow(QrPayload payload, AppDescriptor? app, AppState state)
    {
        _app = app;
        Width = app == null ? 480 : 520;
        Height = app == null ? 112 : 128;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.Manual;
        Icon = AppIcon.Load(32);

        var root = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(238, 17, 20, 24)),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(16, 12, 16, 12)
        };

        var grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new Grid();
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        // 24 DIP 的小图取 48 帧再高质量缩放，比直接用 16 帧清晰。
        var icon = new Image
        {
            Source = AppIcon.Load(48),
            Width = 24,
            Height = 24,
            Margin = new Thickness(0, 3, 10, 0),
            VerticalAlignment = VerticalAlignment.Top
        };
        RenderOptions.SetBitmapScalingMode(icon, BitmapScalingMode.HighQuality);
        Grid.SetColumn(icon, 0);
        header.Children.Add(icon);

        var textStack = new StackPanel();
        textStack.Children.Add(new TextBlock
        {
            Text = payload.Title,
            Foreground = Brushes.White,
            FontSize = 15,
            FontWeight = FontWeights.SemiBold
        });
        textStack.Children.Add(new TextBlock
        {
            Text = payload.Summary,
            Foreground = new SolidColorBrush(Color.FromRgb(170, 176, 186)),
            FontSize = 11.5,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(0, 3, 0, 0)
        });
        Grid.SetColumn(textStack, 1);
        header.Children.Add(textStack);

        if (!string.IsNullOrWhiteSpace(payload.ExtractCode))
        {
            var badge = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(30, 255, 255, 255)),
                CornerRadius = new CornerRadius(7),
                Padding = new Thickness(9, 4, 9, 4),
                VerticalAlignment = VerticalAlignment.Top,
                Child = new TextBlock
                {
                    Text = $"提取码 {payload.ExtractCode}",
                    Foreground = Brushes.White,
                    FontSize = 11
                }
            };
            Grid.SetColumn(badge, 2);
            header.Children.Add(badge);
        }

        Grid.SetRow(header, 0);
        grid.Children.Add(header);

        var footer = new DockPanel { Margin = new Thickness(0, 10, 0, 0), LastChildFill = false };

        if (app != null)
        {
            var appButton = new Button
            {
                Content = $"{app.DisplayName}   ● {StateText(state)}",
                Padding = new Thickness(16, 7, 16, 7),
                Background = new SolidColorBrush(Color.FromRgb(37, 99, 235)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                FontSize = 12.5,
                FontWeight = FontWeights.Medium,
                HorizontalContentAlignment = HorizontalAlignment.Center,
                MinWidth = 220
            };
            appButton.Click += (_, _) => AppSelected?.Invoke(app);
            DockPanel.SetDock(appButton, Dock.Left);
            footer.Children.Add(appButton);
        }

        var copy = new Button
        {
            Content = app == null ? "复制链接" : "复制",
            Padding = new Thickness(14, 7, 14, 7),
            Background = new SolidColorBrush(Color.FromArgb(36, 255, 255, 255)),
            Foreground = Brushes.White,
            BorderThickness = new Thickness(0),
            FontSize = 12,
            HorizontalAlignment = HorizontalAlignment.Left
        };
        copy.Click += (_, _) => CopyRequested?.Invoke();
        DockPanel.SetDock(copy, app == null ? Dock.Left : Dock.Right);
        footer.Children.Add(copy);

        var close = new Button
        {
            Content = "关闭",
            Padding = new Thickness(14, 7, 14, 7),
            Background = new SolidColorBrush(Color.FromArgb(36, 255, 255, 255)),
            Foreground = Brushes.White,
            BorderThickness = new Thickness(0),
            FontSize = 12,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        close.Click += (_, _) => Close();
        DockPanel.SetDock(close, Dock.Right);
        footer.Children.Add(close);

        Grid.SetRow(footer, 1);
        grid.Children.Add(footer);
        root.Child = grid;
        Content = root;

        KeyDown += (_, e) =>
        {
            if (e.Key == System.Windows.Input.Key.Escape) Close();
        };
    }

    public void ShowNear(PixelRect anchor, double scale)
    {
        var working = System.Windows.Forms.Screen.FromPoint(
            new System.Drawing.Point((int)anchor.CenterX, (int)anchor.CenterY)).WorkingArea;

        var left = anchor.CenterX / scale - Width / 2;
        var top = anchor.Bottom / scale + 12;
        if (top + Height > working.Bottom / scale)
        {
            top = anchor.Y / scale - Height - 12;
        }

        var workLeft = working.Left / scale;
        var workTop = working.Top / scale;
        var workRight = working.Right / scale - Width;
        var workBottom = working.Bottom / scale - Height;
        Left = Math.Max(workLeft + 8, Math.Min(left, workRight - 8));
        Top = Math.Max(workTop + 8, Math.Min(top, workBottom - 8));

        Show();
        Activate();
        Focus();
    }

    private static string StateText(AppState state) => state switch
    {
        AppState.Running => "运行中",
        AppState.NotRunning => "未打开",
        _ => "未安装"
    };
}
