![bashatime](./bashatime.jpg)

# bashatime.sh

[![Athena Award Badge](https://img.shields.io/endpoint?url=https%3A%2F%2Faward.athena.hackclub.com%2Fapi%2Fbadge)](https://award.athena.hackclub.com?utm_source=readme)

<br/>

## Installation

**Requirements**
- A Linux machine (MacOS might work too, untested though)
- `inotify-tools`, to watch for files
- `git`, to know what files to watch
- `bash`, to run the script
- `wakatime`/`wakatime-api`, to submit your progress to wakatime

### Clone the repository

First, clone the bashatime repository to your local machine. This is bashatime's installation directory. You can use a different directory to the one used in the command below, if you know what you are doing.

```bash
git clone https://github.com/prplwtf/bashatime.sh.git ~/.bashatime
```

### Make executable

To run bashatime, you have to make it executable.

```bash
chmod +x ~/.bashatime/bashatime.sh
```

### Make it a command

In your `~/.bashrc` or `~/.zshrc`, create an alias for `~/.bashatime/bashatime.sh` to run it more easily.

```bash
# When using bash
echo "alias bashatime=\"~/.bashatime/bashatime.sh\"" >> ~/.bashrc

# When using zsh
echo "alias bashatime=\"~/.bashatime/bashatime.sh\"" >> ~/.zshrc
```

### Source the shell config

Finally, source the shell config to apply the alias to your current session.

```bash
# When using bash
source ~/.bashrc

# When using zsh
source ~/.zshrc
```

### Run bashatime from your project directory

Run the bashatime script from your project's root directory. You have to do this every time you code.

```bash
bashatime
```

## Configuration

To create a bashatime configuration, make a file called `.bashatimerc` in the project's directory. The following configuration options are currently supported:

```bash
# The name of your project, defaults to the parent folder name
PROJECT_NAME=""

# Uncomment to output verbose logs as well
#LOG_VERBOSE="1"
```

### Wakatime configuration

bashatime uses the `wakatime-api` cli tool to submit heartbeats. Use the `~/.wakatime.cfg` config for your API url, key, and other configuration options.

## Limitations

bashatime has a few known limitations, it's a bash script after all.

- When deleting tracked files, bashatime might return errors when updating any file. To fix this, commit your deleted files in git.
- bashatime does not know your editor's buffer cursor position. It tries to "guess" the cursor position based on file changes, but will never be 100% accurate.
- Configuration options are lacking right now, but more might be introduced at some point in the future.

## Contributing

Contributions are welcome. Whenever making changes to `bashatime.sh`, please make sure it passes shellcheck to avoid weird edge-cases and shell freak-outs.
