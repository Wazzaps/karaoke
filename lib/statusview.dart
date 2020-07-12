import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class StatusMessageView extends StatefulWidget {
  final String message;

  const StatusMessageView(this.message, {Key key}) : super(key: key);

  @override
  _StatusMessageViewState createState() => _StatusMessageViewState();
}

class _StatusMessageViewState extends State<StatusMessageView> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          child: SnowWidget(
            isRunning: true,
            speed: 0.8,
            totalSnow: 15,
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(42.0),
            child: Container(
              color: Color.fromARGB(255, 48, 48, 48),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.message,
                  style: Theme.of(context).textTheme.headline3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SnowWidget extends StatefulWidget {
  final int totalSnow;
  final double speed;
  final bool isRunning;

  SnowWidget({Key key, this.totalSnow, this.speed, this.isRunning}) : super(key: key);

  _SnowWidgetState createState() => _SnowWidgetState();
}

class _SnowWidgetState extends State<SnowWidget> with SingleTickerProviderStateMixin {
  Random _rnd;
  AnimationController controller;
  Animation animation;
  List<Snow> _snows;
  double angle = 0;
  double W = 0;
  double H = 0;
  @override
  void initState() {
    super.initState();
    init();
  }

  init() {
    _rnd = new Random();
    if (controller == null) {
      controller = new AnimationController(
          lowerBound: 0, upperBound: 1, vsync: this, duration: const Duration(milliseconds: 20000));
      controller.addListener(() {
        if (mounted) {
          setState(() {
            update();
          });
        }
      });
    }
    if (!widget.isRunning) {
      controller.stop();
    } else {
      controller.repeat();
    }
  }

  @override
  dispose() {
    controller.dispose();
    super.dispose();
  }

  _createSnow() {
    _snows = new List();
    for (var i = 0; i < widget.totalSnow; i++) {
      _snows.add(new Snow(
          x: _rnd.nextDouble() * W,
          y: _rnd.nextDouble() * H,
          r: _rnd.nextDouble() * 28 + 13,
          d: _rnd.nextDouble() * widget.speed));
    }
  }

  update() {
    // print(" update" + widget.isRunning.toString());
    angle += 0.01;
    if (_snows == null || widget.totalSnow != _snows.length) {
      _createSnow();
    }
    for (var i = 0; i < widget.totalSnow; i++) {
      var snow = _snows[i];
      //We will add 1 to the cos function to prevent negative values which will lead flakes to move upwards
      //Every particle has its own density which can be used to make the downward movement different for each flake
      //Lets make it more random by adding in the radius
      var snowAngle = angle + sin(i / 10);
      snow.y -= (cos(snowAngle + snow.d) + 1 + snow.r / 20) * widget.speed;
      snow.x += sin(snowAngle) * 2 * widget.speed;
      if (snow.x > W + 20 || snow.x < -20 || snow.y < -30) {
        if (i % 3 > 0) {
          //66.67% of the flakes
          _snows[i] = new Snow(x: _rnd.nextDouble() * W, y: H + 30, r: snow.r, d: snow.d);
        } else {
          //If the flake is exitting from the right
          if (sin(snowAngle) > 0) {
            //Enter from the left
            _snows[i] = new Snow(x: -20, y: _rnd.nextDouble() * H, r: snow.r, d: snow.d);
          } else {
            //Enter from the right
            _snows[i] = new Snow(x: W + 20, y: _rnd.nextDouble() * H, r: snow.r, d: snow.d);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRunning && !controller.isAnimating) {
      controller.repeat();
    } else if (!widget.isRunning && controller.isAnimating) {
      controller.stop();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // if (_snows == null) {
        W = constraints.maxWidth;
        H = constraints.maxHeight;
        // }
        return CustomPaint(
          willChange: widget.isRunning,
          painter: SnowPainter(
              // progress: controller.value,
              angle: angle,
              isRunning: widget.isRunning,
              snows: _snows),
          size: Size.infinite,
        );
      },
    );
  }
}

class Snow {
  double x;
  double y;
  double r; //radius
  double d; //density
  Snow({this.x, this.y, this.r, this.d});
}

class SnowPainter extends CustomPainter {
  double angle;
  List<Snow> snows;
  bool isRunning;

  SnowPainter({this.angle, this.isRunning, this.snows});

  @override
  void paint(Canvas canvas, Size size) {
    if (snows == null || !isRunning) return;
    for (var i = 0; i < snows.length; i++) {
      var snow = snows[i];
      if (snow != null) {
        final icon = Icons.music_note;
        var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: snow.r, fontFamily: icon.fontFamily))
          ..pushStyle(
            ui.TextStyle(
              color: Color.fromARGB((100 + min(100, (snow.r - 13) * 150 / 28)).floor(), 255, 255, 255),
            ),
          )
          ..addText(String.fromCharCode(icon.codePoint));
        var para = builder.build();
        para.layout(const ui.ParagraphConstraints(width: 60));
        canvas.save();
        canvas.translate(snow.x, snow.y);
        canvas.rotate(sin(angle) / 3);
        canvas.drawParagraph(para, Offset(0, 0));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(SnowPainter oldDelegate) => isRunning;
}
