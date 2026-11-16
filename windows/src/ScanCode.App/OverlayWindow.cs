using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using ScanCode.Capture;
using ScanCode.Core;

namespace ScanCode.App;

public sealed class OverlayWindow : Window
{
    public CapturedMonitor Monitor { get; }

    public event Action<CapturedMonitor, PixelRect>? SelectionConfirmed;
    public event Action<DecodedQr>? HotspotSelected;
    public event Action? Cancelled;

    private readonly Canvas _canvas = new();
    private readonly Border _selectionBorder;
    private readonly Border _sizeBadge;
    private readonly TextBlock _sizeText;
    private readonly Button _confirm;
    private readonly Border _hintBorder;
    private readonly TextBlock _hint;
    private readonly Border _banner;
    private readonly TextBlock _bannerText;
    private readonly List<Button> _hotspotButtons = new();

    private Point _start;
    private Rect _selectionDip;
    private bool _dragging;
    private bool _hotspotMode;

    public OverlayWindow(CapturedMonitor monitor)
    {
        Monitor = monitor;

        Width = monitor.Bounds.Width / monitor.Scale;
        Height = monitor.Bounds.Height / monitor.Scale;
        Left = monitor.Bounds.X / monitor.Scale;
        Top = monitor.Bounds.Y / monitor.Scale;
        WindowStartupLocation = WindowStartupLocation.Manual;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        Focusable = true;

        var root = new Grid();
        root.Children.Add(new Image
        {
            Source = monitor.Image,
            Stretch = Stretch.Fill,
            IsHitTestVisible = false
        });

        root.Children.Add(new Rectangle
        {
            Fill = new SolidColorBrush(Color.FromArgb(108, 0, 0, 0)),
            IsHitTestVisible = false
        });

        _canvas.Background = Brushes.Transparent;
        root.Children.Add(_canvas);

        _selectionBorder = new Border
        {
            BorderBrush = new SolidColorBrush(Color.FromRgb(59, 130, 246)),
            BorderThickness = new Thickness(2),
            Background = Brushes.Transparent,
            Visibility = Visibility.Collapsed,
            IsHitTestVisible = false
        };
        _canvas.Children.Add(_selectionBorder);

        _sizeText = new TextBlock
        {
            Foreground = Brushes.White,
            FontSize = 11,
            FontFamily = new FontFamily("Consolas")
        };
        _sizeBadge = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(230, 10, 14, 20)),
            CornerRadius = new CornerRadius(5),
            Padding = new Thickness(7, 3, 7, 3),
            Child = _sizeText,
            Visibility = Visibility.Collapsed,
            IsHitTestVisible = false
        };
        _canvas.Children.Add(_sizeBadge);

        _confirm = new Button
        {
            Content = "解析二维码",
            Padding = new Thickness(16, 7, 16, 7),
            Background = new SolidColorBrush(Color.FromRgb(37, 99, 235)),
            Foreground = Brushes.White,
            BorderThickness = new Thickness(0),
            FontSize = 12.5,
            FontWeight = FontWeights.Medium,
            Visibility = Visibility.Collapsed
        };
        _confirm.Click += (_, _) => ConfirmSelection();
        _canvas.Children.Add(_confirm);

        _hint = new TextBlock
        {
            Text = "拖动框选二维码　·　Esc 取消",
            Foreground = Brushes.White,
            FontSize = 12
        };
        _hintBorder = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(210, 10, 14, 20)),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(14, 6, 14, 6),
            Child = _hint,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(0, 0, 0, 24),
            IsHitTestVisible = false
        };
        root.Children.Add(_hintBorder);

        _bannerText = new TextBlock
        {
            Foreground = Brushes.White,
            FontSize = 13,
            FontWeight = FontWeights.Medium,
            TextAlignment = TextAlignment.Center
        };
        _banner = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(238, 10, 14, 20)),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(18, 8, 18, 8),
            Child = _bannerText,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(0, 22, 0, 0),
            Visibility = Visibility.Collapsed,
            IsHitTestVisible = false
        };
        root.Children.Add(_banner);

        Content = root;
        MouseLeftButtonDown += OnMouseDown;
        MouseMove += OnMouseMove;
        MouseLeftButtonUp += OnMouseUp;
        KeyDown += OnKeyDown;
        Loaded += (_, _) =>
        {
            Activate();
            Focus();
            Keyboard.Focus(this);
        };
    }

    private void OnMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (_hotspotMode) return;
        if (e.OriginalSource is Button) return;

        _start = e.GetPosition(_canvas);
        _dragging = true;
        _selectionBorder.Visibility = Visibility.Collapsed;
        _sizeBadge.Visibility = Visibility.Collapsed;
        _confirm.Visibility = Visibility.Collapsed;
        _hint.Text = "拖动框选二维码　·　Esc 取消";
        CaptureMouse();
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        if (!_dragging) return;
        var current = e.GetPosition(_canvas);
        UpdateSelection(ClampRect(new Rect(_start, current)));
    }

    private void OnMouseUp(object sender, MouseButtonEventArgs e)
    {
        if (!_dragging) return;
        _dragging = false;
        ReleaseMouseCapture();

        var current = e.GetPosition(_canvas);
        var rect = ClampRect(new Rect(_start, current));
        if (rect.Width < 10 || rect.Height < 10)
        {
            _selectionBorder.Visibility = Visibility.Collapsed;
            _sizeBadge.Visibility = Visibility.Collapsed;
            _confirm.Visibility = Visibility.Collapsed;
            return;
        }

        _selectionDip = rect;
        UpdateSelection(rect);
        _confirm.Visibility = Visibility.Visible;
        Canvas.SetLeft(_confirm, Math.Min(Math.Max(12, rect.Right - 118), Math.Max(12, ActualWidth - 130)));
        Canvas.SetTop(_confirm, Math.Min(rect.Bottom + 8, Math.Max(12, ActualHeight - 48)));
        _hint.Text = "点「解析二维码」继续　·　拖动可重选　·　Esc 取消";
    }

    private void UpdateSelection(Rect rect)
    {
        _selectionDip = rect;
        _selectionBorder.Visibility = Visibility.Visible;
        _selectionBorder.Width = rect.Width;
        _selectionBorder.Height = rect.Height;
        Canvas.SetLeft(_selectionBorder, rect.X);
        Canvas.SetTop(_selectionBorder, rect.Y);

        _sizeBadge.Visibility = Visibility.Visible;
        _sizeText.Text = $"{(int)(rect.Width * Monitor.Scale)} × {(int)(rect.Height * Monitor.Scale)}";
        Canvas.SetLeft(_sizeBadge, Math.Max(4, rect.X));
        Canvas.SetTop(_sizeBadge, Math.Max(4, rect.Y - 28));
    }

    private void ConfirmSelection()
    {
        if (_selectionDip.Width <= 0 || _selectionDip.Height <= 0) return;
        _confirm.IsEnabled = false;
        _hint.Text = "正在解析…";
        var scale = Monitor.Scale;
        var pixels = new PixelRect(
            _selectionDip.X * scale,
            _selectionDip.Y * scale,
            _selectionDip.Width * scale,
            _selectionDip.Height * scale);
        Dispatcher.BeginInvoke(new Action(() => SelectionConfirmed?.Invoke(Monitor, pixels)));
    }

    public void ShowHotspots(IReadOnlyList<DecodedQr> spots)
    {
        _hotspotMode = true;
        _confirm.Visibility = Visibility.Collapsed;
        _sizeBadge.Visibility = Visibility.Collapsed;
        _hint.Text = "选择要识别的二维码　·　Esc 取消";
        _bannerText.Text = $"发现 {spots.Count} 个二维码，点击一个继续";
        _banner.Visibility = Visibility.Visible;

        foreach (var button in _hotspotButtons) _canvas.Children.Remove(button);
        _hotspotButtons.Clear();

        var scale = Monitor.Scale;
        for (var i = 0; i < spots.Count; i++)
        {
            var spot = spots[i];
            var rect = new Rect(
                spot.Bounds.X / scale,
                spot.Bounds.Y / scale,
                Math.Max(24, spot.Bounds.Width / scale),
                Math.Max(24, spot.Bounds.Height / scale));

            var button = new Button
            {
                Content = (i + 1).ToString(),
                Width = rect.Width,
                Height = rect.Height,
                Background = new SolidColorBrush(Color.FromArgb(52, 59, 130, 246)),
                BorderBrush = new SolidColorBrush(Color.FromRgb(59, 130, 246)),
                BorderThickness = new Thickness(2),
                Foreground = Brushes.White,
                FontSize = 14,
                FontWeight = FontWeights.Bold,
                HorizontalContentAlignment = HorizontalAlignment.Left,
                VerticalContentAlignment = VerticalAlignment.Top,
                Padding = new Thickness(8, 4, 0, 0)
            };
            button.Click += (_, _) =>
            {
                foreach (var other in _hotspotButtons) other.IsEnabled = false;
                Dispatcher.BeginInvoke(new Action(() => HotspotSelected?.Invoke(spot)));
            };
            Canvas.SetLeft(button, rect.X);
            Canvas.SetTop(button, rect.Y);
            _canvas.Children.Add(button);
            _hotspotButtons.Add(button);
        }
    }

    private void OnKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            e.Handled = true;
            Cancelled?.Invoke();
        }
    }

    private Rect ClampRect(Rect rect)
    {
        var left = Math.Max(0, Math.Min(rect.Left, ActualWidth));
        var top = Math.Max(0, Math.Min(rect.Top, ActualHeight));
        var right = Math.Max(0, Math.Min(rect.Right, ActualWidth));
        var bottom = Math.Max(0, Math.Min(rect.Bottom, ActualHeight));
        return new Rect(left, top, Math.Max(0, right - left), Math.Max(0, bottom - top));
    }
}
