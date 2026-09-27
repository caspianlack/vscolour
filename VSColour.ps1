<#
.SYNOPSIS
    Gives a VS Code folder its own background colour, a matching recoloured VS Code icon,
    and a shortcut that opens the folder in VS Code.

.DESCRIPTION
    1. Builds a palette from one colour (the editor background): the navy template below moved
       to the new hue, plus every grey in the active theme and VS Code's built-in defaults.
    2. Writes it into <folder>\.vscode\settings.json under "workbench.colorCustomizations".
       Only that block is replaced; the rest of the file (including comments) is kept.
    3. Recolours VS Code's own code.ico to the same hue, keeping the logo's brightness and gradients.
    4. Creates <folder>\<folder name>.lnk, which runs cmd /c "code "<folder>"" with that icon.

    Without -Path it works on the git repo you're in (or the current directory if it isn't a repo).
    Leave out the colour to reuse the folder's current one, or to pick one from a dialog if it has none.
    See README.md for every option.

.EXAMPLE
    VSColour.ps1 '#3A1B2B'
    VSColour.ps1 -ShortcutOnly -Desktop
    VSColour.ps1 -Path C:\Repos\Api -Colour '#192B1B' -Name 'API' -Hotkey 'Ctrl+Alt+A' -StartMenu
    VSColour.ps1 -Pick
    VSColour.ps1 -InstallLauncher      # puts a "VS Colour" shortcut on the desktop that runs this script -Pick
