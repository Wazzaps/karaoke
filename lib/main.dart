import 'package:flutter/material.dart';
import 'package:karaoke/controllers.dart';
import 'package:karaoke/lyricsview.dart';
import 'package:karaoke/statusview.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karaoke',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      debugShowCheckedModeBanner: false,
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  ScrollController _scrollController = ScrollController(initialScrollOffset: LyricsView.VERTICAL_PADDING);
  CurrentSongController _currentSongController = CurrentSongController();
  LyricsController _lyricsController = LyricsController();

  @override
  Widget build(BuildContext context) {
    _currentSongController.init();
    _lyricsController.init(
      _currentSongController.lastMetadata,
      _currentSongController.metadataStream.stream,
      _currentSongController.timeStream.stream,
    );

    return Scaffold(
      body: StreamBuilder(
        stream: _lyricsController.statusMessageStream.stream,
        initialData: "Starting up",
        builder: (context, snapshot) {
          if (snapshot.data != null) {
            return StatusMessageView(snapshot.data);
          } else {
            return Center(
              child: Column(
                children: [
                  Expanded(
                    child: buildLyricViewContainer(),
                  ),
                  Material(
                    color: Colors.black26,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 48.0),
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 900),
                          child: StreamBuilder<SongMetadata>(
                            stream: _currentSongController.metadataStream.stream,
                            initialData: _currentSongController.lastMetadata,
                            builder: (context, metadataSnapshot) {
                              return StreamBuilder<Duration>(
                                stream: _currentSongController.timeStream.stream,
                                builder: (context, timeSnapshot) {
                                  return SongInfoView(
                                    songTitle: metadataSnapshot.data?.title ?? "null",
                                    songArtist: metadataSnapshot.data?.artist ?? "null",
                                    songProgress: timeSnapshot.data ?? Duration(),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Padding buildLyricViewContainer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Container(
        constraints: BoxConstraints(maxWidth: 900),
        child: StreamBuilder<List<Lyric>>(
          stream: _lyricsController.lyricsStream.stream,
          initialData: _lyricsController.lastLyrics,
          builder: (context, lyricsSnapshot) {
            return StreamBuilder<int>(
              stream: _lyricsController.highlightedLyricIdxStream.stream,
              builder: (context, idxSnapshot) {
                if (idxSnapshot.hasData) {
                  var height = 52.0;
                  _scrollController.animateTo(
                    LyricsView.VERTICAL_PADDING + idxSnapshot.data * height - (MediaQuery.of(context).size.height / 6),
                    duration: Duration(milliseconds: LyricsView.LYRIC_ANIMATION_DURATION),
                    curve: Curves.easeOutCubic,
                  );
                }

                return LyricsView(
                  lyrics: lyricsSnapshot.data ?? [],
                  highlightedLyricIdx: idxSnapshot.data ?? -1,
                  scrollController: _scrollController,
                  lyricTapCallback: (i, lrc) {
                    _currentSongController.seek(lrc.time);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }
}
