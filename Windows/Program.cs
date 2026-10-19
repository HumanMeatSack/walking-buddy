using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Drawing = System.Drawing;
using Forms = System.Windows.Forms;

namespace WalkingBuddy.Windows;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        var application = new System.Windows.Application
        {
            ShutdownMode = ShutdownMode.OnExplicitShutdown
        };
        var buddy = new WalkingBuddyApp(application);
        application.Run();
        GC.KeepAlive(buddy);
    }
}

internal sealed record PetDefinition(
    string Key,
    string Title,
    string Icon,
    string Asset,
    BobStyle BobStyle);

internal enum BobStyle
{
    Float,
    Sleigh,
    Hop,
    Gentle,
    Waddle,
    Scuttle
}

internal sealed class BuddySettings
{
    public string SelectedPet { get; set; } = "automatic";
    public string Scale { get; set; } = "normal";
    public double Speed { get; set; } = 90;
    public bool Paused { get; set; }
}

internal sealed class WalkingBuddyApp : IDisposable
{
    private static readonly PetDefinition[] Pets =
    [
        new("halloweenGhost", "Halloween Ghost", "👻", "halloween-ghost.png", BobStyle.Float),
        new("santaSleigh", "Santa & Sleigh", "🎅", "santa-sleigh.png", BobStyle.Sleigh),
        new("springBunny", "Spring Bunny", "🐰", "spring-bunny.png", BobStyle.Hop),
        new("wizardCat", "Wizard Cat", "🐈‍⬛", "wizard-cat.png", BobStyle.Gentle),
        new("tinyDragon", "Tiny Dragon", "🐉", "tiny-dragon.png", BobStyle.Gentle),
        new("ufoAlien", "UFO Alien", "🛸", "ufo-alien.png", BobStyle.Gentle),
        new("snowman", "Snowman", "☃️", "snowman.png", BobStyle.Waddle),
        new("beachCrab", "Beach Crab", "🦀", "beach-crab.png", BobStyle.Scuttle)
    ];

    private static readonly (string Key, string Title, double Factor)[] Scales =
    [
        ("tiny", "Tiny", 0.55),
        ("small", "Small", 0.75),
        ("normal", "Normal", 1.0),
        ("large", "Large", 1.35),
        ("huge", "Huge", 1.75)
    ];

    private readonly System.Windows.Application application;
    private readonly Window window;
    private readonly System.Windows.Controls.Image image;
    private readonly Forms.NotifyIcon trayIcon;
    private readonly Forms.ContextMenuStrip menu;
    private readonly DispatcherTimer timer;
    private readonly Stopwatch clock = Stopwatch.StartNew();
    private readonly Dictionary<string, BitmapImage> images = new();
    private readonly Dictionary<string, Forms.ToolStripMenuItem> petMenuItems = new();
    private readonly Dictionary<string, Forms.ToolStripMenuItem> scaleMenuItems = new();
    private readonly Dictionary<double, Forms.ToolStripMenuItem> speedMenuItems = new();
    private readonly string settingsPath;
    private readonly BuddySettings settings;

    private PetDefinition activePet = Pets[4];
    private Forms.ToolStripMenuItem pauseMenuItem = null!;
    private double direction = 1;
    private double horizontalPosition;
    private double motionBaseTop;
    private double lastSeconds;
    private double dragStartLeft;
    private bool isDragging;
    private bool disposed;

    public WalkingBuddyApp(System.Windows.Application application)
    {
        this.application = application;
        settingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "WalkingBuddy",
            "settings.json");
        settings = LoadSettings();

        foreach (var pet in Pets)
        {
            images[pet.Key] = LoadImage(pet.Asset);
        }

        image = new System.Windows.Controls.Image
        {
            Stretch = Stretch.Uniform,
            SnapsToDevicePixels = true,
            RenderTransformOrigin = new System.Windows.Point(0.5, 0.5)
        };

