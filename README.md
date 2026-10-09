# WTPTerminfo

Custom terminfo descriptions for Windows Terminal Preview 1.26, provided in
[`wt-advanced.tl`](wt-advanced.tl). This is an unofficial profile, not a Microsoft
distribution.

The source defines two terminal types:

| Terminal type | Description |
| --- | --- |
| `wt-advanced` | 256-color profile based on `xterm-256color`, with additional escape sequences. Recommended starting point. |
| `wt-direct` | Inherits `wt-advanced`, advertises 24-bit color, and adds the `setfrgb` and `setbrgb` RGB helpers. |

Additional capabilities in the source describe synchronized output (`Sync`),
hyperlinks (`Smulx`/`Rmulx`), overline (`Smol`/`Rmol`), underline styles
(`Smul2`, `Smulc`, `Smuld`, `Smule`), and mode 2048 (`Smkb`/`Rmkb`). These are
the names used by this file; applications must understand their names and
semantics to use them. Compiling an entry does not verify that every sequence
works in the terminal or that an application will use it.

## Requirements

Run these commands in the environment where your terminal applications run:
for example, your WSL distribution or a Linux host reached through SSH from
Windows Terminal Preview 1.26. Install the database there, rather than in
Windows Terminal's settings directory.

You need a recent **ncurses** installation providing `tic`, `infocmp`, and
`tput`, plus the existing `xterm-256color` entry. On Debian or Ubuntu:

```sh
sudo apt-get update
sudo apt-get install ncurses-bin ncurses-term
```

Check the compiler and base entry:

```sh
tic -V
infocmp xterm-256color
```

## Compile and install for your user

Clone the repository, or use an existing copy:

```sh
git clone https://github.com/CryptoDragonLady/WTPTerminfo.git
cd WTPTerminfo
```

From the directory containing `wt-advanced.tl`:

```sh
# Check the source without installing anything.
tic -x -c wt-advanced.tl

# Compile and install both entries in your user terminfo database.
mkdir -p "$HOME/.terminfo"
tic -x -s -o "$HOME/.terminfo" wt-advanced.tl
```

`-x` preserves the extended capabilities, `-o` chooses the output database,
and `-s` prints an installation summary. Both entries are compiled by the
same command. No `sudo` is needed for this user installation. Repeating the
command updates the installed entries.

Verify that both entries can be read, including their extensions:

```sh
infocmp -x -A "$HOME/.terminfo" wt-advanced
infocmp -x -A "$HOME/.terminfo" wt-direct
```

## Use the profile

In a shell displayed by Windows Terminal Preview 1.26:

```sh
export TERM=wt-advanced
tput colors
```

The expected color count is `256`. You can also select the entry for just
one program with `TERM=wt-advanced your-program`, replacing `your-program`
with the command you want to run.

To make the setting persistent, add `export TERM=wt-advanced` to the startup
file used by that specific shell/profile (for example, `~/.bashrc` for an
interactive Bash shell). Scope it to sessions using Windows Terminal; a
shared startup file may also run under other terminal emulators. Inside
`tmux` or `screen`, use the terminal type supplied by that multiplexer.

For an application that explicitly supports this file's RGB helpers:

```sh
export TERM=wt-direct
tput colors
```

The expected count is `16777216`. This entry retains the indexed `setaf`
and `setab` definitions inherited from `wt-advanced`; it adds separate
three-parameter `setfrgb` and `setbrgb` capabilities. The larger advertised
color count alone does not guarantee direct-color compatibility with
applications expecting packed RGB arguments to `setaf`/`setab`.

## Optional system installation

To make both entries available to all users on a Linux system whose terminfo
database is `/usr/share/terminfo`:

```sh
sudo tic -x -s -o /usr/share/terminfo wt-advanced.tl
```

Use your system's actual database path if it differs. A user entry can take
precedence over the system entry.

## Troubleshooting

- **Unknown terminal type:** install the entries on the machine and under the
  user running the application. SSH destinations need their own installation.
- **Cannot resolve `xterm-256color`:** install your distribution's ncurses
  terminal database package, then repeat the compilation.
- **Entry installed but not found:** check whether `TERMINFO` or `TERMINFO_DIRS`
  points to another database. To select the user database explicitly, run
  `export TERMINFO="$HOME/.terminfo"` before starting the application.
- **Unknown capabilities or unsupported `-x`:** use ncurses `tic` and keep
  `-x` in the compilation command.
- **Application behaves incorrectly:** return to `export TERM=xterm-256color`
  and restart the application. Use `wt-advanced` instead of `wt-direct` when
  the application does not support the RGB helper conventions above.

## References

- [ncurses `tic` manual](https://invisible-island.net/ncurses/man/tic.1m.html)
- [ncurses terminfo manual](https://invisible-island.net/ncurses/man/terminfo.5.html)
- [Windows Terminal releases](https://github.com/microsoft/terminal/releases)
