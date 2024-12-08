# checkpac

A fast and simple package checking tool for Arch Linux. Quickly find installed packages, check versions, and discover available packages using simple keyword searches. Get a clean, colorful overview of package status, update availability, and repository sources - all in one place. Perfect for when you need to quickly check what's on your system or find new packages to install.

![image](https://github.com/user-attachments/assets/6982e19e-23dc-43bb-80ad-30f42e4ec628)


## Features

- **Simple package checking** - find packages using keywords, no exact names needed
- **Check multiple packages at once** - checkpac firefox chrome vim
- **Fast results** - efficient parallel searching for quick lookups
- **Clear, readable output** - color-coded information shows status at a glance
- **Version checking** - easily see available updates. Arch repos check against synced package caches, while AUR check against AUR RPC Endpoint
- **AUR support** - No aur helper needed. Uses RPC

## Installation

Clone the repository:
```bash
git clone https://github.com/zeroz/checkpac.git
cd checkpac
```

Install dependencies:
```bash
pacman -S expac flock
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


## Advanced Features

### Search Options

| Flag | Description |
|------|-------------|
| `-r`, `--remote` | Include packages from repositories |
| `-d`, `--desc` | Search package descriptions |
| `-e`, `--exact` | Match package names exactly |
| `--exclude-aur` | Skip AUR packages |
| `--exclude-arch` | Skip official repository packages |

### Advanced Examples

![image](https://github.com/user-attachments/assets/c2ca724d-bd1e-42ed-8ca8-87b5a2fd9495)


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
checkpac paru yay aurutils -r --exclude-aur
```

### Features in Detail

#### Multi-Package Search
- Search any number of packages simultaneously
- Organized, clear output grouping
- Efficient parallel processing
- Smart result deduplication
- Search for keyword in package name, exact name match, or search descriptions
- In description search, highlights your keyword in the returned package description

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
- Multiple package search support

## About

Created by zeroz/tj

Licensed under GPLv3
