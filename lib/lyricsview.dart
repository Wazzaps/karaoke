import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:karaoke/controllers.dart';

class LyricsView extends StatelessWidget {
  final List<Lyric> lyrics;
  final ScrollController scrollController;
  final double lyricSize;
  final int highlightedLyricIdx;
  final void Function(int lyricIdx, Lyric lyric) lyricTapCallback;

  static const double VERTICAL_PADDING = 800.0;
  // static const double VERTICAL_PADDING = 100.0;
  static const int LYRIC_ANIMATION_DURATION = 250;

  const LyricsView({
    @required this.lyrics,
    @required this.scrollController,
    @required this.highlightedLyricIdx,
    this.lyricSize = 24.0,
    this.lyricTapCallback,
  });

  Widget lyricLine(BuildContext context, int lyricIdx, Lyric lyric) {
    TextStyle style;

    if (lyricIdx == highlightedLyricIdx) {
      // Highlighted style
      style = Theme.of(context).textTheme.headline5.copyWith(
            color: Colors.white,
            fontSize: lyricSize,
          );
    } else if (lyricIdx < highlightedLyricIdx) {
      // Past style
      style = Theme.of(context).textTheme.headline5.copyWith(
            color: Colors.white12,
            fontSize: lyricSize,
          );
    } else {
      // Future style
      style = Theme.of(context).textTheme.headline5.copyWith(
            color: Colors.white38,
            fontSize: lyricSize,
          );
    }

    return GestureDetector(
      onTap: () {
        if (lyricTapCallback != null) {
          lyricTapCallback(lyricIdx, lyric);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: AnimatedDefaultTextStyle(
          style: style,
          duration: Duration(milliseconds: LYRIC_ANIMATION_DURATION),
          curve: Curves.easeOutCubic,
          softWrap: true,
          child: Text(lyric.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var topPadding = Container(constraints: BoxConstraints(minHeight: VERTICAL_PADDING));
    var lyricWidgets = lyrics
        .asMap()
        .map((lyricIdx, lyric) => MapEntry(lyricIdx, lyricLine(context, lyricIdx, lyric)))
        .values
        .toList();
    var bottomPadding = Container(constraints: BoxConstraints(minHeight: VERTICAL_PADDING));

    return ListView(
      shrinkWrap: true,
      controller: scrollController,
      physics: NeverScrollableScrollPhysics(),
      children: <Widget>[topPadding] + lyricWidgets + <Widget>[bottomPadding],
    );
  }
}

class SongInfoView extends StatelessWidget {
  final String songTitle;
  final String songArtist;
  final Duration songProgress;

  const SongInfoView({Key key, @required this.songTitle, @required this.songArtist, @required this.songProgress})
      : super(key: key);

  String formatTime(Duration time) {
    if (time.isNegative) {
      return "-" + formatTime(-time);
    } else {
      return "${time.inMinutes.toString().padLeft(2, "0")}:${(time.inSeconds % 60).toString().padLeft(2, "0")}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 5.0),
          child: Text(
            songTitle,
            style: Theme.of(context).textTheme.subtitle1,
          ),
        ),
        Expanded(
          flex: 100,
          child: Text(
            songArtist,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.caption,
          ),
        ),
        Spacer(flex: 1),
        Text(
          formatTime(songProgress),
          style: Theme.of(context).textTheme.subtitle2,
        ),
      ],
    );
  }
}