#>
[CmdletBinding(DefaultParameterSetName = 'Apply')]
param(
    [Parameter(ParameterSetName = 'Apply', Position = 0)] [string] $Colour,
    [Parameter(ParameterSetName = 'Apply')] [string] $Path,
    [Parameter(ParameterSetName = 'Apply')] [switch] $Pick,
    [Parameter(ParameterSetName = 'Apply')] [string] $Name,
    [Parameter(ParameterSetName = 'Apply')] [string] $Hotkey,
    [Parameter(ParameterSetName = 'Apply')] [switch] $StartMenu,
    [Parameter(ParameterSetName = 'Apply')] [switch] $Desktop,
    [Parameter(ParameterSetName = 'Apply')] [switch] $NoShortcut,
    [Parameter(ParameterSetName = 'Apply')] [switch] $ShortcutOnly,
    # Lightness added to every icon pixel, -1..1. Negative is darker than the original logo.
    [Parameter(ParameterSetName = 'Apply')] [double] $IconShade = -0.1,
    # .ico to recolour instead of the one in the VS Code install.
    [Parameter(ParameterSetName = 'Apply')] [string] $Icon,
    [Parameter(ParameterSetName = 'Install')] [switch] $InstallLauncher
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms, Microsoft.VisualBasic

# VS Code's install folder: the user install, the system install, or wherever `code` on PATH lives.
$codeOnPath = Get-Command code.cmd -ErrorAction SilentlyContinue
$CodeDir = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code'),
    (Join-Path $env:ProgramFiles 'Microsoft VS Code'),
    $(if ($codeOnPath) { Split-Path (Split-Path $codeOnPath.Source) })
) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'Code.exe')) } | Select-Object -First 1
if (-not $CodeDir) { $CodeDir = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code' }
$CodeExe  = Join-Path $CodeDir 'Code.exe'
$IconDir  = Join-Path $env:LOCALAPPDATA 'VSColour\icons'
$DesktopDir = [Environment]::GetFolderPath('Desktop')
$Programs = [Environment]::GetFolderPath('Programs')

# Palette template. Every entry is re-hued relative to $TemplateBase (editor.background).
$TemplateBase = '#17233A'
$Template = [ordered]@{
    'editor.background'                     = '#17233A'
    'sideBar.background'                    = '#101A2D'
    'activityBar.background'                = '#0A1220'
    'statusBar.background'                  = '#172B4A'
    'panel.background'                      = '#121E33'
    'terminal.background'                   = '#0C1729'
    'titleBar.activeBackground'             = '#101C31'
    'titleBar.inactiveBackground'           = '#0A1220'

    'editorGroupHeader.tabsBackground'      = '#101A2D'
    'editorGroupHeader.noTabsBackground'    = '#101A2D'
    'tab.activeBackground'                  = '#17233A'
    'tab.unfocusedActiveBackground'         = '#17233A'
    'tab.inactiveBackground'                = '#101A2D'
    'tab.unfocusedInactiveBackground'       = '#101A2D'
    'tab.hoverBackground'                   = '#1B283F'
    'tab.unfocusedHoverBackground'          = '#141F35'
    'breadcrumb.background'                 = '#17233A'
    'breadcrumbPicker.background'           = '#121E33'

    'editorPane.background'                 = '#17233A'
    'editorGroup.emptyBackground'           = '#17233A'
    'editorGutter.background'               = '#17233A'
    'minimap.background'                    = '#17233A'
    'editorStickyScroll.background'         = '#17233A'
    'editor.lineHighlightBackground'        = '#1E2B43'
    'welcomePage.background'                = '#17233A'

    'editorWidget.background'               = '#121E33'
    'editorSuggestWidget.background'        = '#121E33'
    'editorHoverWidget.background'          = '#121E33'
    'editorHoverWidget.statusBarBackground' = '#101A2D'
    'editorMarkerNavigation.background'     = '#121E33'
    'peekViewEditor.background'             = '#121E33'
    'peekViewEditorGutter.background'       = '#121E33'
    'peekViewResult.background'             = '#101A2D'
    'peekViewTitle.background'              = '#101A2D'
    'debugToolBar.background'               = '#121E33'

    'sideBarTitle.background'               = '#101A2D'
    'sideBarSectionHeader.background'       = '#101A2D'
    'sideBarStickyScroll.background'        = '#101A2D'
    'panelSectionHeader.background'         = '#121E33'
    'panelStickyScroll.background'          = '#121E33'

    'list.hoverBackground'                  = '#1B283F'
    'list.activeSelectionBackground'        = '#234068'
    'list.inactiveSelectionBackground'      = '#1D3354'
    'list.focusBackground'                  = '#1D3354'
    'list.dropBackground'                   = '#1D3354'

    'input.background'                      = '#0D1627'
    'dropdown.background'                   = '#0D1627'
    'dropdown.listBackground'               = '#121E33'
    'checkbox.background'                   = '#0D1627'
    'settings.textInputBackground'          = '#0D1627'
    'settings.numberInputBackground'        = '#0D1627'
    'settings.dropdownBackground'           = '#0D1627'
    'settings.checkboxBackground'           = '#0D1627'
    'keybindingLabel.background'            = '#172B4A'
    'button.secondaryBackground'            = '#1D3354'

    'commandCenter.background'              = '#17233A'
    'commandCenter.activeBackground'        = '#172B4A'
    'menu.background'                       = '#121E33'
    'menu.selectionBackground'              = '#234068'
    'menubar.selectionBackground'           = '#172B4A'

    'quickInput.background'                 = '#121E33'
    'quickInputTitle.background'            = '#101A2D'

    'notifications.background'              = '#121E33'
    'notificationCenterHeader.background'   = '#101A2D'
    'banner.background'                     = '#172B4A'

    'statusBar.noFolderBackground'          = '#172B4A'
    'statusBarItem.remoteBackground'        = '#234068'
    'statusBarItem.hoverBackground'         = '#234068'

    'textCodeBlock.background'              = '#0D1627'
    'textBlockQuote.background'             = '#121E33'
}

# ---------------------------------------------------------------- colour maths

function ConvertTo-Hsl([string] $Hex) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    $r = $c.R / 255; $g = $c.G / 255; $b = $c.B / 255
    $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b))
    $l = ($max + $min) / 2
    if ($max -eq $min) { return @(0.0, 0.0, $l) }
    $d = $max - $min
    $s = if ($l -gt 0.5) { $d / (2 - $max - $min) } else { $d / ($max + $min) }
    $h = if ($max -eq $r) { (($g - $b) / $d) % 6 } elseif ($max -eq $g) { ($b - $r) / $d + 2 } else { ($r - $g) / $d + 4 }
    @(((($h * 60) + 360) % 360), $s, $l)
}

function ConvertFrom-Hsl([double] $H, [double] $S, [double] $L) {
    $S = [Math]::Min(1.0, [Math]::Max(0.0, $S)); $L = [Math]::Min(1.0, [Math]::Max(0.0, $L)); $H = (($H % 360) + 360) % 360
    $c = (1 - [Math]::Abs(2 * $L - 1)) * $S
    $x = $c * (1 - [Math]::Abs((($H / 60) % 2) - 1))
    $m = $L - $c / 2
    $rgb = switch ([Math]::Floor($H / 60)) {
        0 { $c, $x, 0 } 1 { $x, $c, 0 } 2 { 0, $c, $x } 3 { 0, $x, $c } 4 { $x, 0, $c } default { $c, 0, $x }
    }
    '#' + (($rgb | ForEach-Object { '{0:X2}' -f [int][Math]::Round(($_ + $m) * 255) }) -join '')
}