        window = new Window
        {
            Title = "Walking Buddy",
            Content = image,
            WindowStyle = WindowStyle.None,
            ResizeMode = ResizeMode.NoResize,
            AllowsTransparency = true,
            Background = System.Windows.Media.Brushes.Transparent,
            Topmost = true,
            ShowInTaskbar = false,
            ShowActivated = false,
            SizeToContent = SizeToContent.Manual
        };
        window.MouseLeftButtonDown += BeginDrag;
        window.Closing += (_, eventArgs) =>
        {
            if (!disposed)
            {
                eventArgs.Cancel = true;
                window.Hide();
            }
        };

        menu = BuildMenu();
        trayIcon = new Forms.NotifyIcon
        {
            Icon = Drawing.SystemIcons.Application,
            Text = "Walking Buddy",
            ContextMenuStrip = menu,
            Visible = true
        };
        trayIcon.MouseClick += (_, eventArgs) =>
        {
            if (eventArgs.Button == Forms.MouseButtons.Left)
            {
                menu.Show(Forms.Cursor.Position);
            }
        };

        ApplyPetSelection(keepBottomPosition: false);
        ResetToBottom(resetHorizontal: true);
        window.Show();

        Microsoft.Win32.SystemEvents.DisplaySettingsChanged += DisplaySettingsChanged;
        timer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromMilliseconds(16)
        };
        lastSeconds = clock.Elapsed.TotalSeconds;
        timer.Tick += Tick;
        timer.Start();
    }

    private Forms.ContextMenuStrip BuildMenu()
    {
        var contextMenu = new Forms.ContextMenuStrip();
        var characterMenu = new Forms.ToolStripMenuItem("Choose Character");
        AddPetMenuItem(characterMenu, "automatic", "✨  Auto Seasonal");
        foreach (var pet in Pets)
        {
            AddPetMenuItem(characterMenu, pet.Key, $"{pet.Icon}  {pet.Title}");
        }
        contextMenu.Items.Add(characterMenu);

        var sizeMenu = new Forms.ToolStripMenuItem("Character Size");
        foreach (var scale in Scales)
        {
            var item = new Forms.ToolStripMenuItem(scale.Title);
            item.Click += (_, _) => application.Dispatcher.Invoke(() => ChooseScale(scale.Key));
            sizeMenu.DropDownItems.Add(item);
            scaleMenuItems[scale.Key] = item;
        }
        contextMenu.Items.Add(sizeMenu);
        contextMenu.Items.Add(new Forms.ToolStripSeparator());

        pauseMenuItem = new Forms.ToolStripMenuItem();
        pauseMenuItem.Click += (_, _) => application.Dispatcher.Invoke(TogglePause);
        contextMenu.Items.Add(pauseMenuItem);

        var resetItem = new Forms.ToolStripMenuItem("Reset to Bottom");
        resetItem.Click += (_, _) => application.Dispatcher.Invoke(() => ResetToBottom(resetHorizontal: false));
        contextMenu.Items.Add(resetItem);
        contextMenu.Items.Add(new Forms.ToolStripSeparator());

        foreach (var option in new[] { (50.0, "Slow"), (90.0, "Normal"), (150.0, "Fast") })
        {
            var item = new Forms.ToolStripMenuItem(option.Item2);
            item.Click += (_, _) => application.Dispatcher.Invoke(() => ChooseSpeed(option.Item1));
            contextMenu.Items.Add(item);
            speedMenuItems[option.Item1] = item;
        }

        contextMenu.Items.Add(new Forms.ToolStripSeparator());
        var quitItem = new Forms.ToolStripMenuItem("Quit Walking Buddy");
        quitItem.Click += (_, _) => application.Dispatcher.Invoke(Quit);
        contextMenu.Items.Add(quitItem);
        return contextMenu;
    }

    private void AddPetMenuItem(Forms.ToolStripMenuItem parent, string key, string title)
    {
        var item = new Forms.ToolStripMenuItem(title);
        item.Click += (_, _) => application.Dispatcher.Invoke(() => ChoosePet(key));
        parent.DropDownItems.Add(item);
        petMenuItems[key] = item;
    }

    private void Tick(object? sender, EventArgs eventArgs)
    {
        var now = clock.Elapsed.TotalSeconds;
        var delta = Math.Min(now - lastSeconds, 0.05);
        lastSeconds = now;
        if (settings.Paused || isDragging)
        {
            return;
        }

        var bounds = SystemParameters.WorkArea;
        if (bounds.Width <= window.Width)
        {
            return;
        }

        var leftEdge = bounds.Left;
        var rightEdge = bounds.Right - window.Width;
        horizontalPosition += settings.Speed * direction * delta;
        if (horizontalPosition >= rightEdge)
        {
            horizontalPosition = rightEdge;
            direction = -1;
            UpdateDirection();
        }
        else if (horizontalPosition <= leftEdge)
        {
            horizontalPosition = leftEdge;
            direction = 1;
            UpdateDirection();
        }

        window.Left = horizontalPosition;
        window.Top = motionBaseTop - BobOffset(now);
    }

    private double BobOffset(double time) => activePet.BobStyle switch
    {
        BobStyle.Float => (Math.Sin(time * 2.6) + 1) * 8,
        BobStyle.Sleigh => (Math.Sin(time * 3.2) + 1) * 3,
        BobStyle.Hop => Math.Abs(Math.Sin(time * 5.5)) * 11,
        BobStyle.Gentle => (Math.Sin(time * 2.8) + 1) * 7,
        BobStyle.Waddle => Math.Abs(Math.Sin(time * 3.5)) * 3,
        BobStyle.Scuttle => Math.Abs(Math.Sin(time * 8.0)) * 2,
        _ => 0
    };

    private void BeginDrag(object sender, MouseButtonEventArgs eventArgs)
    {
        if (eventArgs.ChangedButton != MouseButton.Left)
        {
            return;
        }

        isDragging = true;
        dragStartLeft = window.Left;
        try
        {
            window.DragMove();
        }
        catch (InvalidOperationException)
        {
            // The mouse can be released before WPF starts the system drag.
        }

        var bounds = SystemParameters.WorkArea;
        var horizontalDelta = window.Left - dragStartLeft;
        if (horizontalDelta > 1)
        {
            direction = 1;
        }
        else if (horizontalDelta < -1)
        {
            direction = -1;
        }

        var now = clock.Elapsed.TotalSeconds;
        horizontalPosition = Math.Clamp(window.Left, bounds.Left, Math.Max(bounds.Left, bounds.Right - window.Width));
        motionBaseTop = window.Top + BobOffset(now);
        ClampMotionBase(bounds);
        window.Left = horizontalPosition;
        window.Top = motionBaseTop - BobOffset(now);
        UpdateDirection();
        isDragging = false;
        lastSeconds = now;
    }

    private void ChoosePet(string key)
    {
        settings.SelectedPet = key;
        ApplyPetSelection(keepBottomPosition: true);
        SaveSettings();
    }

    private void ChooseScale(string key)
    {
        settings.Scale = key;
        ApplyPetSelection(keepBottomPosition: true);
        SaveSettings();
    }

    private void ChooseSpeed(double speed)
    {
        settings.Speed = speed;
        UpdateMenuChecks();
        SaveSettings();
    }

    private void TogglePause()
    {
        settings.Paused = !settings.Paused;
        pauseMenuItem.Text = settings.Paused ? "Resume Walking" : "Pause Walking";
        lastSeconds = clock.Elapsed.TotalSeconds;
        SaveSettings();
    }

    private void ApplyPetSelection(bool keepBottomPosition)
    {
        var previousBottom = motionBaseTop + window.Height;
        activePet = ResolvePet();
        var source = images[activePet.Key];
        var scale = Scales.FirstOrDefault(value => value.Key == settings.Scale);
        var factor = scale.Factor == 0 ? 1.0 : scale.Factor;
        var height = 160 * factor;
        var width = height * source.PixelWidth / source.PixelHeight;

        window.Width = width;
        window.Height = height;
        image.Source = source;
        UpdateDirection();
        if (keepBottomPosition && previousBottom > 0)
        {
            motionBaseTop = previousBottom - height;
        }

    