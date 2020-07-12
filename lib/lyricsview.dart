import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:dbus_client/dbus_client.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class Lyric {
  final Duration time;
  final String text;

  Lyric(this.time, this.text);
}

class LyricsView extends StatefulWidget {
  LyricsView({Key key}) : super(key: key);

  @override
  _LyricsViewState createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  Timer _timer;
  Timer _mprisTimer;
  Timer _mprisMetadataTimer;
  DBusClient _dbusClient;
  String _songTitle = "N/A";
  String _songArtist = "N/A";
  List<Lyric> _lyrics = [];

  static const double LYRIC_SIZE = 24.0;

  int idx = -1;
  // DateTime start = DateTime.now().add(Duration(seconds: 2));
  Duration _currentTime = Duration();
  ScrollController scrollController = ScrollController();

  Future<String> fetchLrcFile(String title, String artist) async {
    var basedir = await getApplicationSupportDirectory();
    var nameParts = [];
    if (artist != "N/A") {
      nameParts.add(artist);
    }
    if (title != "N/A") {
      nameParts.add(title);
    }
    var sanitizedName = (nameParts.join(" - ")).replaceAll("/", "_").replaceAll(" ", "+").replaceAll("&", "%26");
    await Directory("${basedir.path}/lyrics").create();
    var lrcFile = File("${basedir.path}/lyrics/$sanitizedName.lrc");
    if (await lrcFile.exists()) {
      return await lrcFile.readAsString();
    }

    setState(() {
      idx = -1;
      _lyrics = [Lyric(Duration(), "(Searching for lyrics...)")];
    });
    print("--- searching for lyrics ($sanitizedName)");
    var searchResult = latin1.decode((await http.get("https://syair.info/search?q=$sanitizedName")).bodyBytes);
    var firstResult = RegExp(r'<div class="li">1\. <a href="/lyrics/([^"]+)" target="_blank" class="title">')
        .firstMatch(searchResult);
    if (firstResult != null) {
      setState(() {
        _lyrics = [Lyric(Duration(), "(Found \"${firstResult.group(1)}\"...)")];
      });
      print("-- found: ${firstResult.group(1)}");
      print("--- loading lyrics page");
      var lyricsPage = latin1.decode((await http.get("https://syair.info/lyrics/${firstResult.group(1)}")).bodyBytes);
      var downloadLink = RegExp(r'<a href="/download\.php\?([^"]+)" rel="nofollow" target="_blank"><span>Download ')
          .firstMatch(lyricsPage);
      if (downloadLink != null) {
        setState(() {
          _lyrics = [Lyric(Duration(), "(Downloading lyrics...)")];
        });
        print("--- downloading lyrics");
        var lyrics =
            utf8.decode((await http.get("https://syair.info/download.php?${downloadLink.group(1)}")).bodyBytes);
        await lrcFile.writeAsString(lyrics);
        return lyrics;
      }
    } else {
      return "[00:00.00](Lyrics not found)";
    }
    return "[00:00.00](Download error)";
  }

  Future<List<Lyric>> fetchLyrics(String title, String artist) async {
    var lyrics = (await fetchLrcFile(title, artist))
        .split("\n")
        .map((lyric) {
          var match = RegExp(r"\[(\d+):(\d+\.\d+)\](.*)").firstMatch(lyric);
          if (match != null) {
            var min = int.parse(match.group(1));
            var sec = double.parse(match.group(2));
            var lyric = match.group(3);
            return Lyric(Duration(minutes: min, seconds: sec.floor(), milliseconds: ((sec % 1) * 1000).floor()), lyric);
          } else {
            return null;
          }
        })
        .where((lyric) => lyric != null)
        .toList();
    return lyrics;
  }

  String formatTime(Duration time) {
    if (time.isNegative) {
      return "-" + formatTime(-time);
    } else {
      return "${time.inMinutes.toString().padLeft(2, "0")}:${(time.inSeconds % 60).toString().padLeft(2, "0")}";
    }
  }

  Duration getSongTime() {
    // return DateTime.now().difference(start)
    return _currentTime;
  }

  Future<void> testMpris() async {
    if (_dbusClient == null) {
      _dbusClient = DBusClient.session();
      _dbusClient.connect();
    }
    try {
      var posResult = await _dbusClient.getProperty(
        destination: 'org.mpris.MediaPlayer2.vlc',
        path: '/org/mpris/MediaPlayer2',
        interface: 'org.mpris.MediaPlayer2.Player',
        name: 'Position',
      );

      var pos = (posResult.value as DBusInt64).value;
      _currentTime = Duration(microseconds: pos);
    } catch (e) {
      print("testMpris: $e");
    }
    _mprisTimer = Timer(Duration(milliseconds: 100), testMpris);
  }