# Re-hues a grey theme colour. Dark greys (backgrounds, borders) move with the editor background;
# light greys (text, icons, scrollbars) keep their lightness and get a light tint.
# Returns $null for colours that already have a hue (accents, errors, git colours), which are left alone.
function Get-TintedColour([string] $Hex, [double] $ThemeBgL, $New) {
    $v = $Hex.TrimStart('#')
    if ($v.Length -in 3, 4) { $v = -join ($v.ToCharArray() | ForEach-Object { "$_$_" }) }
    if ($v.Length -notin 6, 8 -or $v -notmatch '^[0-9A-Fa-f]+$') { return $null }
    $alpha = $v.Substring(6)
    $hsl = ConvertTo-Hsl ('#' + $v.Substring(0, 6))
    if ($hsl[1] -ge 0.2) { return $null }
    if ($hsl[2] -lt 0.3) {
        $out = ConvertFrom-Hsl $New[0] $New[1] ($hsl[2] - $ThemeBgL + $New[2])
    } else {
        # Cap at 0.9 so pure white (activity bar icons etc.) still takes the tint.
        $out = ConvertFrom-Hsl $New[0] ([Math]::Min(0.3, $New[1] * 0.6)) ([Math]::Min(0.9, $hsl[2]))
    }
    $out + $alpha.ToUpper()
}

function Get-Palette([string] $Colour, $ThemeColours) {
    $base = ConvertTo-Hsl $TemplateBase
    $new  = ConvertTo-Hsl $Colour
    $satScale = if ($base[1] -gt 0) { $new[1] / $base[1] } else { 1 }
    $palette = [ordered]@{}
    foreach ($key in $Template.Keys) {
        $t = ConvertTo-Hsl $Template[$key]
        $palette[$key] = ConvertFrom-Hsl ($t[0] - $base[0] + $new[0]) ($t[1] * $satScale) ($t[2] - $base[2] + $new[2])
    }

    # Everything else the theme colours grey: borders, scrollbars, icons, text.
    $bg = if ($ThemeColours.Contains('editor.background')) { $ThemeColours['editor.background'] } else { '#1F1F1F' }
    $themeBgL = (ConvertTo-Hsl ('#' + $bg.TrimStart('#').Substring(0, 6)))[2]
    foreach ($key in ($ThemeColours.Keys | Sort-Object)) {
        if ($palette.Contains($key)) { continue }
        $tinted = Get-TintedColour $ThemeColours[$key] $themeBgL $new
        if ($tinted) { $palette[$key] = $tinted }
    }
    $palette
}

# ---------------------------------------------------------------- theme lookup

# Reads VS Code's built-in dark default for every colour id that has a literal one, straight from
# the workbench bundle (e.g. se("foreground",{dark:"#CCCCCC",...})). Defaults that point at another
# colour aren't needed: VS Code resolves those at runtime from the colours we set.
function Get-DefaultColours {
    $bundle = Get-ChildItem (Join-Path $CodeDir '*\resources\app\out\vs\workbench\workbench.desktop.main.js'), (Join-Path $CodeDir 'resources\app\out\vs\workbench\workbench.desktop.main.js') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $colours = [ordered]@{}
    if (-not $bundle) { Write-Warning "Couldn't find VS Code's workbench bundle; built-in default colours won't be tinted."; return $colours }
    $hex = '#[0-9A-Fa-f]{3,8}'
    $pattern = '[\w$]+\("([a-zA-Z][\w-]*(?:\.[\w-]+)*)",\{[^{}]*?\bdark:(?:"(' + $hex + ')"|[\w$]+\.fromHex\("(' + $hex + ')"\)(?:\.transparent\(([\d.]+)\))?|[\w$]+\.(white|black)\b)'
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($bundle.FullName), $pattern)) {
        $id = $m.Groups[1].Value
        if ($colours.Contains($id)) { continue }
        $value = if ($m.Groups[2].Success) { $m.Groups[2].Value }
                 elseif ($m.Groups[3].Success) {
                     $v = $m.Groups[3].Value
                     if ($m.Groups[4].Success) { $v += '{0:X2}' -f [int][Math]::Round([double]$m.Groups[4].Value * 255) }
                     $v
                 }
                 elseif ($m.Groups[5].Value -eq 'white') { '#FFFFFF' } else { '#000000' }
        $colours[$id] = $value
    }
    $colours
}

