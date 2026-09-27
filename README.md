<p align="center">
  <img src="assets/rainbow.png" alt="The VS Code icon recoloured in eight rainbow hues" width="100%">
</p>

<h1 align="center">VS Colour</h1>

<p align="center">Give every repo its own VS Code colour, so you can tell windows apart at a glance.</p>

Pick one colour and VS Colour will:

- **Recolour the whole VS Code window** for that repo: backgrounds, borders, scrollbars, icons and text, not just the title and status bars.
- **Make a matching VS Code icon** from the one in your VS Code install, with the blue swapped for your colour. The icon keeps the logo's shading.
- **Create a shortcut** (`<repo name>.lnk`) that opens the repo in VS Code with that icon.

The colours are stored in the repo's `.vscode/settings.json`, so they only affect that repo and every other VS Code window is unchanged.

## Requirements

- Windows 10 or 11
- VS Code, either the user or system installer, with `code` on your `PATH` (both installers add it by default)
- Windows PowerShell 5.1 (comes with Windows)

## Setup

1. Clone or download this repository to somewhere permanent, e.g. `C:\Tools\vscolour`.
2. Add that folder to your `PATH` so that `vscolour` works in any terminal:
   - **Windows:** Start → *Edit environment variables for your account* → `Path` → *New* → the folder path. Then open a new terminal.
   - **Git Bash only:** add `export PATH="$PATH:/c/Tools/vscolour"` to `~/.bashrc`.
3. Optional: create a desktop launcher that lets you pick the folder and colour from dialogs:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Tools\vscolour\VSColour.ps1 -InstallLauncher
   ```

## Usage

Open a terminal inside the repo (any subfolder works) and run:

```bash
vscolour '#183111'
```

This:

1. writes the colours to `<repo>\.vscode\settings.json`,
2. saves the recoloured icon to `%LOCALAPPDATA%\VSColour\icons\`, and
3. creates `<repo>\<repo name>.lnk`.

Move the `.lnk` wherever you like, e.g. the desktop, the Start Menu, or pinned to the taskbar. It keeps working after you move it.

> The colour you give is the **editor background**, so choose a dark one. `#17233A` (navy), `#183111` (green) and `#3A1B2B` (plum) are good starting points.

### Common tasks

