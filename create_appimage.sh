#!/usr/bin/env bash
set -e
# flutter build linux
mkdir -p Karaoke.AppDir/usr/bin
cp -r build/linux/release/bundle/* Karaoke.AppDir/usr/bin
echo "MANUAL TODO (Once):"
echo "- Copy AppRun from https://github.com/AppImage/AppImageKit releases into Karaoke.AppDir/"
echo "- Locate libunixdomainsocket.so on your PC and put it in Karaoke.AppDir/usr/bin/lib/"
echo "Press enter to continue"
head -n1 > /dev/null
strip Karaoke.AppDir/usr/bin/lib/libapp.so Karaoke.AppDir/usr/bin/lib/libflutter_linux_gtk.so Karaoke.AppDir/usr/bin/lib/libunixdomainsocket.so Karaoke.AppDir/usr/bin/karaoke
~/Downloads/appimagetool-x86_64.AppImage Karaoke.AppDir/
