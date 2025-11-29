# A Simple Utility to Launch Steam Games from the Terminal on Linux

## Why?

Although Steam provides the ability to launch games via terminal with a command like:
```shell
$ steam steam://rungameid/<appid>
```
This requires you to input the game’s appid each time, which is not very convenient. `steam-launch` simplifies this process by letting you create and manage game aliases and effortlessly launch games by alias.

## Features

- Launch Steam games from terminal by custom aliases.
- Manage and remove aliases.
- Automatically find appids.
- Easily work with any Steam installation.
- Customize Steam launch arguments.
- Manage Steam console output.

## Prerequisites

Before using `steam-launch` make sure you have the following installed on your Linux system:
- Steam
- `coreutils`, `busybox` or alternatives
- `bash`
- `grep`
- `find`
- `jq`
- `curl`
- `awk`
- `sed`

## Note on Steam versions

There are multiple ways you can install Steam on Linux. The most common ones include:
- Official `deb` file from Steam website (for Debian-based distributions)
- Packages provided by first party of third party repositories for your distribution
- Flatpak (from Flathub)
- Snap  
Flatpak and Snap versions are notable for their different behavior. To address this `steam-launch` has configs for default (native), Flatpak and Snap Steam installations that are easy to use. Native Steam installations almost always behave the same (in a way that is relevant to `steam-launch`). This, however, cannot be guaranteed for all installations. If you use a non-standard Steam installation you can still make `steam-launch` work with it by adjusting a few settings.

## Getting Started

### 1. Installation (Optional)

As `steam-launch` is a single bash script, there is technically no need to do any particular installation steps. You can just execute `steam-launch.sh` from wherever it is located on your system. However for the ease of use it is recommended to make it accessible from anywhere as `steam-launch` (or any name you prefer, however all further instructions assume `steam-launch`). One way to achieve that is by creating a symlink in `~/bin`, `~/.local/bin` or any other directory that is added to your PATH.

### 2. Initialize the Configuration Directory (Optional)

Run the following command to initialize the config directory:
```shell
$ steam-launch --init
```
This will create a config directory at `~/.config/steam-launch/` and initialize necessary files there.  
If you're using Flatpak version of Steam use `--flatpak` option:
```shell
$ steam-launch --init --flatpak
```
If you're using Snap version of Steam use `--snap` option:
```shell
$ steam-launch --init --snap
```
If config directory doesn't exist it will be initialized automatically (for default Steam installation) when you create an alias or customize settings. Other `steam-launch` operations won't automatically initialize config directory. This means if you're using default Steam installation (and don't intend to manually edit config files before doing anything else) you can skip this step and just start adding aliases. For flatpak and snap installations however it is recommended to initialize config directory for your installation type. Otherwise you'll have to use `steam-launch --reconf` functionality or manually change certain settings.

### 3. Adding Aliases

There are several ways to add game aliases:
#### a. Manually
You can manually enter appid:
```shell
$ steam-launch --alias -m <alias> <appid>
```
Example:
```shell
$ steam-launch --alias -m rdr2 1174180
```
#### b. Searching Local Files
You can search for the game by its name in Steam local files:
```shell
$ steam-launch --alias -l <game_name> <alias>
```
Example:
```shell
$ steam-launch --alias -l "Red Dead Redemption 2" rdr2
```
If you want the alias to be the exact game name, omit the alias argument:
```shell
$ steam-launch --alias -l <game_name>
```
Example:
```shell
$ steam-launch --alias -l Portal
```
**Note 1:** This works only for installed games or games that have residual appmanifest files on your system.  
**Note 2:** Game name must be exact match (case sensitive).  
#### c. Using the Steam Web API
Alternatively, you can search for the game appid using the Steam Web API:
```shell
$ steam-launch --alias -a <game_name> <alias>
```
Example:
```shell
$ steam-launch --alias -a "Red Dead Redemption 2" rdr2
```
If you want the alias to be the exact game name, omit the alias argument:
```shell
$ steam-launch --alias -a <game_name>
```
Example:
```shell
$ steam-launch --alias -a Portal
```
**Note 1:** An Internet connection is required for this feature.  
**Note 2:** Game name must be exact match (case sensitive).  
**Note 3:** This may not work as expected in rare cases when multiple games on Steam share exactly the same name.  
#### d. Editing the Alias File Directly
You can edit the alias file (`~/.config/steam-launch/alias.json`) directly. Add a new entry to the file where key is alias name and value is game id.
Example:
```json
{
    "rdr2": 1174180,
    "Portal": 400
}
```

### 4. Managing Aliases

- To list current aliases run:
  ```shell
  $ steam-launch --list
  ```
- To update an alias, simply create a new alias with the same name, and it will overwrite the existing one.
- To remove an alias run:
  ```shell
  $ steam-launch --rmalias <alias>
  ```
  Example:
  ```shell
  $ steam-launch --rmalias rdr2
  ```
- You can have multiple aliases for the same game.

### 5. Launching Games

To launch a game, simply use the alias as a single parameter:
```shell
$ steam-launch <alias>
```
Example:
```shell
$ steam-launch rdr2
```