| Task | Command |
|---|---|
| Colour the current repo | `vscolour '#183111'` |
| Choose the colour from a colour picker | `vscolour` (in a repo that has no colour yet) |
| Re-apply after changing theme or updating VS Code | `vscolour` (reuses the repo's current colour) |
| Only remake the shortcut and icon | `vscolour -ShortcutOnly` |
| Only change the colours, no shortcut | `vscolour '#183111' -NoShortcut` |
| Also put the shortcut on the desktop / Start Menu | `vscolour -Desktop -StartMenu` |
| Colour a different folder | `vscolour '#183111' -Path C:\Repos\Api` |
| Pick the folder and colour from dialogs | `vscolour -Pick` (or double-click the **VS Colour** launcher) |

### Options

| Option | Description |
|---|---|
| `<colour>` / `-Colour` | Editor background as `#RRGGBB`. If you leave it out, the repo's current colour is used; if the repo has none, a colour picker opens. |
| `-Path <folder>` | Folder to colour. Defaults to the root of the git repo you're in, or the current folder if it isn't a repo. |
| `-Pick` | Choose the folder, colour and shortcut name from dialogs. |
| `-Name <text>` | Shortcut name. Defaults to the folder name. |
| `-ShortcutOnly` | Make the icon and shortcut without changing `settings.json`. |
| `-NoShortcut` | Change the colours only. |
| `-Desktop` | Also put a copy of the shortcut on the desktop. |
| `-StartMenu` | Also put a copy of the shortcut in the Start Menu. |
| `-Hotkey <keys>` | Keyboard shortcut that opens the repo, e.g. `Ctrl+Alt+A`. Windows only honours hotkeys on shortcuts in the desktop or Start Menu, so combine it with `-Desktop` or `-StartMenu`, or move the `.lnk` there yourself. |
| `-Icon <path>` | `.ico` file to recolour instead of VS Code's own icon. See [Using a different icon](#using-a-different-icon). |
| `-IconShade <n>` | Brightness of the icon, from `-1` to `1`. `0` matches the original logo; the default `-0.1` is slightly darker. |
| `-InstallLauncher` | Create the **VS Colour** desktop launcher. |

You can also run the script directly, without the wrappers:

```powershell
powershell -ExecutionPolicy Bypass -File .\VSColour.ps1 '#183111'
```

### Using a different icon

By default the icon comes from your VS Code install. The script looks for it here:

```
<VS Code folder>\<build id>\resources\app\resources\win32\code.ico   (current versions)
<VS Code folder>\resources\app\resources\win32\code.ico              (older versions)
```

`<VS Code folder>` is `%LOCALAPPDATA%\Programs\Microsoft VS Code` for the user installer, or `C:\Program Files\Microsoft VS Code` for the system installer. `<build id>` is a short code such as `04c0d99f4f` that changes with each VS Code update.

To use another icon, for example if VS Code is installed somewhere else, you use VS Code Insiders, or you have your own logo, pass it with `-Icon`:

```bash
vscolour '#183111' -Icon 'D:\Icons\my-logo.ico'
```

The file must be a `.ico`. Its coloured parts are shifted to your colour's hue, and white and grey parts are left as they are.

If the script can't find VS Code's icon and you didn't give `-Icon`, it stops with an error, except in `-Pick` mode (and the desktop launcher), where it asks you to choose an `.ico` file instead.

## How it works

**Window colours.** `VSColour.ps1` contains a hand-tuned navy palette of about 70 background colours. Every shade is moved to your colour's hue, and keeps the same lightness difference from the editor background. The script then finds every grey your current theme uses, plus VS Code's built-in defaults read from its own files, and tints those too. Colours that already have a hue, such as blue buttons, red errors and git colours, are left alone.

Only the `workbench.colorCustomizations` block in `settings.json` is replaced. Your other settings and comments stay as they are.

**Icon.** The script takes the `code.ico` that ships with your VS Code install and replaces its blue with your colour's hue. Each pixel keeps its original brightness, so the logo stays readable even when the background colour is very dark. Each icon file name includes the colour and a content hash, so Windows can't keep showing an older cached icon.

**Shortcut.** The shortcut runs `cmd.exe /c "code "<repo>""`, minimised so no console window flashes up. The *Font*, *Layout* and *Colors* tabs in the shortcut's Properties belong to that brief console window and don't affect VS Code.

## Files

| File | Purpose |
|---|---|
| `VSColour.ps1` | The script |
| `vscolour` | Wrapper for Git Bash |
| `vscolour.cmd` | Wrapper for Command Prompt and PowerShell |
| `assets/rainbow.png` | README banner, made with the script's own icon recolouring |

## Limitations

- **Dark themes:** the palette is built for dark themes. With a light theme, the colours will be too dark to read comfortably.
- **Taskbar:** Windows groups all VS Code windows under one taskbar button, so an open window shows the normal VS Code icon. The coloured icon appears on the shortcut itself and on taskbar pins made from it.
- **Outer window border:** VS Code only draws the border and title bar in your colour when it draws its own title bar. If your user settings contain `"window.customTitleBarVisibility": "never"`, Windows draws them instead.
- **Themes:** the tint is based on the theme that is active when you run the command. After switching theme, run `vscolour` again in each repo.
- **Git:** `.vscode/settings.json` and the `.lnk` are created inside the repo. If you don't want to commit them, add them to the repo's `.gitignore` or `.git/info/exclude`.

## License

[MIT](LICENSE). The Visual Studio Code name and logo are trademarks of Microsoft Corporation. This project is not affiliated with or endorsed by Microsoft.
