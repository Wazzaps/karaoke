import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:path_provider/path_provider.dart';

import 'controllers.dart';

class LyricSource {
  Future<String> fetchLrcFile(SongMetadata metadata, StreamSink<String> statusUpdates) async {
    return """[00:00.00]Hello,
[00:00.00]World.
[00:00.00]Foo
[00:00.00]Bar""";
  }

  Future<List<Lyric>> fetchLyrics(SongMetadata metadata, StreamSink<String> statusUpdates) async {
    return (await fetchLrcFile(metadata, statusUpdates))
        ?.split("\n")
        ?.map((lyric) {
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
        ?.where((lyric) => lyric != null)
        ?.toList();
  }
}

class LocalLyricSource extends LyricSource {
  @override
  Future<String> fetchLrcFile(SongMetadata metadata, StreamSink<String> statusUpdates) async {
    var basedir = await getApplicationSupportDirectory();
    var nameParts = [];
    if (metadata.artist != null) {
      nameParts.add(metadata.artist);
    }
    if (metadata.title != null) {
      nameParts.add(metadata.title);
    }
    if (nameParts.length == 0) {
      return null;
    }

    var sanitizedName = (nameParts.join(" - ")).replaceAll("/", "_").replaceAll(" ", "+").replaceAll("&", "%26");
    await Directory("${basedir.path}/lyrics").create();
    var lrcFile = File("${basedir.path}/lyrics/$sanitizedName.lrc");
    if (await lrcFile.exists()) {
      return await lrcFile.readAsString();
    }

    return null;
  }
}

class SyairInfoLyricSource extends LyricSource {
  @override
  Future<String> fetchLrcFile(SongMetadata metadata, StreamSink<String> statusUpdates) async {
    var basedir = await getApplicationSupportDirectory();
    var nameParts = [];
    if (metadata.artist != null) {
      nameParts.add(metadata.artist);
    }
    if (metadata.title != null) {
      nameParts.add(metadata.title);
    }
    if (nameParts.length == 0) {
      return null;
    }

    var sanitizedName = (nameParts.join(" - ")).replaceAll("/", "_").replaceAll(" ", "+").replaceAll("&", "%26");
    await Directory("${basedir.path}/lyrics").create();
    var lrcFile = File("${basedir.path}/lyrics/$sanitizedName.lrc");
    if (await lrcFile.exists()) {
      return await lrcFile.readAsString();
    }

    statusUpdates.add("Searching online (syair.info)");

    print("--- searching for lyrics ($sanitizedName)");
    var searchResult = latin1.decode((await http.get("https://syair.info/search?q=$sanitizedName")).bodyBytes);
    var firstResult = RegExp(r'<div class="li">1\. <a href="/lyrics/([^"]+)" target="_blank" class="title">')
        .firstMatch(searchResult);
    if (firstResult != null) {
      statusUpdates.add("Found \"${firstResult.group(1)}\"");
      print("-- found: ${firstResult.group(1)}");
      print("--- loading lyrics page");
      var lyricsPage = latin1.decode((await http.get("https://syair.info/lyrics/${firstResult.group(1)}")).bodyBytes);
      var downloadLink = RegExp(r'<a href="/download\.php\?([^"]+)" rel="nofollow" target="_blank"><span>Download ')
          .firstMatch(lyricsPage);
      if (downloadLink != null) {
        statusUpdates.add("Downloading lyrics");
        print("--- downloading lyrics");
        var lyrics =
            utf8.decode((await http.get("https://syair.info/download.php?${downloadLink.group(1)}")).bodyBytes);
        await lrcFile.writeAsString(lyrics);
        return lyrics;
      }
    }
    return null;
  }
}
