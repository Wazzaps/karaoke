import 'dart:async';

import 'package:dbus_client/dbus_client.dart';
import 'package:flutter/widgets.dart';

import 'lyric_sources.dart';

class Lyric {
  final Duration time;
  final String text;

  Lyric(this.time, this.text);
}

class LyricsController {
  var lyricsStream = StreamController<List<Lyric>>.broadcast();
  var highlightedLyricIdxStream = StreamController<int>.broadcast();
  var statusMessageStream = StreamController<String>.broadcast();
  List<Lyric> lastLyrics;
  int lasthighlightedLyricIdx;
  var _didInit = false;

  List<LyricSource> sources = [LocalLyricSource(), SyairInfoLyricSource()];

  fetchNewLyrics(SongMetadata metadata) async {
    if (metadata == null) {
      statusMessageStream.sink.add("Waiting for VLC");
      return;
    }
    statusMessageStream.sink.add("Looking for lyrics");
    var lyrics;
    for (var source in sources) {
      lyrics = await source.fetchLyrics(metadata, statusMessageStream.sink);
      if (lyrics != null) {
        break;
      }
    }

    if (lyrics == null) {
      statusMessageStream.sink.add("Lyrics not found");
    } else {
      lastLyrics = lyrics;
      lyricsStream.sink.add(lyrics);
      statusMessageStream.sink.add(null);
    }
  }

  updateCurrentLyric(Duration currentTime) async {
    if (currentTime == null) {
      return;
    }
    var newIdx = lasthighlightedLyricIdx;
    lastLyrics?.asMap()?.forEach((lyricIdx, lyric) {
      if (currentTime >= lyric.time) {
        newIdx = lyricIdx;
      }
    });
    if (lasthighlightedLyricIdx != newIdx) {
      scrollToLyric(newIdx);
    }
  }

  init(SongMetadata initialSongMetadata, Stream<SongMetadata> songMetadataStream, Stream<Duration> timeStream) async {
    if (!_didInit) {
      songMetadataStream.listen(fetchNewLyrics);
      timeStream.listen(updateCurrentLyric);
    }
  }

  scrollToLyric(int idx) {
    lasthighlightedLyricIdx = idx;
    highlightedLyricIdxStream.sink.add(idx);
  }

  dispose() {
    lyricsStream.close();
    highlightedLyricIdxStream.close();
    statusMessageStream.close();
  }
}

@immutable
class SongMetadata {
  final String title;
  final String artist;

  SongMetadata(this.title, this.artist);
}

class CurrentSongController {
  var metadataStream = StreamController<SongMetadata>.broadcast();
  var timeStream = StreamController<Duration>.broadcast();
  SongMetadata lastMetadata;
  Duration lastTime = Duration();
  var _didInit = false;
  DBusClient _dbusClient;
  String _songTitle;
  String _songArtist;

  Stream<SongMetadata> _metadataStream() async* {
    while (true) {
      try {
        var metadataResult = await _dbusClient.getProperty(
          destination: 'org.mpris.MediaPlayer2.vlc',
          path: '/org/mpris/MediaPlayer2',
          interface: 'org.mpris.MediaPlayer2.Player',
          name: 'Metadata',
        );

        var metadata = (metadataResult.value as DBusDict);
        var songTitle;
        var songArtist;
        metadata.children.forEach((DBusStruct metadataItem) {
          var metadataName = (metadataItem.children[0] as DBusString).value;
          if (metadataName == 'xesam:title') {
            songTitle = ((metadataItem.children[1] as DBusVariant).value as DBusString).value;
          } else if (metadataName == 'xesam:artist') {
            var artistValue = ((metadataItem.children[1] as DBusVariant).value as DBusArray);
            songArtist = artistValue.children.map((a) => (a as DBusString).value).toList().join(", ");
          }
        });
        if (_songArtist != songArtist || _songTitle != songTitle) {
          _songTitle = songTitle;
          _songArtist = songArtist;
          print("$songTitle - $songArtist");
          if (songTitle == null && songArtist == null) {
            yield null;
          } else {
            yield SongMetadata(songTitle, songArtist);
          }
        }
      } catch (e) {
        print(e);
        _songArtist = null;
        _songTitle = null;
        yield null;
      }

      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  Stream<Duration> _timeStream() async* {
    while (true) {
      try {
        var posResult = await _dbusClient.getProperty(
          destination: 'org.mpris.MediaPlayer2.vlc',
          path: '/org/mpris/MediaPlayer2',
          interface: 'org.mpris.MediaPlayer2.Player',
          name: 'Position',
        );

        var pos = (posResult.value as DBusInt64).value;
        // print("yes vlc");
        yield Duration(microseconds: pos);
      } catch (e) {
        // print("no vlc");
        yield null;
      }

      await Future.delayed(Duration(milliseconds: 50));
    }
  }

  seek(Duration time) async {
    try {
      await _dbusClient.callMethod(
        destination: 'org.mpris.MediaPlayer2.vlc',
        path: '/org/mpris/MediaPlayer2',
        interface: 'org.mpris.MediaPlayer2.Player',
        member: 'Seek',
        values: [DBusInt64(time.inMicroseconds - lastTime.inMicroseconds)],
      );
    } catch (e) {}
  }

  init() async {
    if (!_didInit) {
      _dbusClient = DBusClient.session();
      _dbusClient.connect();
      _metadataStream().listen((event) {
        if (event != null) {
          print("CurrentSongController: ${event.title}");
        }
        lastMetadata = event;
        metadataStream.sink.add(event);
      });
      _timeStream().listen((event) {
        lastTime = event;
        timeStream.sink.add(event);
      });
    }
  }

  dispose() {
    print("BYE!!!!");
    metadataStream.close();
    timeStream.close();
    _dbusClient.close();
  }
}