### 6. Customizing Settings

#### a. Steam Installation Compatibility

**Note:** This section is meant for Steam installations that are not compatible with default configs. For Flatpak or Snap installations it is recommended to initialize config directory for you installation type right away as described above.

##### i. Changing the Steam Command

For non-standard Steam installations you may need to update the `steam` command used internally by `steam-launch`:
```shell
$ steam-launch --cfg --steam-command <steam_command>
```
Example:
```shell
$ steam-launch --cfg --steam-command "flatpak run com.valvesoftware.Steam"
```

##### ii. Changing the `steamapps` Directory

Another setting that may need to be adjusted for non-standard Steam installations before adding aliases by searching local files is the default `steamapps` location:
```shell
$ steam-launch --cfg --steamapps-path <steamapps_location>
```
Example:
```shell
$ steam-launch --cfg --steamapps-path ~/snap/steam/common/.steam/steam/steamapps
```

##### iii. Using `xdg-open`

In some cases with non-standard Steam installations running
```shell
$ <steam_command> steam://rungameid/<appid>
```
may work correctly only when Steam is not running.  
To fix this `steam-launch` can use `xdg-open` instead when Steam is running. To enable this run:
```shell
$ steam-launch --cfg --xdg-open true
```
To disable run:
```shell
$ steam-launch --cfg --xdg-open false
```
**Note:** Before using this options make sure `xdg-open` and `pgrep` are installed on your system and `steam://` URLs are correctly recognized by `xdg-open`.

#### b. Adding Steam Launch Arguments

If you typically launch Steam with additional arguments, you can configure `steam-launch` to use them (or you can add arguments specific to `steam-launch`):
```shell
$ steam-launch --cfg --steam-args <your_args>
```
Example:
```shell
$ steam-launch --cfg --steam-args "-forcedesktopscaling=1.5 -silent"
```
#### c. Managing Steam Output

If when you launch a game with `steam-launch` Steam is not running, it will first start Steam and then launch the game. By default `steam-launch` will start Steam in the background and discard its console output by appending `>/dev/null 2>&1 &` to the `steam` command. This behavior can be customized using:
```shell
$ steam-launch --cfg --redirect <redirect>
```
For example if you don't want any redirection (Steam output will be printed to terminal) you can use:
```shell
$ steam-launch --cfg --redirect ""
```
You can use any redirect options, including redirect to file:
```shell
$ steam-launch --cfg --redirect ">>~/steam-launch/output.txt 2>&1 &"
```
If you want to revert the default redirect behavior run:
```shell
$ steam-launch --cfg --redirect ">/dev/null 2>&1 &"
```
Alternatively to revert the default redirect setting you can use:
```shell
$ steam-launch --cfg --background true
```
Or for no redirect use:
```shell
$ steam-launch --cfg --background false
```

#### d. Reconfiguring for Different Steam Installation Type

If you're moving from one Steam installation type to another, or you accidentally initialized config directory for wrong installation type you can easily update relevant setting while keeping all other settings and aliases.  
For default Steam installation run:
```shell
$ steam-launch --reconf
```
For Flatpak installation run:
```shell
$ steam-launch --reconf --flatpak
```
For Snap installation run:
```shell
$ steam-launch --reconf --snap
```

#### e. Resetting Config Directory

You can also reset the config directory. It will erase your config directory and create a new one with default settings. All your aliases and settings will be lost.  
For default Steam installation run:
```shell
$ steam-launch --reset
```
For Flatpak installation run:
```shell
$ steam-launch --reset --flatpak
```
For Snap installation run:
```shell
$ steam-launch --reset --snap
```

### 7. Using test config directory

If you made changes to `steam-launch` and want to test them without affecting you config directory, you can set environment variable `STEAM_LAUNCH_TEST` to use separate config directory at `~/.config/steam-launch-test/` instead of `~/.config/steam-launch/`.

## Compatibility Table

The following table provides configurations (Linux distributions and Steam versions) with which `steam-launch` is confirmed to fully compatible using default settings.

| Linux Distrubution  | Steam installation type | Steam package provider (repository name) |
| ------------------- | ----------------------- | ---------------------------------------- |
| Ubuntu              | Default                 | Steam website                            |
| Ubuntu              | Default                 | Multiverse                               |
| Debian              | Default                 | Steam website                            |
| Debian              | Default                 | contrib                                  |
| Fedora              | Default                 | RPMFusion                                |
| openSUSE Tumbleweed | Default                 | Main Repository (NON-OSS)                |
| Arch Linux          | Default                 | multilib                                 |
| Void Linux          | Default                 | void-repo-nonfree                        |
| Gentoo              | Default                 | steam-overlay                            |
| NixOS               | Default                 | nixpkgs                                  |
| Solus               | Default                 | Stable                                   |
| Ubuntu              | Flatpak                 | Flathub                                  |
| Debian              | Flatpak                 | Flathub                                  |
| Fedora              | Flatpak                 | Flathub                                  |
| Alpine Linux        | Flatpak                 | Flathub                                  |
| Ubuntu              | Snap                    | Snap Store                               |

## License

This project is licensed under the MIT License.