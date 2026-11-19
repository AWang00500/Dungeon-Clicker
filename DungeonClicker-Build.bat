@echo off
setlocal
cd /d "%~dp0"

set "CSC=%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo [ERROR] Windows .NET Framework 4.x compiler (csc.exe^) was not found.
  pause
  exit /b 1
)

set "CS_TMP=%TEMP%\DungeonClicker_%RANDOM%.cs"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$raw = [IO.File]::ReadAllText('%~f0', [Text.Encoding]::UTF8); $marker = '/*CS_' + 'START*/'; $idx = $raw.IndexOf($marker); if ($idx -lt 0) { exit 2 }; [IO.File]::WriteAllText('%CS_TMP%', $raw.Substring($idx), [Text.Encoding]::UTF8)"
if errorlevel 1 (
  echo [ERROR] Failed to extract C# source.
  pause
  exit /b 1
)

echo Building DungeonClicker.exe ...
"%CSC%" /nologo /target:winexe /optimize+ /out:"%~dp0DungeonClicker.exe" /r:System.dll,System.Drawing.dll,System.Windows.Forms.dll "%CS_TMP%"
set "BUILD_ERR=%errorlevel%"
del /q "%CS_TMP%" >nul 2>&1

if not "%BUILD_ERR%"=="0" (
  echo [ERROR] Build failed with code %BUILD_ERR%.
  pause
  exit /b 1
)

echo Build succeeded! Launching DungeonClicker.exe ...
start "" "%~dp0DungeonClicker.exe"
exit /b 0