# Colours whose VS Code default is derived from another colour (or unset) but that still show up grey.
$DefaultColours = [ordered]@{
    'scrollbar.shadow'                   = '#000000'
    'scrollbarSlider.background'         = '#79797966'
    'scrollbarSlider.hoverBackground'    = '#646464B3'
    'scrollbarSlider.activeBackground'   = '#BFBFBF66'
    'editorOverviewRuler.border'         = '#7F7F7F4D'
    'editorIndentGuide.background1'      = '#404040'
    'editorIndentGuide.activeBackground1'= '#707070'
    'editorRuler.foreground'             = '#5A5A5A'
    'editorWhitespace.foreground'        = '#E3E4E229'
    'editorLineNumber.foreground'        = '#858585'
    'editorLineNumber.activeForeground'  = '#C6C6C6'
    'tree.indentGuidesStroke'            = '#585858'
    'minimapSlider.background'           = '#79797933'
    'minimapSlider.hoverBackground'      = '#64646459'
    'minimapSlider.activeBackground'     = '#BFBFBF33'
    'widget.border'                      = '#303031'
    'sash.hoverBorder'                   = '#454545'
    'editorGroup.border'                 = '#444444'
    'tab.border'                         = '#252526'
    'panel.border'                       = '#80808059'
    'menu.separatorBackground'           = '#454545'
    'icon.foreground'                    = '#C5C5C5'
    'activityBar.inactiveForeground'     = '#FFFFFF66'
    'activityBar.foreground'             = '#FFFFFF'
    'toolbar.hoverBackground'            = '#5A5D5E50'
    'sideBar.border'                     = '#2B2B2B'
    'activityBar.border'                 = '#2B2B2B'
    'statusBar.border'                   = '#2B2B2B'
    'titleBar.border'                    = '#2B2B2B'
    'button.secondaryBackground'         = '#3A3D41'
    'button.secondaryHoverBackground'    = '#45494E'
    'window.activeBorder'                = '#3C3C3C'   # only drawn with the custom title bar
    'window.inactiveBorder'              = '#2B2B2B'
}

function ConvertFrom-Jsonc([string] $Text) {
    $Text = [regex]::Replace($Text, '("(?:\\.|[^"\\])*")|//[^\n]*|/\*[\s\S]*?\*/', '$1')
    $Text = [regex]::Replace($Text, '("(?:\\.|[^"\\])*")|,(\s*[}\]])', '$1$2')
    $Text | ConvertFrom-Json
}

