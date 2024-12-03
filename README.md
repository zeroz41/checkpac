# pacheck

A fast and simple package checking tool for Arch Linux. Quickly find installed packages, check versions, and discover available packages using simple keyword searches. Get a clean, colorful overview of package status, update availability, and repository sources - all in one place. Perfect for when you need to quickly check what's on your system or find new packages to install.

![Screenshot 1](screenshots/1.png)
![Screenshot 2](screenshots/2.png)
![Screenshot 3](screenshots/3.png)

## Features

- **Simple package checking** - find packages using keywords, no exact names needed
- **Check multiple packages at once** - pacheck firefox chrome vim
- **Fast results** - efficient parallel searching for quick lookups
- **Clear, readable output** - color-coded information shows status at a glance
- **Version checking** - easily see available updates
- **AUR support** - check AUR packages when yay is installed

## Installation

Clone the repository:
```bash
git clone https://github.com/zeroz/pacheck.git
cd pacheck
```

Install dependencies:
```bash
pacman -S expac flock
```

Optional but recommended:
```bash
pacman -S yay  # For AUR support
```

Make the script executable if not:
```bash
chmod +x bin/pacheck
```

You can either:
1. Create an alias in your `.bashrc`
   ```bash
   alias pacheck='/path/to/pacheck.bash'
   ```
   
2. Or copy to a directory in your PATH:
   ```bash
   sudo cp bin/pacheck.bash /usr/local/bin/pacheck
   ```

## Basic Usage
Default search is case insensitive, and uses your package arguments as keywords to search for package names containing it.
You may also search for exact package name matches, or choose to search and list packages where your keywords match the description


Check a single package:
```bash
pacheck wine
```

Check multiple packages at once:
```bash
pacheck firefox minecraf vim
```


Include remote packages (not installed):
```bash
pacheck -r firefox chromium brave
```
or 
```bash
pacheck firefox chromium brave -r
```

List all installed lib packages containing "lib"
```bash
pacheck lib
```

View the help menu :)
```bash
pacheck -h
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

Search through descriptions and remote packages for multiple terms:
```bash
pacheck -rd docker kubernetes podman container
```

Search for exact package matches:
```bash
pacheck -e wine wine-staging wine-mono
```

Check ONLY AUR packages locally installed:
```bash
pacheck --exclude-arch paru yay aurutils
```

Check ONLY AUR packages, remote and installed:
```bash
pacheck paru yay aurutils -r --exclude-aur
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