/*CS_START*/
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace DungeonClickerOverlay
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new OverlayForm());
        }
    }

    internal sealed class OverlayForm : Form
    {
        private const int LogicalW = 320;
        private const int LogicalH = 180;
        private const int WinW = 560;
        private const int WinH = 315;
        private const int SlimeW = 96;
        private const int SlimeH = 74;

        private const int WM_INPUT = 0x00FF;
        private const uint RID_INPUT = 0x10000003;
        private const uint RIDEV_INPUTSINK = 0x00000100;
        private const uint RIM_TYPEMOUSE = 0;
        private const uint RIM_TYPEKEYBOARD = 1;

        private const int GWL_EXSTYLE = -20;
        private const int WS_EX_LAYERED = 0x00080000;
        private const int WS_EX_TRANSPARENT = 0x00000020;
        private const int WS_EX_TOPMOST = 0x00000008;
        private const byte AC_SRC_OVER = 0x00;
        private const byte AC_SRC_ALPHA = 0x01;
        private const int ULW_ALPHA = 0x02;

        [StructLayout(LayoutKind.Sequential)]
        private struct RAWINPUTDEVICE
        {
            public ushort usUsagePage;
            public ushort usUsage;
            public uint dwFlags;
            public IntPtr hwndTarget;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RAWINPUTHEADER
        {
            public uint dwType;
            public uint dwSize;
            public IntPtr hDevice;
            public IntPtr wParam;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct RAWMOUSE
        {
            [FieldOffset(0)] public ushort usFlags;
            [FieldOffset(4)] public uint ulButtons;
            [FieldOffset(4)] public ushort usButtonFlags;
            [FieldOffset(6)] public ushort usButtonData;
            [FieldOffset(8)] public uint ulRawButtons;
            [FieldOffset(12)] public int lLastX;
            [FieldOffset(16)] public int lLastY;
            [FieldOffset(20)] public uint ulExtraInformation;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RAWKEYBOARD
        {
            public ushort MakeCode;
            public ushort Flags;
            public ushort Reserved;
            public ushort VKey;
            public uint Message;
            public uint ExtraInformation;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT
        {
            public int x;
            public int y;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct SIZE
        {
            public int cx;
            public int cy;
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct BLENDFUNCTION
        {
            public byte BlendOp;
            public byte BlendFlags;
            public byte SourceConstantAlpha;
            public byte AlphaFormat;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterRawInputDevices(RAWINPUTDEVICE[] pRawInputDevices, uint uiNumDevices, uint cbSize);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint GetRawInputData(IntPtr hRawInput, uint uiCommand, IntPtr pData, ref uint pcbSize, uint cbSizeHeader);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool UpdateLayeredWindow(
            IntPtr hwnd,
            IntPtr hdcDst,
            ref POINT pptDst,
            ref SIZE psize,
            IntPtr hdcSrc,
            ref POINT pprSrc,
            int crKey,
            ref BLENDFUNCTION pblend,
            int dwFlags);

        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern IntPtr CreateCompatibleDC(IntPtr hDC);

        [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool DeleteDC(IntPtr hdc);

        [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);

        [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool DeleteObject(IntPtr hObject);

        private struct SlimePalette
        {
            public Color Outline;
            public Color Deep;
            public Color Shadow;
            public Color Base;
            public Color Light;
            public Color Shine;
        }

        private readonly SlimePalette[] _palettes;
        private readonly SlimePalette[] _rainbowBands;
        private readonly Bitmap _bgBitmap;
        private readonly Bitmap[] _slimeSprites;
        private readonly Bitmap[] _rainbowSprites;
        private readonly Bitmap _whiteFlashSprite;
        private readonly Bitmap _swordSprite;
        private readonly Bitmap _logicalBmp;
        private readonly Bitmap _windowBmp;

        private readonly Timer _frameTimer;
        private readonly HashSet<ushort> _heldKeys = new HashSet<ushort>();

        private bool _isPlaying = false;
        private bool _useDungeonBg = false;
        private bool _isClickThrough = false;
        private bool _isDragging = false;
        private Point _dragStartScreen;
        private Point _dragStartFormPos;
        private long _justStartedTicks = 0;

        private readonly Rectangle _bgRect = new Rectangle(WinW - 118, 6, 36, 20);
        private readonly Rectangle _moveRect = new Rectangle(WinW - 78, 6, 46, 20);
        private readonly Rectangle _closeRect = new Rectangle(WinW - 28, 6, 22, 20);
        private readonly Rectangle _startRect = new Rectangle((WinW - 180) / 2, WinH - 72, 180, 42);

        private long _totalClicks = 0;
        private int _stage = 1;
        private long _currentHp = 100;
        private long _nextStageClicks = 100;
        private int _colorIndex = 0;

        private int _displayedColorIndex = 0;
        private int _fadePhase = 0; // 0 = none, 1 = out, 2 = in
        private double _fadeTimer = 0.0;
        private const double FadeOutDur = 0.14;
        private const double FadeInDur = 0.16;

        private double _hitFlashTimer = 0.0;
        private const double HitFlashDur = 0.065;
        private double _shakeTimer = 0.0;
        private const double ShakeDur = 0.14;
        private bool _isSwinging = false;
        private double _swingTimer = 0.0;
        private const double SwingDur = 0.175;
        private double _elapsed = 0.0;
        private long _lastTicks;

        public OverlayForm()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.ShowInTaskbar = true;
            this.TopMost = true;
            this.Text = "Dungeon Clicker";
            this.StartPosition = FormStartPosition.Manual;
            Rectangle wa = Screen.PrimaryScreen.WorkingArea;
            this.Location = new Point(Math.Max(0, wa.Right - WinW - 24), Math.Max(0, wa.Bottom - WinH - 24));
            this.Size = new Size(WinW, WinH);

            _palettes = new SlimePalette[]
            {
                MakePal("#090b0a", "#123b1e", "#1f6e33", "#39b552", "#7ae86d", "#dcffd4"),
                MakePal("#080a10", "#11264f", "#1d4d99", "#3486e3", "#74c0ff", "#d9f2ff"),
                MakePal("#0b0810", "#2a1245", "#53218a", "#8d43db", "#c285ff", "#f2deff"),
                MakePal("#10080a", "#4a1019", "#8f1d2a", "#d93838", "#ff7d6e", "#ffdad4"),
                MakePal("#100c07", "#4f3208", "#996414", "#e8aa25", "#ffe066", "#fff9cc"),
                MakePal("#050508", "#0d0e14", "#1b1d26", "#2e3240", "#52586e", "#9ba3ba"),
                MakePal("#0b0c10", "#5f677a", "#939db3", "#cfd7e6", "#f0f4fa", "#ffffff")
            };

            _rainbowBands = new SlimePalette[]
            {
                MakePal("#09070d", "#5c111d", "#a82230", "#e84343", "#ff8a7a", "#ffe6e0"),
                MakePal("#09070d", "#5e2b0a", "#ab5316", "#eb8723", "#ffbd59", "#ffefd4"),
                MakePal("#09070d", "#544709", "#9c8614", "#e0c928", "#fff06b", "#fffbd4"),
                MakePal("#09070d", "#124520", "#1f7a38", "#38bf57", "#7ef075", "#deffd9"),
                MakePal("#09070d", "#0e3c52", "#1a7091", "#32b2d9", "#78e2ff", "#dbf8ff"),
                MakePal("#09070d", "#2f1452", "#5c269e", "#974ce8", "#ca8cff", "#f4e3ff")
            };

            _bgBitmap = BuildDungeonBackground();

            bool[,] mask = BuildSlimeMask();
            _slimeSprites = new Bitmap[_palettes.Length];
            for (int i = 0; i < _palettes.Length; i++)
            {
                _slimeSprites[i] = BuildSlimeBitmap(mask, _palettes[i], false, 0);
            }

            _rainbowSprites = new Bitmap[6];
            for (int f = 0; f < 6; f++)
            {
                _rainbowSprites[f] = BuildSlimeBitmap(mask, _palettes[0], true, f);
            }

            _whiteFlashSprite = BuildWhiteFlashBitmap(mask);
            _swordSprite = BuildSwordBitmap();
            _logicalBmp = new Bitmap(LogicalW, LogicalH, PixelFormat.Format32bppArgb);
            _windowBmp = new Bitmap(WinW, WinH, PixelFormat.Format32bppPArgb);

            _lastTicks = DateTime.UtcNow.Ticks;
            _frameTimer = new Timer();
            _frameTimer.Interval = 16;
            _frameTimer.Tick += OnFrameTick;
            _frameTimer.Start();
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= WS_EX_LAYERED | WS_EX_TOPMOST;
                return cp;
            }
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            RegisterGlobalRawInput();
            RenderAndPresent();
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            _frameTimer.Stop();
            _bgBitmap.Dispose();
            _logicalBmp.Dispose();
            _windowBmp.Dispose();
            _swordSprite.Dispose();
            _whiteFlashSprite.Dispose();
            for (int i = 0; i < _slimeSprites.Length; i++) _slimeSprites[i].Dispose();
            for (int i = 0; i < _rainbowSprites.Length; i++) _rainbowSprites[i].Dispose();
            base.OnFormClosed(e);
        }

        private void RegisterGlobalRawInput()
        {
            RAWINPUTDEVICE[] rids = new RAWINPUTDEVICE[2];

            // Global mouse listener (works unfocused and with click-through)
            rids[0].usUsagePage = 0x01;
            rids[0].usUsage = 0x02;
            rids[0].dwFlags = RIDEV_INPUTSINK;
            rids[0].hwndTarget = this.Handle;

            // Global keyboard listener (works unfocused)
            rids[1].usUsagePage = 0x01;
            rids[1].usUsage = 0x06;
            rids[1].dwFlags = RIDEV_INPUTSINK;
            rids[1].hwndTarget = this.Handle;

            RegisterRawInputDevices(rids, (uint)rids.Length, (uint)Marshal.SizeOf(typeof(RAWINPUTDEVICE)));
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_INPUT)
            {
                ProcessRawInput(m.LParam);
            }
            base.WndProc(ref m);
        }

        private void ProcessRawInput(IntPtr hRawInput)
        {
            uint dwSize = 0;
            uint headerSize = (uint)Marshal.SizeOf(typeof(RAWINPUTHEADER));
            GetRawInputData(hRawInput, RID_INPUT, IntPtr.Zero, ref dwSize, headerSize);
            if (dwSize == 0) return;

            IntPtr buffer = Marshal.AllocHGlobal((int)dwSize);
            try
            {
                if (GetRawInputData(hRawInput, RID_INPUT, buffer, ref dwSize, headerSize) != dwSize)
                    return;

                RAWINPUTHEADER header = (RAWINPUTHEADER)Marshal.PtrToStructure(buffer, typeof(RAWINPUTHEADER));
                IntPtr dataPtr = new IntPtr(buffer.ToInt64() + headerSize);

                if (header.dwType == RIM_TYPEKEYBOARD)
                {
                    RAWKEYBOARD kb = (RAWKEYBOARD)Marshal.PtrToStructure(dataPtr, typeof(RAWKEYBOARD));
                    if (kb.VKey == 0xFF) return;
                    bool isBreak = (kb.Flags & 0x01) != 0;
                    if (!isBreak)
                    {
                        if (!_heldKeys.Contains(kb.VKey))
                        {
                            _heldKeys.Add(kb.VKey);
                            if (_isPlaying)
                            {
                                RegisterAttack();
                            }
                        }
                    }
                    else
                    {
                        _heldKeys.Remove(kb.VKey);
                    }
                }
                else if (header.dwType == RIM_TYPEMOUSE)
                {
                    RAWMOUSE mouse = (RAWMOUSE)Marshal.PtrToStructure(dataPtr, typeof(RAWMOUSE));
                    ushort bf = mouse.usButtonFlags;
                    bool isBtnDown = (bf & (0x0001 | 0x0004 | 0x0010 | 0x0040 | 0x0100)) != 0;
                    if (isBtnDown && _isPlaying)
                    {
                        if ((DateTime.UtcNow.Ticks - _justStartedTicks) < 1500000) return;
                        Point cur = Cursor.Position;
                        Point local = new Point(cur.X - this.Left, cur.Y - this.Top);
                        if (!_isDragging && !_bgRect.Contains(local) && !_moveRect.Contains(local) && !_closeRect.Contains(local))
                        {
                            RegisterAttack();
                        }
                    }
                }
            }
            catch
            {
                // Keep message loop resilient against unexpected device packets
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button != MouseButtons.Left) return;

            if (_closeRect.Contains(e.Location))
            {
                this.Close();
                return;
            }

            if (_bgRect.Contains(e.Location))
            {
                _useDungeonBg = !_useDungeonBg;
                RenderAndPresent();
                return;
            }

            if (_moveRect.Contains(e.Location))
            {
                _isDragging = true;
                _dragStartScreen = Cursor.Position;
                _dragStartFormPos = this.Location;
                return;
            }

            if (!_isPlaying && _startRect.Contains(e.Location))
            {
                _justStartedTicks = DateTime.UtcNow.Ticks;
                _isPlaying = true;
                UpdateClickThroughState();
            }
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            if (_isDragging)
            {
                Point cur = Cursor.Position;
                this.Location = new Point(
                    _dragStartFormPos.X + (cur.X - _dragStartScreen.X),
                    _dragStartFormPos.Y + (cur.Y - _dragStartScreen.Y));
            }
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            if (e.Button == MouseButtons.Left)
            {
                _isDragging = false;
            }
        }

        private void UpdateClickThroughState()
        {
            if (this.IsDisposed || !this.IsHandleCreated) return;

            bool shouldPassThrough = false;
            if (_isPlaying && !_isDragging)
            {
                Point cur = Cursor.Position;
                Point local = new Point(cur.X - this.Left, cur.Y - this.Top);
                if (!_bgRect.Contains(local) && !_moveRect.Contains(local) && !_closeRect.Contains(local))
                {
                    shouldPassThrough = true;
                }
            }

            if (shouldPassThrough != _isClickThrough)
            {
                _isClickThrough = shouldPassThrough;
                int ex = GetWindowLong(this.Handle, GWL_EXSTYLE);
                if (shouldPassThrough)
                    SetWindowLong(this.Handle, GWL_EXSTYLE, ex | WS_EX_TRANSPARENT);
                else
                    SetWindowLong(this.Handle, GWL_EXSTYLE, ex & ~WS_EX_TRANSPARENT);
            }
        }

        private void ComputeProgress()
        {
            int s = 1;
            long rem = _totalClicks;
            long maxHp = 100;
            while (rem >= maxHp)
            {
                rem -= maxHp;
                s += 1;
                maxHp *= 2;
            }
            _stage = s;
            _currentHp = maxHp - rem;
            _nextStageClicks = _currentHp;
            _colorIndex = (s - 1) % 8;
        }

        private void RegisterAttack()
        {
            int prevStage = _stage;
            _totalClicks += 1;
            ComputeProgress();

            _isSwinging = true;
            _swingTimer = 0.0;
            _hitFlashTimer = HitFlashDur;
            _shakeTimer = ShakeDur;

            if (_stage > prevStage && (_fadePhase == 0 || _fadePhase == 2))
            {
                _fadePhase = 1;
                _fadeTimer = 0.0;
            }
        }

        private void OnFrameTick(object sender, EventArgs e)
        {
            long nowTicks = DateTime.UtcNow.Ticks;
            double rawDt = (nowTicks - _lastTicks) / 10000000.0;
            _lastTicks = nowTicks;
            double dt = Math.Min(Math.Max(rawDt, 0.0), 0.05);

            if (_isDragging)
            {
                Point cur = Cursor.Position;
                this.Location = new Point(
                    _dragStartFormPos.X + (cur.X - _dragStartScreen.X),
                    _dragStartFormPos.Y + (cur.Y - _dragStartScreen.Y));
            }
            UpdateClickThroughState();

            _elapsed += dt;
            if (_hitFlashTimer > 0.0) _hitFlashTimer = Math.Max(0.0, _hitFlashTimer - dt);
            if (_shakeTimer > 0.0) _shakeTimer = Math.Max(0.0, _shakeTimer - dt);

            if (_isSwinging)
            {
                _swingTimer += dt;
                if (_swingTimer >= SwingDur)
                {
                    _isSwinging = false;
                    _swingTimer = 0.0;
                }
            }

            if (_fadePhase == 1)
            {
                _fadeTimer += dt;
                if (_fadeTimer >= FadeOutDur)
                {
                    _displayedColorIndex = _colorIndex;
                    _fadePhase = 2;
                    _fadeTimer = 0.0;
                }
            }
            else if (_fadePhase == 2)
            {
                _fadeTimer += dt;
                if (_fadeTimer >= FadeInDur)
                {
                    _fadePhase = 0;
                    _fadeTimer = 0.0;
                    if (_displayedColorIndex != _colorIndex)
                    {
                        _fadePhase = 1;
                        _fadeTimer = 0.0;
                    }
                }
            }

            RenderAndPresent();
        }

        private void RenderAndPresent()
        {
            if (this.IsDisposed || !this.IsHandleCreated) return;

            using (Graphics lg = Graphics.FromImage(_logicalBmp))
            {
                lg.InterpolationMode = InterpolationMode.NearestNeighbor;
                lg.PixelOffsetMode = PixelOffsetMode.Half;
                lg.SmoothingMode = SmoothingMode.None;

                if (_useDungeonBg)
                {
                    lg.DrawImage(_bgBitmap, 0, 0);
                    DrawTorchFlames(lg, _elapsed);
                }
                else
                {
                    lg.Clear(Color.Transparent);
                }

                double slimeAlpha = 1.0;
                if (_fadePhase == 1) slimeAlpha = Math.Max(0.0, 1.0 - _fadeTimer / FadeOutDur);
                else if (_fadePhase == 2) slimeAlpha = Math.Min(1.0, _fadeTimer / FadeInDur);

                int shakeX = 0;
                if (_shakeTimer > 0.0)
                {
                    double ratio = _shakeTimer / ShakeDur;
                    double freq = Math.Sin((1.0 - ratio) * Math.PI * 5.0);
                    shakeX = (int)Math.Round(freq * 3.5 * ratio);
                }

                int slimeX = (LogicalW - SlimeW) / 2 + shakeX;
                int slimeY = 74;

                if (slimeAlpha > 0.01)
                {
                    int rIdx = Math.Abs((int)Math.Floor(_elapsed * 8.0)) % _rainbowSprites.Length;
                    Bitmap sprite = (_displayedColorIndex == 7)
                        ? _rainbowSprites[rIdx]
                        : _slimeSprites[_displayedColorIndex];

                    DrawWithAlpha(lg, sprite, slimeX, slimeY, (float)slimeAlpha);

                    if (_hitFlashTimer > 0.0)
                    {
                        float flashA = (float)(slimeAlpha * Math.Min(1.0, (_hitFlashTimer / HitFlashDur) * 1.15));
                        DrawWithAlpha(lg, _whiteFlashSprite, slimeX, slimeY, flashA);
                    }
                }

                if (_isSwinging)
                {
                    double u = _swingTimer / SwingDur;
                    if (u >= 0.14 && u <= 0.58)
                    {
                        DrawPixelSlashArc(lg, (u - 0.14) / 0.44);
                    }
                }

                DrawSword(lg);
            }

            using (Graphics wg = Graphics.FromImage(_windowBmp))
            {
                wg.Clear(Color.Transparent);
                wg.InterpolationMode = InterpolationMode.NearestNeighbor;
                wg.PixelOffsetMode = PixelOffsetMode.Half;
                wg.SmoothingMode = SmoothingMode.None;
                wg.DrawImage(_logicalBmp, new Rectangle(0, 0, WinW, WinH));

                DrawOverlayUi(wg);
            }

            PresentLayeredBitmap(_windowBmp);
        }

        private void DrawOverlayUi(Graphics g)
        {
            using (Brush ctrlBg = new SolidBrush(Color.FromArgb(225, 16, 14, 22)))
            using (Brush bgActiveBrush = new SolidBrush(Color.FromArgb(235, 46, 111, 61)))
            using (Pen ctrlBorder = new Pen(Color.FromArgb(255, 89, 82, 104), 2))
            using (Pen bgActiveBorder = new Pen(Color.FromArgb(255, 136, 224, 108), 2))
            using (Font btnFont = new Font("Consolas", 8.5f, FontStyle.Bold))
            using (Brush textBrush = new SolidBrush(Color.FromArgb(255, 230, 226, 216)))
            {
                g.FillRectangle(_useDungeonBg ? bgActiveBrush : ctrlBg, _bgRect);
                g.DrawRectangle(_useDungeonBg ? bgActiveBorder : ctrlBorder, _bgRect);
                DrawCenteredText(g, "BG", btnFont, textBrush, _bgRect);

                g.FillRectangle(ctrlBg, _moveRect);
                g.DrawRectangle(ctrlBorder, _moveRect);
                DrawCenteredText(g, "MOVE", btnFont, textBrush, _moveRect);

                g.FillRectangle(ctrlBg, _closeRect);
                g.DrawRectangle(ctrlBorder, _closeRect);
                DrawCenteredText(g, "X", btnFont, textBrush, _closeRect);
            }

            if (_isPlaying)
            {
                Rectangle hud = new Rectangle(12, 32, WinW - 24, 48);
                using (Brush hudBg = new SolidBrush(Color.FromArgb(232, 16, 14, 22)))
                using (Pen outerPen = new Pen(Color.FromArgb(255, 89, 82, 104), 3))
                using (Pen innerPen = new Pen(Color.FromArgb(255, 43, 39, 54), 2))
                using (Font lblFont = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (Font valFont = new Font("Consolas", 13.5f, FontStyle.Bold))
                using (Brush lblBrush = new SolidBrush(Color.FromArgb(255, 163, 155, 178)))
                using (Brush valBrush = new SolidBrush(Color.FromArgb(255, 244, 239, 230)))
                {
                    g.FillRectangle(hudBg, hud);
                    g.DrawRectangle(outerPen, hud);

                    string[] labels = { "TOTAL CLICKS", "CURRENT STAGE", "CURRENT HP", "NEXT STAGE" };
                    string[] values = {
                        _totalClicks.ToString(),
                        _stage.ToString(),
                        _currentHp.ToString(),
                        _nextStageClicks.ToString()
                    };

                    int colW = hud.Width / 4;
                    for (int i = 0; i < 4; i++)
                    {
                        int cx = hud.Left + i * colW;
                        if (i > 0)
                        {
                            g.DrawLine(innerPen, cx, hud.Top + 6, cx, hud.Bottom - 6);
                        }
                        Rectangle lblR = new Rectangle(cx, hud.Top + 6, colW, 14);
                        Rectangle valR = new Rectangle(cx, hud.Top + 21, colW, 22);
                        DrawCenteredText(g, labels[i], lblFont, lblBrush, lblR);
                        DrawCenteredText(g, values[i], valFont, valBrush, valR);
                    }
                }
            }
            else
            {
                Rectangle titleBox = new Rectangle((WinW - 360) / 2, 36, 360, 52);
                using (Brush tBg = new SolidBrush(Color.FromArgb(238, 20, 18, 27)))
                using (Pen tPen = new Pen(Color.FromArgb(255, 109, 100, 128), 3))
                using (Font tFont = new Font("Consolas", 20f, FontStyle.Bold))
                using (Brush tBrush = new SolidBrush(Color.FromArgb(255, 243, 237, 226)))
                {
                    g.FillRectangle(tBg, titleBox);
                    g.DrawRectangle(tPen, titleBox);
                    DrawCenteredText(g, "DUNGEON CLICKER", tFont, tBrush, titleBox);
                }

                using (Brush sBg = new SolidBrush(Color.FromArgb(245, 46, 111, 61)))
                using (Pen sPen = new Pen(Color.FromArgb(255, 136, 224, 108), 3))
                using (Font sFont = new Font("Consolas", 13f, FontStyle.Bold))
                using (Brush sBrush = new SolidBrush(Color.FromArgb(255, 247, 243, 235)))
                {
                    g.FillRectangle(sBg, _startRect);
                    g.DrawRectangle(sPen, _startRect);
                    DrawCenteredText(g, "START GAME", sFont, sBrush, _startRect);
                }
            }
        }

        private static void DrawCenteredText(Graphics g, string text, Font font, Brush brush, Rectangle rect)
        {
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Center;
            sf.LineAlignment = StringAlignment.Center;
            g.DrawString(text, font, brush, rect, sf);
            sf.Dispose();
        }

        private static void DrawWithAlpha(Graphics g, Bitmap bmp, int x, int y, float alpha)
        {
            if (alpha >= 0.99f)
            {
                g.DrawImage(bmp, x, y);
                return;
            }
            ColorMatrix cm = new ColorMatrix();
            cm.Matrix33 = alpha;
            using (ImageAttributes ia = new ImageAttributes())
            {
                ia.SetColorMatrix(cm, ColorMatrixFlag.Default, ColorAdjustType.Bitmap);
                g.DrawImage(bmp, new Rectangle(x, y, bmp.Width, bmp.Height), 0, 0, bmp.Width, bmp.Height, GraphicsUnit.Pixel, ia);
            }
        }

        private static void DrawPixelSlashArc(Graphics g, double t)
        {
            int steps = 18;
            double head = Math.Min(1.0, t * 1.35);
            double tail = Math.Max(0.0, t * 1.35 - 0.52);

            using (Brush darkB = new SolidBrush(Color.FromArgb(255, 11, 10, 16)))
            using (Brush midB = new SolidBrush(Color.FromArgb(255, 203, 213, 225)))
            using (Brush whiteB = new SolidBrush(Color.White))
            {
                for (int i = 0; i <= steps; i++)
                {
                    double s = (double)i / steps;
                    if (s < tail || s > head) continue;

                    double inv = 1.0 - s;
                    double sx = inv * inv * 224.0 + 2.0 * inv * s * 150.0 + s * s * 98.0;
                    double sy = inv * inv * 58.0 + 2.0 * inv * s * 92.0 + s * s * 136.0;
                    int px = (int)Math.Round(sx);
                    int py = (int)Math.Round(sy);

                    int th = s > head - 0.15 ? 3 : 2;
                    g.FillRectangle(darkB, px - 2, py - 2, th + 3, th + 3);
                    g.FillRectangle(midB, px - 1, py - 1, th + 1, th + 1);
                    g.FillRectangle(whiteB, px, py, th, th);
                }
            }
        }

        private void DrawSword(Graphics g)
        {
            double posX = 270.0;
            double posY = 166.0;
            double angleRad = -0.45;
            double scale = 2.15;

            if (_isSwinging)
            {
                double u = _swingTimer / SwingDur;
                if (u < 0.14)
                {
                    double p = u / 0.14;
                    posX = 270.0 + (278.0 - 270.0) * p;
                    posY = 166.0 + (86.0 - 166.0) * p;
                    angleRad = -0.45 + (0.42 - -0.45) * p;
                    scale = 2.15 + 0.15 * p;
                }
                else if (u < 0.56)
                {
                    double p = (u - 0.14) / 0.42;
                    double ease = 1.0 - (1.0 - p) * (1.0 - p);
                    posX = 278.0 + (136.0 - 278.0) * ease;
                    posY = 86.0 + (158.0 - 86.0) * ease;
                    angleRad = 0.42 + (-1.62 - 0.42) * ease;
                    scale = 2.3;
                }
                else
                {
                    double p = (u - 0.56) / 0.44;
                    double ease = 1.0 - Math.Pow(1.0 - p, 2.0);
                    posX = 136.0 + (270.0 - 136.0) * ease;
                    posY = 158.0 + (166.0 - 158.0) * ease;
                    angleRad = -1.62 + (-0.45 - -1.62) * ease;
                    scale = 2.3 - 0.15 * ease;
                }
            }

            GraphicsState st = g.Save();
            g.TranslateTransform((float)Math.Round(posX), (float)Math.Round(posY));
            g.RotateTransform((float)(angleRad * 180.0 / Math.PI));
            g.ScaleTransform((float)scale, (float)scale);
            g.DrawImage(_swordSprite, -12, -38);
            g.Restore(st);
        }

        private void PresentLayeredBitmap(Bitmap bitmap)
        {
            IntPtr screenDc = GetDC(IntPtr.Zero);
            IntPtr memDc = CreateCompatibleDC(screenDc);
            IntPtr hBitmap = IntPtr.Zero;
            IntPtr oldBitmap = IntPtr.Zero;

            try
            {
                hBitmap = bitmap.GetHbitmap(Color.FromArgb(0));
                oldBitmap = SelectObject(memDc, hBitmap);

                SIZE size = new SIZE();
                size.cx = bitmap.Width;
                size.cy = bitmap.Height;

                POINT pointSource = new POINT();
                pointSource.x = 0;
                pointSource.y = 0;

                POINT topPos = new POINT();
                topPos.x = this.Left;
                topPos.y = this.Top;

                BLENDFUNCTION blend = new BLENDFUNCTION();
                blend.BlendOp = AC_SRC_OVER;
                blend.BlendFlags = 0;
                blend.SourceConstantAlpha = 255;
                blend.AlphaFormat = AC_SRC_ALPHA;

                UpdateLayeredWindow(this.Handle, screenDc, ref topPos, ref size, memDc, ref pointSource, 0, ref blend, ULW_ALPHA);
            }
            finally
            {
                if (oldBitmap != IntPtr.Zero) SelectObject(memDc, oldBitmap);
                if (hBitmap != IntPtr.Zero) DeleteObject(hBitmap);
                DeleteDC(memDc);
                ReleaseDC(IntPtr.Zero, screenDc);
            }
        }

        private static double Hash2d(int x, int y)
        {
            unchecked
            {
                uint n = (uint)(x * 374761393 + y * 668265263);
                n = (n ^ (n >> 13)) * 1274126177u;
                n = n ^ (n >> 16);
                return n / 4294967295.0;
            }
        }

        private static int ClampByte(double v)
        {
            int iv = (int)Math.Round(v);
            if (iv < 0) return 0;
            if (iv > 255) return 255;
            return iv;
        }

        private static double TorchLightAt(int px, int py)
        {
            double d1 = Math.Sqrt(Math.Pow((px - 46) * 0.9, 2) + Math.Pow((py - 70) * 1.15, 2));
            double d2 = Math.Sqrt(Math.Pow((px - 274) * 0.9, 2) + Math.Pow((py - 70) * 1.15, 2));
            double g1 = Math.Max(0.0, 1.0 - d1 / 78.0);
            double g2 = Math.Max(0.0, 1.0 - d2 / 78.0);
            return Math.Min(1.0, g1 * g1 + g2 * g2);
        }

        private static Bitmap BuildDungeonBackground()
        {
            Bitmap bmp = new Bitmap(LogicalW, LogicalH, PixelFormat.Format32bppArgb);
            int backLeft = 96;
            int backRight = 224;
            int backTop = 32;
            int backBottom = 116;

            for (int y = 0; y < LogicalH; y++)
            {
                for (int x = 0; x < LogicalW; x++)
                {
                    double r = 24.0;
                    double g = 24.0;
                    double b = 30.0;

                    if (x >= backLeft && x < backRight && y >= backTop && y < backBottom)
                    {
                        int archHalfW = 34;
                        int dx = x - 160;
                        bool inArchRect = Math.Abs(dx) <= archHalfW && y >= 62;
                        double archCurveY = 62.0 - Math.Sqrt(Math.Max(0.0, archHalfW * archHalfW - dx * dx)) * 0.58;
                        bool inArch = inArchRect || (Math.Abs(dx) <= archHalfW && y >= archCurveY);

                        if (inArch)
                        {
                            double rimDist = Math.Min(archHalfW - Math.Abs(dx), y - archCurveY);
                            if (rimDist < 2.0) { r = 16; g = 15; b = 22; }
                            else
                            {
                                r = 6; g = 5; b = 10;
                                if (y > 100 && (x + y) % 11 == 0) { r = 9; g = 8; b = 14; }
                            }
                        }
                        else
                        {
                            int row = (y - backTop) / 12;
                            int colOffset = (row % 2) * 10;
                            int localY = (y - backTop) % 12;
                            int localX = (x - backLeft + colOffset) % 20;
                            bool isMortar = localY == 0 || localX == 0;
                            double blockNoise = Hash2d((x - backLeft + colOffset) / 20 + 17, row + 3);
                            double micro = Hash2d(x, y);
                            if (isMortar) { r = 14; g = 14; b = 18; }
                            else
                            {
                                double baseShade = 28.0 + blockNoise * 12.0 + (micro - 0.5) * 6.0;
                                double bevel = (localY == 1 || localX == 1) ? 5.0 : (localY == 11 || localX == 19) ? -5.0 : 0.0;
                                double val = baseShade + bevel;
                                r = val; g = val + 1.0; b = val + 6.0;
                                if (blockNoise > 0.84 && micro > 0.65) { r -= 4.0; g += 5.0; b -= 4.0; }
                            }
                        }
                    }
                    else if (x < backLeft && y >= (x / (double)backLeft) * backTop && y < LogicalH - (x / (double)backLeft) * (LogicalH - backBottom))
                    {
                        double t = x / (double)backLeft;
                        double wallTop = t * backTop;
                        double wallBot = LogicalH - t * (LogicalH - backBottom);
                        double vNorm = (y - wallTop) / Math.Max(1.0, wallBot - wallTop);
                        double courseFloat = vNorm * 7.0;
                        int row = (int)Math.Floor(courseFloat);
                        double courseFrac = courseFloat - row;
                        double uDepth = -Math.Log(1.0 - t * 0.72) * 4.2 + (row % 2) * 0.5;
                        int col = (int)Math.Floor(uDepth);
                        double colFrac = uDepth - col;
                        bool isMortar = courseFrac < 0.08 || colFrac < 0.07;
                        double bh = Hash2d(col + 31, row + 11);
                        double micro = Hash2d(x, y);
                        if (isMortar) { r = 15; g = 14; b = 19; }
                        else
                        {
                            double depthDarken = 1.0 - t * 0.36;
                            double bVal = (44.0 + bh * 16.0 + (micro - 0.5) * 6.0) * depthDarken;
                            double bevel = courseFrac < 0.16 ? 6.0 : courseFrac > 0.9 ? -6.0 : 0.0;
                            r = bVal + bevel; g = bVal + bevel + 1.0; b = bVal + bevel + 6.0;
                            if (bh > 0.8 && micro > 0.62) { r -= 4.0; g += 6.0; b -= 3.0; }
                        }
                    }
                    else if (x >= backRight && y >= ((LogicalW - x) / (double)backLeft) * backTop && y < LogicalH - ((LogicalW - x) / (double)backLeft) * (LogicalH - backBottom))
                    {
                        int distFromRight = LogicalW - 1 - x;
                        double t = distFromRight / (double)backLeft;
                        double wallTop = t * backTop;
                        double wallBot = LogicalH - t * (LogicalH - backBottom);
                        double vNorm = (y - wallTop) / Math.Max(1.0, wallBot - wallTop);
                        double courseFloat = vNorm * 7.0;
                        int row = (int)Math.Floor(courseFloat);
                        double courseFrac = courseFloat - row;
                        double uDepth = -Math.Log(1.0 - t * 0.72) * 4.2 + (row % 2) * 0.5;
                        int col = (int)Math.Floor(uDepth);
                        double colFrac = uDepth - col;
                        bool isMortar = courseFrac < 0.08 || colFrac < 0.07;
                        double bh = Hash2d(col + 97, row + 29);
                        double micro = Hash2d(x, y);
                        if (isMortar) { r = 15; g = 14; b = 19; }
                        else
                        {
                            double depthDarken = 1.0 - t * 0.36;
                            double bVal = (44.0 + bh * 16.0 + (micro - 0.5) * 6.0) * depthDarken;
                            double bevel = courseFrac < 0.16 ? 6.0 : courseFrac > 0.9 ? -6.0 : 0.0;
                            r = bVal + bevel; g = bVal + bevel + 1.0; b = bVal + bevel + 6.0;
                            if (bh > 0.8 && micro > 0.62) { r -= 4.0; g += 6.0; b -= 3.0; }
                        }
                    }
                    else if (y < backTop)
                    {
                        double t = y / (double)backTop;
                        double leftEdge = t * backLeft;
                        double rightEdge = LogicalW - t * backLeft;
                        double uNorm = (x - leftEdge) / Math.Max(1.0, rightEdge - leftEdge);
                        double depthZ = -Math.Log(1.0 - t * 0.65) * 3.5;
                        int row = (int)Math.Floor(depthZ);
                        double rowFrac = depthZ - row;
                        double colFloat = uNorm * 6.0 + (row % 2) * 0.5;
                        int col = (int)Math.Floor(colFloat);
                        double colFrac = colFloat - col;
                        bool isMortar = rowFrac < 0.1 || colFrac < 0.06;
                        double h = Hash2d(col + 5, row + 51);
                        double micro = Hash2d(x, y);
                        if (isMortar) { r = 11; g = 10; b = 15; }
                        else
                        {
                            double shade = (24.0 + h * 10.0 + (micro - 0.5) * 4.0) * (1.0 - t * 0.28);
                            r = shade; g = shade; b = shade + 5.0;
                        }
                    }
                    else
                    {
                        double t = (LogicalH - 1 - y) / (double)(LogicalH - backBottom);
                        double leftEdge = t * backLeft;
                        double rightEdge = LogicalW - t * backLeft;
                        double uNorm = (x - leftEdge) / Math.Max(1.0, rightEdge - leftEdge);
                        double depthZ = -Math.Log(1.0 - t * 0.72) * 4.4;
                        int row = (int)Math.Floor(depthZ);
                        double rowFrac = depthZ - row;
                        double colFloat = uNorm * 7.0 + (row % 2) * 0.5;
                        int col = (int)Math.Floor(colFloat);
                        double colFrac = colFloat - col;
                        bool isMortar = rowFrac < 0.09 || colFrac < 0.06;
                        double sh = Hash2d(col + 71, row + 13);
                        double micro = Hash2d(x, y);
                        if (isMortar) { r = 12; g = 12; b = 16; }
                        else
                        {
                            double depthDarken = 1.0 - t * 0.35;
                            double bVal = (36.0 + sh * 14.0 + (micro - 0.5) * 5.0) * depthDarken;
                            double bevel = rowFrac > 0.88 ? 4.0 : rowFrac < 0.15 ? -4.0 : 0.0;
                            r = bVal + bevel; g = bVal + bevel + 1.0; b = bVal + bevel + 6.0;
                        }
                    }

                    double glow = TorchLightAt(x, y);
                    if (glow > 0.01)
                    {
                        r += glow * 58.0;
                        g += glow * 32.0;
                        b += glow * 8.0;
                    }

                    double sdx = (x - 160) / 48.0;
                    double sdy = (y - 142) / 10.0;
                    double sDist = sdx * sdx + sdy * sdy;
                    if (sDist < 1.0)
                    {
                        double sf = 0.25 + 0.75 * sDist;
                        r *= sf; g *= sf; b *= sf;
                    }

                    bmp.SetPixel(x, y, Color.FromArgb(255, ClampByte(r), ClampByte(g), ClampByte(b)));
                }
            }

            using (Graphics bg = Graphics.FromImage(bmp))
            {
                DrawTorchMount(bg, 46, 78);
                DrawTorchMount(bg, 274, 78);
            }
            return bmp;
        }

        private static void DrawTorchMount(Graphics g, int tx, int ty)
        {
            using (Brush b1 = new SolidBrush(ColorTranslator.FromHtml("#191a20")))
            using (Brush b2 = new SolidBrush(ColorTranslator.FromHtml("#3f434f")))
            using (Brush b3 = new SolidBrush(ColorTranslator.FromHtml("#3d2412")))
            using (Brush b4 = new SolidBrush(ColorTranslator.FromHtml("#613a1c")))
            using (Brush b5 = new SolidBrush(ColorTranslator.FromHtml("#241814")))
            {
                g.FillRectangle(b1, tx - 3, ty + 3, 6, 7);
                g.FillRectangle(b2, tx - 2, ty + 4, 4, 2);
                g.FillRectangle(b3, tx - 1, ty - 2, 2, 10);
                g.FillRectangle(b4, tx - 1, ty - 2, 1, 7);
                g.FillRectangle(b5, tx - 2, ty - 4, 4, 3);
            }
        }

        private static void DrawTorchFlames(Graphics g, double timeSec)
        {
            int frame = Math.Abs((int)Math.Floor(timeSec * 7.0)) % 4;
            int[] xs = { 46, 274 };
            int[] phases = { 0, 2 };

            using (Brush outerB = new SolidBrush(ColorTranslator.FromHtml("#d94814")))
            using (Brush midB = new SolidBrush(ColorTranslator.FromHtml("#f59e0b")))
            using (Brush coreB = new SolidBrush(ColorTranslator.FromHtml("#fef08a")))
            {
                for (int i = 0; i < 2; i++)
                {
                    int tx = xs[i];
                    int ty = 74;
                    int f = (frame + phases[i]) % 4;
                    int tipDx = f == 1 ? -1 : f == 3 ? 1 : 0;
                    int tipH = (f == 0 || f == 2) ? 0 : 1;

                    g.FillRectangle(outerB, tx - 3, ty - 4, 6, 5);
                    g.FillRectangle(outerB, tx - 2, ty - 7, 4, 3);
                    g.FillRectangle(outerB, tx - 1 + tipDx, ty - 9 - tipH, 2, 3);

                    g.FillRectangle(midB, tx - 2, ty - 4, 4, 4);
                    g.FillRectangle(midB, tx - 1, ty - 6, 2, 3);

                    g.FillRectangle(coreB, tx - 1, ty - 3, 2, 3);
                    g.FillRectangle(coreB, tx, ty - 5, 1, 2);
                }
            }
        }

        private static SlimePalette MakePal(string o, string d, string s, string b, string l, string sh)
        {
            SlimePalette p = new SlimePalette();
            p.Outline = ColorTranslator.FromHtml(o);
            p.Deep = ColorTranslator.FromHtml(d);
            p.Shadow = ColorTranslator.FromHtml(s);
            p.Base = ColorTranslator.FromHtml(b);
            p.Light = ColorTranslator.FromHtml(l);
            p.Shine = ColorTranslator.FromHtml(sh);
            return p;
        }

        private static bool IsInsideSlime(int x, int y)
        {
            int dx = x - 48;
            if (y < 9 || y > 69) return false;

            double v = (y - 9) / 60.0;
            double halfWidth;
            if (v < 0.25)
            {
                double t = (0.25 - v) / 0.25;
                halfWidth = 31.0 * Math.Sqrt(Math.Max(0.0, 1.0 - t * t * 0.92));
            }
            else if (v < 0.78)
            {
                double t2 = (v - 0.25) / 0.53;
                halfWidth = 31.0 + t2 * 12.0;
            }
            else
            {
                double t3 = (v - 0.78) / 0.22;
                halfWidth = 43.0 - t3 * t3 * 5.0;
            }

            double lobeBump = Math.Sin(v * Math.PI * 3.2) * 1.4;
            if (Math.Abs(dx) > halfWidth + lobeBump) return false;

            if (y > 65)
            {
                double foldWave = Math.Cos((dx / 42.0) * Math.PI * 3.0);
                double maxY = 67.5 + foldWave * 1.4;
                if (y > maxY) return false;
            }
            return true;
        }

        private static bool[,] BuildSlimeMask()
        {
            bool[,] mask = new bool[SlimeH, SlimeW];
            for (int y = 0; y < SlimeH; y++)
                for (int x = 0; x < SlimeW; x++)
                    mask[y, x] = IsInsideSlime(x, y);
            return mask;
        }

        private static bool IsOutline(bool[,] mask, int x, int y)
        {
            if (!mask[y, x]) return false;
            for (int oy = -1; oy <= 1; oy++)
            {
                for (int ox = -1; ox <= 1; ox++)
                {
                    if (ox == 0 && oy == 0) continue;
                    int nx = x + ox;
                    int ny = y + oy;
                    if (nx < 0 || nx >= SlimeW || ny < 0 || ny >= SlimeH || !mask[ny, nx])
                        return true;
                }
            }
            return false;
        }

        private Bitmap BuildSlimeBitmap(bool[,] mask, SlimePalette pal, bool isRainbow, int frameIdx)
        {
            Bitmap bmp = new Bitmap(SlimeW, SlimeH, PixelFormat.Format32bppArgb);
            double[] bxs = { 30.0, 64.0, 49.0, 23.0, 70.0 };
            double[] bys = { 52.0, 48.0, 58.0, 42.0, 59.0 };
            double[] brs = { 2.3, 2.6, 2.0, 1.6, 1.8 };

            for (int py = 0; py < SlimeH; py++)
            {
                for (int px = 0; px < SlimeW; px++)
                {
                    if (!mask[py, px]) continue;

                    SlimePalette activePal = pal;
                    if (isRainbow)
                    {
                        int bandCoord = (int)Math.Floor((px * 0.45 + py * 0.75 + frameIdx * 4.0) / 4.0);
                        int bIdx = ((bandCoord % _rainbowBands.Length) + _rainbowBands.Length) % _rainbowBands.Length;
                        activePal = _rainbowBands[bIdx];
                    }

                    if (IsOutline(mask, px, py))
                    {
                        bmp.SetPixel(px, py, activePal.Outline);
                        continue;
                    }

                    bool inLeftEye = px >= 33 && px <= 41 && py >= 33 && py <= 41;
                    bool inRightEye = px >= 55 && px <= 63 && py >= 33 && py <= 41;
                    if (inLeftEye || inRightEye)
                    {
                        int ex = inLeftEye ? px - 33 : px - 55;
                        int ey = py - 33;
                        if (ey == 0)
                        {
                            bmp.SetPixel(px, py, activePal.Deep);
                            continue;
                        }
                        bool corner = (ex == 0 || ex == 8) && (ey == 1 || ey == 8);
                        if (!corner)
                        {
                            if ((ex >= 2 && ex <= 3 && ey >= 2 && ey <= 3) || (ex == 6 && ey == 6))
                                bmp.SetPixel(px, py, Color.FromArgb(255, 248, 250, 252));
                            else
                                bmp.SetPixel(px, py, Color.FromArgb(255, 9, 8, 15));
                            continue;
                        }
                    }

                    double d1 = Math.Sqrt(Math.Pow((px - 31) * 0.8, 2) + Math.Pow((py - 20) * 1.15, 2));
                    double d2 = Math.Sqrt(Math.Pow(px - 23, 2) + Math.Pow(py - 28, 2));
                    if (d1 < 3.4 || d2 < 1.8)
                    {
                        bmp.SetPixel(px, py, activePal.Shine);
                        continue;
                    }

                    bool inBubble = false;
                    for (int bi = 0; bi < bxs.Length; bi++)
                    {
                        double dist = Math.Sqrt(Math.Pow(px - bxs[bi], 2) + Math.Pow(py - bys[bi], 2));
                        if (dist < brs[bi])
                        {
                            inBubble = true;
                            break;
                        }
                    }
                    if (inBubble)
                    {
                        bmp.SetPixel(px, py, activePal.Shadow);
                        continue;
                    }

                    double lightBias = (px - 40) * 0.35 + (py - 24) * 0.85;
                    bool dither = (px + py) % 2 == 0;
                    if (py >= 62 || lightBias > 34.0) bmp.SetPixel(px, py, activePal.Deep);
                    else if (py >= 54 || lightBias > 22.0 || (lightBias > 18.0 && dither)) bmp.SetPixel(px, py, activePal.Shadow);
                    else if (lightBias < 4.0 || (lightBias < 8.0 && dither)) bmp.SetPixel(px, py, activePal.Light);
                    else bmp.SetPixel(px, py, activePal.Base);
                }
            }
            return bmp;
        }

        private static Bitmap BuildWhiteFlashBitmap(bool[,] mask)
        {
            Bitmap bmp = new Bitmap(SlimeW, SlimeH, PixelFormat.Format32bppArgb);
            for (int y = 0; y < SlimeH; y++)
                for (int x = 0; x < SlimeW; x++)
                    if (mask[y, x]) bmp.SetPixel(x, y, Color.White);
            return bmp;
        }

        private static Bitmap BuildSwordBitmap()
        {
            string[] rows = new string[]
            {
                "...........OO...........",
                "..........OEEO..........",
                ".........OEDSEO.........",
                ".........OEDrSO.........",
                "........OEDSSSEO........",
                "........OEDSRSEO........",
                ".......OEDSSSSSEO.......",
                ".......OEDrSSSSrO.......",
                ".......OEDSSSDSEO.......",
                "........OEDSSDSEO.......",
                ".......OEDSSSDSEO.......",
                ".......OERSSSDSEO.......",
                ".......OErSSSDSSO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDSSSDSO........",
                ".......OEDSSSDSEO.......",
                ".......OERrSSDSEO.......",
                ".......OERSSSDSEO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDSSSDSrO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDrSSDSEO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDSSSDSEO.......",
                ".......OEDSSSDSEO.......",
                "....OOOOEDSSSDSEOOOO....",
                "...OGGGgEDSSSDSEgGGGO...",
                "..OGrGGggggggggggGGgrO..",
                "...OOOOggggggggggOOOO...",
                "........OOLLLLOO........",
                ".........OllllO.........",
                ".........OLLLLLO........",
                ".........OllllO.........",
                ".........OLLLLLO........",
                ".........OllllO.........",
                ".........OLLLLLO........",
                "........OOPPPPOO........",
                ".......OOPPPPPPOO.......",
                ".......OOPPrPPPOO.......",
                "........OOPPPPOO........",
                ".........OOOOOO........."
            };

            Dictionary<char, Color> pal = new Dictionary<char, Color>();
            pal['O'] = ColorTranslator.FromHtml("#0b0a10");
            pal['E'] = ColorTranslator.FromHtml("#bac2cf");
            pal['S'] = ColorTranslator.FromHtml("#7f8896");
            pal['D'] = ColorTranslator.FromHtml("#4a505e");
            pal['R'] = ColorTranslator.FromHtml("#6b3113");
            pal['r'] = ColorTranslator.FromHtml("#9e4c1d");
            pal['G'] = ColorTranslator.FromHtml("#8c94a3");
            pal['g'] = ColorTranslator.FromHtml("#424754");
            pal['L'] = ColorTranslator.FromHtml("#6b3f22");
            pal['l'] = ColorTranslator.FromHtml("#3d2211");
            pal['P'] = ColorTranslator.FromHtml("#636978");

            int h = rows.Length;
            int w = rows[0].Length;
            Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            for (int y = 0; y < h; y++)
            {
                string row = rows[y];
                for (int x = 0; x < row.Length; x++)
                {
                    char ch = row[x];
                    if (ch == '.') continue;
                    Color c;
                    if (pal.TryGetValue(ch, out c))
                    {
                        bmp.SetPixel(x, y, c);
                    }
                }
            }
            return bmp;
        }
    }
}
