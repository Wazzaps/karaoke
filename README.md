# Karaoke app for linux

A small karaoke/lyrics display for the currently running VLC song.

Make sure the songs have metadata (at least title and artist).

## Running

- step 0 - setup a linux flutter toolchain
- step 1 - setup vscode for flutter dev
- step 2 - run it inside vscode

## Known bugs

- Attempting to close the app will make it stall. Probably async shenanigans.
- Running under wayland produces a blank window without GDK_BACKEND=x11 env var, probably flutter's problem
- Doesn't work in `flutter run`, looks like `dbus_client`'s fault somehow (writes lots of `flutter: Failed to read from socket: Invalid argument` to stdout)