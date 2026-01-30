# checkpac

A fast and simple package checking tool for Arch Linux. Quickly find installed packages, check versions, and discover available packages using simple keyword searches. Get a clean, colorful overview of package status, update availability, and repository sources - all in one place. Perfect for when you need to quickly check what's on your system or find new packages to install.

![image](https://github.com/user-attachments/assets/03d62d26-b067-43bd-b07a-20ba9aed2a2d)


## Features

- **Simple package checking** - find packages using keywords, no exact names needed
- **Check multiple packages at once** - checkpac firefox chrome vim
- **Fast results** - efficient parallel searching for quick lookups
- **Clear, readable output** - color-coded information shows status at a glance
- **Version checking** - easily see available updates. Arch repos check against remote official repos, while AUR check against AUR RPC Endpoint
- **AUR support** - No aur helper needed to be installed. Paginates requests to AUR to be able to return large lists of results if required

## Installation

### From AUR (Recommended)

checkpac is available on the [AUR](https://aur.archlinux.org/packages/checkpac). Install it using your favorite AUR helper:

```bash
# Using yay
yay -S checkpac

# Using paru
paru -S checkpac

# Or manually with makepkg
git clone https://aur.archlinux.org/checkpac.git
cd checkpac
makepkg -si
```

help menu
<img width="1271" height="599" alt="image" src="https://github.com/user-attachments/assets/3b8e963c-a581-4672-bbe3-99f8644a3709" />


### Manual Installation

Clone the repository:
```bash
git clone https://github.com/zeroz/checkpac.git
cd checkpac
```

Install dependencies:
```bash
pacman -S expac flock jq
```

Make the script executable if not:
```bash
chmod +x bin/checkpac
```

You can either:
1. Create an alias in your `.bashrc`
   ```bash
   alias checkpac='/path/to/checkpac.bash'
   ```
   
2. Or copy to a directory in your PATH:
   ```bash
   sudo cp bin/checkpac.bash /usr/local/bin/checkpac
   ```

## Basic Usage
Default search is case insensitive, and uses your package arguments as keywords to search for package names containing it.
You may also search for exact package name matches, or choose to search and list packages where your keywords match the description


Check a single package:
```bash
checkpac wine
```

Check multiple packages at once:
```bash
checkpac firefox minecraf vim
```


Include remote packages (not installed):
```bash
checkpac -r firefox chromium brave
```
or 
```bash
checkpac firefox chromium brave -r
```

List all installed lib packages containing "lib"
```bash
checkpac lib
```

View the help menu :)
```bash
checkpac -h
```

-     Simple output(list every found package in line by line scriptable output. can be combined with any flags:

- Use -s flag.
- 
<img width="1271" height="599" alt="image" src="https://github.com/user-attachments/assets/ab49ea2c-7c12-4fb8-934b-17988316db90" />



## Advanced Features

### Search Options

| Flag | Description |
|------|-------------|
| `-r`, `--remote` | Include packages from repositories |
| `-d`, `--desc` | Search package descriptions |
| `-e`, `--exact` | Match package names exactly |     
| `-s`, `--simple` | List packages line by line with NAME ONLY, for simple usage in scripting |
| `--exclude-aur` | Skip AUR packages |
| `--exclude-arch` | Skip official repository packages |

### Advanced Examples

![image](https://github.com/user-attachments/assets/6f2f7af3-3c78-4def-a6fc-69b26f5b1249)


Search through descriptions and remote packages for multiple terms:
```bash
checkpac -rd docker kubernetes podman container
```

Search for exact package matches:
```bash
checkpac -e wine wine-staging wine-mono
```

Check ONLY AUR packages locally installed:
```bash
checkpac --exclude-arch paru yay aurutils
```

Check ONLY AUR packages, remote and installed:
```bash
checkpac paru yay aurutils -r --exclude-arch
```

### Features in Detail

#### Version Checking
- Color-coded version comparisons (installed vs detected in package cache)
- Highlights version differences
- Shows available updates
- Detects development packages (-git, -svn, etc.)

#### Repository Information
- Shows package source (core, extra, community, etc.)
- Color-coded repository types
- AUR package identification
- Development package detection

#### Search Capabilities
- Parallel search processing
- Optional description searching
- Case-insensitive by default
- Exact matching option
- Paginated API searches
- Multiple package search support

#### Processing
- Support for sub processes and process management for speed
- Allows caching for packages to process and print more efficiently/simulataneously
- Process interruption. Always be able to kill the program with Ctrl^C or interrupts

## About

Created by zeroz/tj

Licensed under GPLv3