function Get-ThemeName([string] $Folder) {
    foreach ($file in (Join-Path $Folder '.vscode\settings.json'), (Join-Path $env:APPDATA 'Code\User\settings.json')) {
        if (-not (Test-Path $file)) { continue }
        $m = [regex]::Match([IO.File]::ReadAllText($file), '"workbench\.colorTheme"\s*:\s*"([^"]+)"')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    'Dark 2026'   # VS Code's default
}

function Read-ThemeColours([string] $File, $Into) {
    $theme = ConvertFrom-Jsonc ([IO.File]::ReadAllText($File))
    if ($theme.PSObject.Properties['include']) {
        Read-ThemeColours (Join-Path (Split-Path $File) $theme.include) $Into
    }
    if ($theme.PSObject.Properties['colors']) {
        foreach ($p in $theme.colors.PSObject.Properties) { if ($p.Value -is [string]) { $Into[$p.Name] = $p.Value } }
    }
}

function Get-ThemeColours([string] $ThemeName) {
    $colours = Get-DefaultColours
    foreach ($k in $DefaultColours.Keys) { $colours[$k] = $DefaultColours[$k] }

    $builtIn = Get-ChildItem (Join-Path $CodeDir '*\resources\app\extensions'), (Join-Path $CodeDir 'resources\app\extensions') -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $dirs = @($builtIn.FullName, (Join-Path $env:USERPROFILE '.vscode\extensions')) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($pkg in (Get-ChildItem $dirs -Filter package.json -Depth 1 -ErrorAction SilentlyContinue)) {
        $raw = [IO.File]::ReadAllText($pkg.FullName)
        if ($raw -notmatch '"themes"' -or $raw -notmatch [regex]::Escape($ThemeName)) { continue }
        try { $json = $raw | ConvertFrom-Json } catch { continue }
        if (-not $json.PSObject.Properties['contributes'] -or -not $json.contributes.PSObject.Properties['themes']) { continue }
        foreach ($t in $json.contributes.themes) {
            $id = if ($t.PSObject.Properties['id']) { $t.id } else { $t.label }
            if (($id -eq $ThemeName -or $t.label -eq $ThemeName) -and $t.path -like '*.json') {
                Read-ThemeColours (Join-Path $pkg.DirectoryName $t.path) $colours
                return $colours
            }
        }
    }
    Write-Warning "Couldn't find theme '$ThemeName'; only VS Code's default greys will be tinted."
    $colours
}

# ---------------------------------------------------------------- settings.json

# Returns the index just past the value that starts at $Start ('{' ... '}'), skipping strings and comments.
function Find-ObjectEnd([string] $Text, [int] $Start) {
    $depth = 0; $i = $Start
    while ($i -lt $Text.Length) {
        $ch = $Text[$i]
        if ($ch -eq '"') {
            $i++
            while ($Text[$i] -ne '"') { if ($Text[$i] -eq '\') { $i++ }; $i++ }
        } elseif ($ch -eq '/' -and $Text[$i + 1] -eq '/') {
            $i = $Text.IndexOf("`n", $i); if ($i -lt 0) { $i = $Text.Length }
        } elseif ($ch -eq '/' -and $Text[$i + 1] -eq '*') {
            $i = $Text.IndexOf('*/', $i + 2) + 1
        } elseif ($ch -eq '{') {
            $depth++
        } elseif ($ch -eq '}') {
            $depth--; if ($depth -eq 0) { return $i + 1 }
        }
        $i++
    }
    throw 'Unbalanced braces in settings.json'
}

function Set-WorkspaceColours([string] $Folder, $Palette) {
    $dir  = Join-Path $Folder '.vscode'
    $file = Join-Path $dir 'settings.json'
    $body = ($Palette.Keys | ForEach-Object { '        "{0}": "{1}"' -f $_, $Palette[$_] }) -join ",`r`n"
    $block = "{`r`n$body`r`n    }"

    $text = if (Test-Path $file) { [IO.File]::ReadAllText($file) } else { '' }
    if ($text.Trim() -eq '') {
        $text = "{`r`n    `"workbench.colorCustomizations`": $block`r`n}`r`n"
    } else {
        $m = [regex]::Match($text, '"workbench\.colorCustomizations"\s*:\s*\{')
        if ($m.Success) {
            $open = $m.Index + $m.Length - 1
            $text = $text.Substring(0, $open) + $block + $text.Substring((Find-ObjectEnd $text $open))
        } else {
            $open = $text.IndexOf('{')
            if ($open -lt 0) { throw "$file is not a JSON object" }
            $rest = $text.Substring($open + 1)
            $sep  = if ($rest.Trim() -eq '}') { '' } else { ',' }
            $text = $text.Substring(0, $open + 1) + "`r`n    `"workbench.colorCustomizations`": $block$sep" + $rest
        }
    }
    New-Item -ItemType Directory -Force $dir | Out-Null
    [IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding $false))
    $file
}

# ---------------------------------------------------------------- icon

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class VSColourIcon
{
    // Recolours an .ico so its average hue becomes h, keeping each pixel's brightness and its hue offset
    // from that average so the gradients survive. satScale scales saturation (1 = as vivid as the original).
    // Returns a new .ico with every frame stored as PNG.
    public static byte[] Recolour(byte[] ico, double h, double satScale, double lightShift)
    {
        int count = BitConverter.ToUInt16(ico, 4);
        var bitmaps = new List<Bitmap>();
        for (int i = 0; i < count; i++)
        {
            int e = 6 + 16 * i;
            Bitmap bmp = Decode(ico, BitConverter.ToInt32(ico, e + 12), BitConverter.ToInt32(ico, e + 8));
            if (bmp != null) bitmaps.Add(bmp);
        }
        Bitmap largest = bitmaps[0];
        foreach (var b in bitmaps) if (b.Width > largest.Width) largest = b;
        double[] refHsl = Average(largest);

        var frames = new List<KeyValuePair<int, byte[]>>();
        foreach (var bmp in bitmaps)
            using (bmp)
            {
                Shift(bmp, h - refHsl[0], satScale, lightShift);
                using (var ms = new MemoryStream()) { bmp.Save(ms, ImageFormat.Png); frames.Add(new KeyValuePair<int, byte[]>(bmp.Width, ms.ToArray())); }
            }
        using (var ms = new MemoryStream())
        using (var w = new BinaryWriter(ms))
        {
            w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)frames.Count);
            int offset = 6 + 16 * frames.Count;
            foreach (var f in frames)
            {
                w.Write((byte)(f.Key >= 256 ? 0 : f.Key)); w.Write((byte)(f.Key >= 256 ? 0 : f.Key));
                w.Write((byte)0); w.Write((byte)0); w.Write((ushort)1); w.Write((ushort)32);
                w.Write(f.Value.Length); w.Write(offset); offset += f.Value.Length;
            }
            foreach (var f in frames) w.Write(f.Value);
            return ms.ToArray();
        }
    }

    static Bitmap Decode(byte[] ico, int offset, int size)
    {
        if (ico[offset] == 0x89) // PNG frame
            using (var ms = new MemoryStream(ico, offset, size))
            using (var png = new Bitmap(ms))
                return new Bitmap(png);

        int w = BitConverter.ToInt32(ico, offset + 4), h = BitConverter.ToInt32(ico, offset + 8) / 2;
        int headerSize = BitConverter.ToInt32(ico, offset), bpp = BitConverter.ToUInt16(ico, offset + 14);
        if (bpp != 32) return null;
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        for (int y = 0; y < h; y++) // DIB rows are bottom-up
            Marshal.Copy(ico, offset + headerSize + (h - 1 - y) * w * 4, data.Scan0 + y * data.Stride, w * 4);
        bmp.UnlockBits(data);
        return bmp;
    }

    static byte[] Pixels(Bitmap bmp, out BitmapData data)
    {
        data = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var px = new byte[data.Stride * bmp.Height];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        return px;
    }

    // HSL of pixel i, or null for transparent and grey/white pixels (which are left alone).
    static double[] Hsl(byte[] px, int i)
    {
        if (px[i + 3] == 0) return null;
        double r = px[i + 2] / 255.0, g = px[i + 1] / 255.0, b = px[i] / 255.0;
        double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b)), l = (max + min) / 2, d = max - min;
        if (d < 0.05) return null;
        double s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        double h = max == r ? ((g - b) / d) % 6 : max == g ? (b - r) / d + 2 : (r - g) / d + 4;
        return new[] { (h * 60 + 360) % 360, s, l };
    }

    // Alpha-weighted average colour of the coloured pixels (hue averaged on the circle).
    static double[] Average(Bitmap bmp)
    {
        BitmapData data;
        var px = Pixels(bmp, out data);
        bmp.UnlockBits(data);
        double x = 0, y = 0, s = 0, l = 0, w = 0;
        for (int i = 0; i < px.Length; i += 4)
        {
            var c = Hsl(px, i);
            if (c == null) continue;
            double a = px[i + 3] / 255.0, rad = c[0] * Math.PI / 180;
            x += Math.Cos(rad) * a; y += Math.Sin(rad) * a; s += c[1] * a; l += c[2] * a; w += a;
        }
        return new[] { (Math.Atan2(y, x) * 180 / Math.PI + 360) % 360, s / w, l / w };
    }

    static void Shift(Bitmap bmp, double hueShift, double satScale, double lightShift)
    {
        BitmapData data;
        var px = Pixels(bmp, out data);
        for (int i = 0; i < px.Length; i += 4)
        {
            var hsl = Hsl(px, i);
            if (hsl == null) continue;
            double h = ((hsl[0] + hueShift) % 360 + 360) % 360;
            double s = Math.Max(0, Math.Min(1, hsl[1] * satScale));
            double l = Math.Max(0, Math.Min(1, hsl[2] + lightShift));
            double c = (1 - Math.Abs(2 * l - 1)) * s, x = c * (1 - Math.Abs((h / 60) % 2 - 1)), m = l - c / 2;
            double[] rgb;
            switch ((int)(h / 60)) { case 0: rgb = new[] { c, x, 0.0 }; break; case 1: rgb = new[] { x, c, 0.0 }; break; case 2: rgb = new[] { 0.0, c, x }; break;
                                     case 3: rgb = new[] { 0.0, x, c }; break; case 4: rgb = new[] { x, 0.0, c }; break; default: rgb = new[] { c, 0.0, x }; break; }
            px[i + 2] = (byte)Math.Round((rgb[0] + m) * 255); px[i + 1] = (byte)Math.Round((rgb[1] + m) * 255); px[i] = (byte)Math.Round((rgb[2] + m) * 255);
        }
        Marshal.Copy(px, 0, data.Scan0, px.Length);
        bmp.UnlockBits(data);
    }
}
'@

