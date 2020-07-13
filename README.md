# Karaoke app for linux

A small karaoke/lyrics display for the currently running VLC song.

Video:

[![Video](http://img.youtube.com/vi/ph0usWUUbZU/0.jpg)](http://www.youtube.com/watch?v=ph0usWUUbZU "Karaoke app for Linux")

Make sure the songs have metadata (at least title and artist).

## Downloading

- Download from the "Releases" section
- `chmod +x karaoke-x86_64.appimage`
- `./karaoke-x86_64.appimage`

## Building

- step 0 - setup a linux flutter toolchain
- step 1 - `flutter run`

## Known bugs

- Attempting to close the app will make it hang. Looks like `dbus_client` doesn't close its thread
- Running under wayland produces a blank window without GDK_BACKEND=x11 env var, probably flutter's problem
- stdout is very spammy (dbus_client is loud)