  Future<void> testMprisSeek(int timeInMicrosecs) async {
    if (_dbusClient == null) {
      _dbusClient = DBusClient.session();
      _dbusClient.connect();
    }
    try {
      await _dbusClient.callMethod(
        destination: 'org.mpris.MediaPlayer2.vlc',
        path: '/org/mpris/MediaPlayer2',
        interface: 'org.mpris.MediaPlayer2.Player',
        member: 'Seek',
        values: [DBusInt64(timeInMicrosecs - _currentTime.inMicroseconds)],
      );
    } catch (e) {
      print("testMprisSeek: $e");
    }
  }

  Future<void> testMprisMetadata() async {
    if (_dbusClient == null) {
      _dbusClient = DBusClient.session();
      _dbusClient.connect();
    }
    try {
      var metadataResult = await _dbusClient.getProperty(
        destination: 'org.mpris.MediaPlayer2.vlc',
        path: '/org/mpris/MediaPlayer2',
        interface: 'org.mpris.MediaPlayer2.Player',
        name: 'Metadata',
      );

      var metadata = (metadataResult.value as DBusDict);
      var songTitle = "N/A";
      var songArtist = "N/A";
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
        _lyrics = await fetchLyrics(songTitle, songArtist);
      }
    } catch (e) {
      print("testMprisMetadata: $e");
    }
    _mprisMetadataTimer = Timer(Duration(milliseconds: 200), testMprisMetadata);
  }

  @override
  Widget build(BuildContext context) {
    if (_timer == null) {
      _timer = Timer.periodic(Duration(milliseconds: 30), (timer) {
        var newIdx = idx;
        _lyrics.asMap().forEach((lyricIdx, lyric) {
          if (getSongTime() >= lyric.time) {
            newIdx = lyricIdx;
          }
        });
        if (newIdx != idx) {
          var height = 24.0 + LYRIC_SIZE;
          scrollController.animateTo(800 + newIdx * height - (MediaQuery.of(context).size.height / 6),
              duration: Duration(milliseconds: 250), curve: Curves.easeOutCubic);
        }
        setState(() {
          idx = newIdx;
        });
      });
    }
    if (_mprisTimer == null) {
      _mprisTimer = Timer(Duration(milliseconds: 100), testMpris);
    }
    if (_mprisMetadataTimer == null) {
      _mprisMetadataTimer = Timer(Duration(milliseconds: 200), testMprisMetadata);
    }

    return Center(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Container(
                constraints: BoxConstraints(maxWidth: 1000),
                child: ListView(
                  controller: scrollController,
                  physics: NeverScrollableScrollPhysics(),
                  children: <Widget>[
                        Container(
                          constraints: BoxConstraints(minHeight: 800),
                        )
                      ] +
                      _lyrics
                          .asMap()
                          .map(
                            (i, l) => MapEntry(
                              i,
                              GestureDetector(
                                onTap: () {
                                  testMprisSeek(l.time.inMicroseconds);
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: AnimatedDefaultTextStyle(
                                    style: i == idx
                                        ? Theme.of(context).textTheme.headline5.copyWith(
                                              color: Colors.white,
                                              fontSize: LYRIC_SIZE,
                                            )
                                        : (i < idx
                                            ? Theme.of(context).textTheme.headline5.copyWith(
                                                  color: Colors.white12,
                                                  fontSize: LYRIC_SIZE,
                                                )
                                            : Theme.of(context).textTheme.headline5.copyWith(
                                                  color: Colors.white38,
                                                  fontSize: LYRIC_SIZE,
                                                )),
                                    duration: Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    softWrap: true,
                                    child: Text(l.text),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .values
                          .toList() +
                      <Widget>[
                        Container(
                          constraints: BoxConstraints(minHeight: 800),
                        )
                      ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.black26,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 48.0),
                child: Container(
                  constraints: BoxConstraints(maxWidth: 1000),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 5.0),
                        child: Text(
                          _songTitle,
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                      ),
                      Expanded(
                        flex: 100,
                        child: Text(
                          _songArtist,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: Theme.of(context).textTheme.caption,
                        ),
                      ),
                      Spacer(flex: 1),
                      Text(
                        formatTime(getSongTime()),
                        style: Theme.of(context).textTheme.subtitle2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
