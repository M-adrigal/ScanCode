using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using ScanCode.Core;

namespace ScanCode.App;

public sealed class WelcomeWindow : Window
{
    public event Action? StartRequested;
    public event Action? QuitRequested;

    private readonly AppRegistry _registry;
    private readonly StackPanel _statusPanel = new();

    public WelcomeWindow(AppRegistry registry)
    {
        _registry = registry;
        Width = 520;
        Height = 460;
        WindowStyle = WindowStyle.SingleBorderWindow;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Title = "扫码助手";
        Icon = LoadIcon();
        Background = new SolidColorBrush(Color.FromRgb(246, 247, 249));

        var root = new Grid { Margin = new Thickness(36, 22, 36, 22) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var icon = new Image
        {
            Source = LoadIcon(),
            Width = 88,
            Height = 88,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 8)
        };
        Grid.SetRow(icon, 0);
        root.Children.Add(icon);

        var title = new TextBlock
        {
            Text = "扫码助手",
            FontSize = 24,
            FontWeight = FontWeights.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center,
            Foreground = new SolidColorBrush(Color.FromRgb(28, 32, 38))
        };
        Grid.SetRow(title, 1);
        root.Children.Add(title);

        var subtitle = new TextBlock
        {
            Text = "框选屏幕上的二维码，\n在已打开的应用里继续。",
            FontSize = 13,
            TextAlignment = TextAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
            Foreground = new SolidColorBrush(Color.FromRgb(100, 106, 116)),
            Margin = new Thickness(0, 6, 0, 16)
        };
        Grid.SetRow(subtitle, 2);
        root.Children.Add(subtitle);

        var card = new Border
        {
            Background = Brushes.White,
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(18, 12, 18, 12),
            Height = 118,
            VerticalAlignment = VerticalAlignment.Top
        };
        var cardStack = new StackPanel();
        cardStack.Children.Add(new TextBlock
        {
            Text = "应用",
            FontSize = 11,
            FontWeight = FontWeights.Medium,
            Foreground = new SolidColorBrush(Color.FromRgb(130, 136, 146)),
            Margin = new Thickness(0, 0, 0, 8)
        });
        cardStack.Children.Add(_statusPanel);
        card.Child = cardStack;
        Grid.SetRow(card, 3);
        root.Children.Add(card);

        var start = new Button
        {
            Content = "开始识别二维码",
            Height = 42,
            Width = 300,
            HorizontalAlignment = HorizontalAlignment.Center,
            Background = new SolidColorBrush(Color.FromRgb(37, 99, 235)),
            Foreground = Brushes.White,
            BorderThickness = new Thickness(0),
            FontSize = 14,
            FontWeight = FontWeights.SemiBold
        };
        start.Click += (_, _) => StartRequested?.Invoke();
        Grid.SetRow(start, 4);
        root.Children.Add(start);

        var footer = new Grid { Margin = new Thickness(0, 14, 0, 0) };
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var quit = new Button
        {
            Content = "退出",
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Foreground = new SolidColorBrush(Color.FromRgb(120, 126, 136)),
            Padding = new Thickness(0),
            FontSize = 11
        };
        quit.Click += (_, _) => QuitRequested?.Invoke();
        Grid.SetColumn(quit, 0);
        footer.Children.Add(quit);

        var version = new TextBlock
        {
            Text = "v0.1.6-win",
            FontSize = 10,
            Foreground = new SolidColorBrush(Color.FromRgb(160, 166, 176)),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        Grid.SetColumn(version, 2);
        footer.Children.Add(version);

        Grid.SetRow(footer, 5);
        root.Children.Add(footer);

        Content = root;
        Refresh();
        Activated += (_, _) => Refresh();
    }

    public void Refresh()
    {
        _statusPanel.Children.Clear();
        _statusPanel.Children.Add(StatusRow(KnownApps.Baidu));
        _statusPanel.Children.Add(StatusRow(KnownApps.Quark));
    }

    private UIElement StatusRow(AppDescriptor app)
    {
        var state = _registry.GetState(app);
        var color = state switch
        {
            AppState.Running => Color.FromRgb(34, 197, 94),
            AppState.NotRunning => Color.FromRgb(150, 156, 166),
            _ => Color.FromRgb(239, 68, 68)
        };

        var panel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 4, 0, 4)
        };
        panel.Children.Add(new TextBlock
        {
            Text = "●",
            Foreground = new SolidColorBrush(color),
            FontSize = 11,
            Margin = new Thickness(0, 2, 7, 0)
        });
        panel.Children.Add(new TextBlock
        {
            Text = app.DisplayName,
            Foreground = new SolidColorBrush(Color.FromRgb(32, 36, 42)),
            FontSize = 12,
            FontWeight = FontWeights.Medium,
            Width = 78
        });
        panel.Children.Add(new TextBlock
        {
            Text = state switch
            {
                AppState.Running => "运行中",
                AppState.NotRunning => "未打开",
                _ => "未安装"
            },
            Foreground = new SolidColorBrush(Color.FromRgb(110, 116, 126)),
            FontSize = 11,
            Margin = new Thickness(0, 1, 0, 0)
        });
        return panel;
    }

    private static ImageSource LoadIcon() => AppIcon.Load();
}
