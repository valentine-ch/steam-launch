
# A Simple Utility to Launch Steam Games from the Terminal on Linux

## Why?

Although Steam provides the ability to launch games via terminal with a command like:
```bash
$ steam steam://rungameid/{appid}
```
This requires you to input the game’s appid each time, which is not very convenient. `steam-launch` simplifies this process by letting you create and manage game aliases and effortlessly launch games by alias.

## Features

- Launch Steam games from terminal by custom aliases.
- Manage and remove aliases.
- Automatically find appids.
- Customize settings for non-standard Steam installations.
- Customize Steam launch arguments.

## Getting Started

### 1. Installation (Optional)

You can add `steam-launch.sh` to PATH for easier access. Of course you can make a custom alias for it. All examples below assume you have it added to PATH as `steam-launch`.

### 2. Initialize the Configuration Directory (Optional)

Run the following command to initialize the config directory:
```bash
$ steam-launch --init
```
This will create a directory at `~/.config/steam-launch/` and initialize necessary config files there. You only need to run this if you want to manually edit the config before using the tool.

### 3. Adding Aliases

There are several ways to add game aliases:
#### a. Manually
You can manually enter appid:
```bash
$ steam-launch --alias -m {alias} {appid}
```
Example:
```bash
$ steam-launch --alias -m rdr2 1174180
```
#### b. Searching Local Files
You can search for the game by its name in Steam local files:
```bash
$ steam-launch --alias -l {game_name} {alias}
```
Example:
```bash
$ steam-launch --alias -l "Red Dead Redemption 2" rdr2
```
If you want the alias to be the exact game name, omit the alias argument:
```bash
$ steam-launch --alias -l {game_name}
```
Example:
```bash
$ steam-launch --alias -l Portal
```
**Note 1:** This works only for installed games or games that have residual files in the `steamapps` directory.
**Note 2:** Game name must be exact match (case sensitive).
**Note 3:** For non-standard Steam installations you may need to update `steam-launch` config first.
#### c. Using the Steam Web API
Alternatively, you can search for the game appid using the Steam Web API:
```bash
$ steam-launch --alias -a {game_name} {alias}
```
Example:
```bash
$ steam-launch --alias -a "Red Dead Redemption 2" rdr2
```
If you want the alias to be the exact game name, omit the alias argument:
```bash
$ steam-launch --alias -a {game_name}
```
Example:
```bash
$ steam-launch --alias -a Portal
```
**Note 1:** An Internet connection is required for this feature.
**Note 2:** Game name must be exact match (case sensitive).
**Note 3:** This may not work as expected if multiple games share exactly the same name.
#### d. Editing the Alias File Directly
You can edit the alias file (`~/.config/steam-launch/alias.json`) directly. Add a new entry to the file where key is alias name and value is game id.
Example:
```json
{
    "rdr2": 1174180,
    "Portal": 400
}
```
### 4. Updating or Removing Aliases

- To update an alias, simply create a new alias with the same name, and it will overwrite the existing one.
- To remove an alias:
  ```bash
  $ steam-launch --rmalias {alias}
  ```
  Example:
  ```bash
  $ steam-launch --rmalias rdr2
  ```
- To list aliases:
  ```bash
  $ steam-launch --list
  ```
You can have multiple aliases for the same game.

### 5. Launching Games

To launch a game, simply use the alias:
```bash
$ steam-launch {alias}
```
Example:
```bash
$ steam-launch rdr2
```

### 6. Customizing Settings

#### a. Changing the Steam Command

If Steam is installed in a non-default way (e.g., via Flatpak), you may need to update the `steam` command used by `steam-launch`:
```bash
$ steam-launch --cfg -steam {steam_command}
```
Example:
```bash
$ steam-launch --cfg -steam "flatpak run com.valvesoftware.Steam"
```

#### b. Changing the `steamapps` Directory

For non-standard installations of Steam you may need to update the `steamapps` location before adding aliases by searching local files:
```bash
$ steam-launch --cfg -path {steamapps_location}
```
Example (for Flatpak):
```bash
$ steam-launch --cfg -path ~/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps
```

#### c. Adding Steam Launch Arguments

If you typically launch Steam with additional arguments, you can configure `steam-launch` to use them (or you can add arguments specific to `steam-launch`):
```bash
$ steam-launch --cfg -args "{your_args}"
```
Example:
```bash
$ steam-launch --cfg -args "-forcedesktopscaling=1.5 -silent"
```

## License

This project is licensed under the MIT License.