# The .ico to recolour: -Icon if given, else the one VS Code ships, else (with -Pick) one chosen in a dialog.
function Find-SourceIcon {
    if ($Icon) {
        if (-not (Test-Path $Icon -PathType Leaf)) { throw "-Icon file not found: $Icon" }
        $src = (Resolve-Path $Icon).Path
    } else {
        # Newer VS Code versions keep it under a per-build folder (<install>\<build id>\resources\...), older ones
        # directly under <install>\resources. Right after an update both builds can exist; take the newest.
        $src = Get-ChildItem (Join-Path $CodeDir '*\resources\app\resources\win32\code.ico'), (Join-Path $CodeDir 'resources\app\resources\win32\code.ico') -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $src -and $Pick) {
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = "Couldn't find VS Code's icon - choose an .ico to recolour"
        $dlg.Filter = 'Icons (*.ico)|*.ico'
        if ($dlg.ShowDialog() -eq 'OK') { $src = $dlg.FileName }
    }
    if (-not $src) { throw "Couldn't find VS Code's code.ico under $CodeDir. Point to an icon with -Icon <path to .ico>." }

    $bytes = [IO.File]::ReadAllBytes($src)
    if ($bytes.Length -lt 6 -or $bytes[0] -ne 0 -or $bytes[1] -ne 0 -or $bytes[2] -ne 1 -or $bytes[3] -ne 0) {
        throw "$src isn't an .ico file"
    }
    $bytes
}

function New-ColouredIcon([string] $Colour, [string] $Name) {
    $source = Find-SourceIcon

    $new = ConvertTo-Hsl $Colour
    # Take only the hue from the chosen colour and keep the logo bright. Near-grey colours give a
    # correspondingly grey logo; anything with real colour gets the logo's full vividness.
    $satScale = [Math]::Min(1.0, [double]$new[1] / 0.25)
    $bytes = [VSColourIcon]::Recolour($source,$new[0], $satScale, $IconShade)

    # The colour goes in the file name: Windows caches icons by path, so reusing a path shows the old colour.
    New-Item -ItemType Directory -Force $IconDir | Out-Null
    $safe = $Name -replace '[\\/:*?"<>|]', '_'
    Get-ChildItem $IconDir -Filter "$safe*.ico" | Where-Object { $_.BaseName -match "^$([regex]::Escape($safe))(-[0-9A-F]{6}(-[0-9a-f]{8})?)?$" } | Remove-Item
    $hash = -join ([Security.Cryptography.MD5]::Create().ComputeHash($bytes)[0..3] | ForEach-Object { '{0:x2}' -f $_ })
    $out = Join-Path $IconDir ("$safe-" + $Colour.TrimStart('#').ToUpper() + "-$hash.ico")
    [IO.File]::WriteAllBytes($out, $bytes)
    $out
}

# Tells Explorer to reload icons so the shortcut shows its new colour straight away.
function Update-ShellIcons {
    Add-Type -Namespace VSColour -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);'
    [VSColour.Shell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)   # SHCNE_ASSOCCHANGED
}

# The editor background already written to <folder>\.vscode\settings.json, if any.
function Get-CurrentColour([string] $Folder) {
    $file = Join-Path $Folder '.vscode\settings.json'
    if (-not (Test-Path $file)) { return $null }
    $m = [regex]::Match([IO.File]::ReadAllText($file), '"workbench\.colorCustomizations"\s*:\s*\{[^}]*?"editor\.background"\s*:\s*"(#[0-9A-Fa-f]{6})')
    if ($m.Success) { $m.Groups[1].Value } else { $null }
}

# ---------------------------------------------------------------- shortcuts

function New-Shortcut([string] $LinkPath, [string] $Target, [string] $Arguments, [string] $Icon, [string] $WorkDir, [string] $Key, [int] $WindowStyle = 1) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($LinkPath)
    $s.TargetPath = $Target
    $s.Arguments = $Arguments
    $s.WorkingDirectory = $WorkDir
    $s.IconLocation = "$Icon,0"
    $s.WindowStyle = $WindowStyle
    if ($Key) { $s.Hotkey = $Key }
    $s.Save()
    $LinkPath
}

if ($InstallLauncher) {
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $link = New-Shortcut (Join-Path $DesktopDir 'VS Colour.lnk') $ps "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Pick" `
        "$CodeExe" $PSScriptRoot ''
    Write-Host "Launcher created: $link"
    return
}

# ---------------------------------------------------------------- main

$interactive = [bool]$Pick
try {
    if (-not (Test-Path $CodeExe)) { throw "VS Code not found at $CodeExe" }

    if ($Pick) {
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Pick the folder to colour'
        if ($dlg.ShowDialog() -ne 'OK') { return }
        $Path = $dlg.SelectedPath
    } elseif (-not $Path) {
        # Root of the git repo we're in, so running from a subfolder still colours the whole repo.
        $Path = (Get-Location).ProviderPath
        $root = cmd /c "git -C `"$Path`" rev-parse --show-toplevel 2>nul"
        if ($LASTEXITCODE -eq 0 -and $root) { $Path = $root -replace '/', '\' }
    }
    $Path = (Resolve-Path $Path).Path.TrimEnd('\')

    # No colour given: reuse the folder's current one, and only ask when there isn't one (or with -Pick).
    $current = Get-CurrentColour $Path
    if (-not $Colour -and $current -and -not $Pick) { $Colour = $current }
    if (-not $Colour) {
        if ($ShortcutOnly) { throw "$Path has no colour yet; give one, e.g. vscolour '#183111'" }
        $cd = New-Object System.Windows.Forms.ColorDialog
        $cd.FullOpen = $true
        $cd.Color = [System.Drawing.ColorTranslator]::FromHtml($(if ($current) { $current } else { $TemplateBase }))
        if ($cd.ShowDialog() -ne 'OK') { return }
        $Colour = '#{0:X2}{1:X2}{2:X2}' -f $cd.Color.R, $cd.Color.G, $cd.Color.B
    }
    if ($Colour -notmatch '^#?[0-9A-Fa-f]{6}$') { throw "Colour must look like #17233A, got '$Colour'" }
    if (-not $Colour.StartsWith('#')) { $Colour = "#$Colour" }

    if (-not $Name) {
        $Name = Split-Path $Path -Leaf
        if ($interactive) {
            $Name = [Microsoft.VisualBasic.Interaction]::InputBox('Shortcut name:', 'VS Colour', $Name)
            if (-not $Name) { return }
        }
    }

    $done = @()
    if (-not $ShortcutOnly) {
        $themeName = Get-ThemeName $Path
        $palette = Get-Palette $Colour (Get-ThemeColours $themeName)
        $settings = Set-WorkspaceColours $Path $palette
        $done += "Colours ($Colour, $($palette.Count) keys over '$themeName') -> $settings"
    }

    if (-not $NoShortcut) {
        $icon = New-ColouredIcon $Colour $Name
        $done += "Icon -> $icon"
        # Always in the repo itself (move it wherever you like); -Desktop / -StartMenu add copies there.
        $targets = @($Path)
        if ($Desktop) { $targets += $DesktopDir }
        if ($StartMenu) { $targets += $Programs }
        # Only one shortcut can own a hotkey, and Windows only honours it on the desktop or in the Start Menu,
        # so it goes to the first of those copies (or the repo copy, for when you move it there yourself).
        $hotkeyDir = if ($targets.Count -gt 1) { $targets[1] } else { $targets[0] }
        foreach ($dir in $targets) {
            $key = if ($dir -eq $hotkeyDir) { $Hotkey } else { '' }
            # cmd /c "code "<repo>"", started minimised so the console barely flashes.
            $cmd = Join-Path $env:SystemRoot 'System32\cmd.exe'
            $done += 'Shortcut -> ' + (New-Shortcut (Join-Path $dir "$Name.lnk") $cmd "/c `"code `"$Path`"`"" $icon $Path $key 7)
        }
        Update-ShellIcons
    }

    $done | ForEach-Object { Write-Host $_ }
    if ($interactive) { [System.Windows.Forms.MessageBox]::Show(($done -join "`n"), 'VS Colour') | Out-Null }
} catch {
    if ($interactive) { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'VS Colour', 'OK', 'Error') | Out-Null }
    throw
}
