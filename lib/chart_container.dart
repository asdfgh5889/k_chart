import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:k_chart/flutter_k_chart.dart';
import 'package:reorderables/reorderables.dart';
import 'chart_style.dart';
import 'entity/info_window_entity.dart';
import 'entity/k_line_entity.dart';
import 'renderer/chart_painter.dart';
import 'utils/date_format_util.dart';
import 'renderer/single_chart_painter.dart';
import 'renderer/single_base_chart_painter.dart';

class ChartContainer extends StatefulWidget {
  final List<KLineEntity> data;
  final List<String> timeFormat;
  final Map<Key, SingleBaseChartState> states;
  final List<Key> order;

  final Function(int oldIndex, int newIndex) onReorder;
  final Function(Key k, double oldHeight, double newHright) onResize;
  final Function(bool) onLoadMore;
  final List<Color> bgColor;
  final int fixedLength;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool) isOnDrag;
  final bool orderMode;
  final bool resizeMode;
  final Color dividerColor;

  ChartContainer(this.data, {
    Key key,
    this.states,
    this.order,
    this.onReorder,
    this.onResize,
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.onLoadMore,
    this.bgColor,
    this.fixedLength,
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.dividerColor = const Color(0xff2D4158),
    this.orderMode = false,
    this.resizeMode = false
  }): super(key: key);

  @override
  _ChartContainerState createState() => _ChartContainerState();
}

class _ChartContainerState extends State<ChartContainer>
    with TickerProviderStateMixin {
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  StreamController<InfoWindowEntity> mInfoWindowStream;
  double mWidth = 0;
  AnimationController _controller;
  Animation<double> aniX;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    mWidth = MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null || widget.data.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    return GestureDetector(
      onHorizontalDragDown: (details) {
        _stopAnimation();
        _onDragChanged(true);
      },
      onHorizontalDragUpdate: (details) {
        if (isScale || isLongPress) return;
        mScrollX = (details.primaryDelta / mScaleX + mScrollX)
            .clamp(0.0, SingleBaseChartPainter.maxScrollX);
        notifyChanged();
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        var velocity = details.velocity.pixelsPerSecond.dx;
        _onFling(velocity);
      },
      onHorizontalDragCancel: () => _onDragChanged(false),
      onScaleStart: (_) {
        isScale = true;
      },
      onScaleUpdate: (details) {
        if (isDrag || isLongPress) return;
        mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
        notifyChanged();
      },
      onScaleEnd: (_) {
        isScale = false;
        _lastScale = mScaleX;
      },
      onLongPressStart: (details) {
        isLongPress = true;
        if (mSelectX != details.globalPosition.dx) {
          mSelectX = details.globalPosition.dx;
          notifyChanged();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (mSelectX != details.globalPosition.dx) {
          mSelectX = details.globalPosition.dx;
          notifyChanged();
        }
      },
      onLongPressEnd: (details) {
        isLongPress = false;
        mInfoWindowStream?.sink?.add(null);
        notifyChanged();
      },
      child: _buildChartList(context),
    );
  }

  Widget _buildChartList(BuildContext context) {
    if (this.widget.orderMode) {
      return ReorderableColumn(
        key: PageStorageKey("chart_list"),
        onReorder: this.widget.onReorder,
        children: this.widget.order.map((k) => _buildReorderableChart(k)).toList(),
      );
    } else if (this.widget.resizeMode) {
      return ListView(
        key: PageStorageKey("chart_list"),
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.all(0),
        children: this.widget.order.map((k) => _buildResizableChart(k)).toList(),
      );
    } else {
      return ListView(
        key: PageStorageKey("chart_list"),
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.all(0),
        children: this.widget.order.map((k) => _buildSingleChart(k)).toList(),
      );
    }
  }

  double _resizeHeight;
  Widget _buildResizableChart(Key k) {
    return ClipRRect(
      key: Key(k.toString()),
      child: Stack(
        children: <Widget>[
          _buildSingleChart(k),
          Positioned(
              bottom: 0,
              left: 0,
              child: GestureDetector(
                onLongPressStart: (touch) {
                  _resizeHeight = this.widget.states[k].size.height;
                  HapticFeedback.selectionClick();
                },
                onLongPressMoveUpdate: (touch) {
                  this.widget.onResize(k, this.widget.states[k].size.height,
                      _resizeHeight + touch.localOffsetFromOrigin.dy);
                },
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: this.widget.dividerColor,
                  ),
                  child: Icon(Icons.unfold_more, color: Colors.white,),
                ),
              )
          )
        ],
      ),
    );
  }

  Widget _buildReorderableChart(Key k) {
    return SizedBox(
      key: Key(k.toString()),
      height: this.widget.states[k].size.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xff18191d),//this.widget.dividerColor.withOpacity(0.5),
                border: Border(
                  top: BorderSide(
                    color: this.widget.dividerColor,
                    width: 1
                  ),
                  bottom: BorderSide(
                    color: this.widget.dividerColor,
                    width: 1
                  ),
                )
              ),
              child: Icon(Icons.reorder, color: Colors.white,),
            ),
          ),
          Expanded(
            child: ClipRRect(
              child: _buildSingleChart(k),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleChart(Key k) {
    return LayoutBuilder(
      key: Key(k.toString()),
      builder: (context, constraint) {
        return Container(
          key: Key(k.toString()),
          color: this.widget.dividerColor,
          padding: EdgeInsets.symmetric(vertical: 1),
          child: CustomPaint(
            size: this.widget.states[k].size,
            painter: SingleChartPainter(
              state: this.widget.states[k],
              constraints: constraint,
              data: widget.data,
              scaleX: mScaleX,
              scrollX: mScrollX,
              selectX: mSelectX,
              isLongPass: isLongPress,
              sink: mInfoWindowStream?.sink,
              bgColor: widget.bgColor,
              fixedLength: widget.fixedLength,
            ),
          ),
        );
      },
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller.isAnimating) {
      _controller.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(
        CurvedAnimation(parent: _controller, curve: widget.flingCurve));
    aniX.addListener(() {
      mScrollX = aniX.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore(true);
        }
        _stopAnimation();
      } else if (mScrollX >= SingleBaseChartPainter.maxScrollX) {
        mScrollX = SingleBaseChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller.forward();
  }

  void notifyChanged() => setState(() {});

  final List<String> infoNamesEN = [
    "Date",
    "Open",
    "High",
    "Low",
    "Close",
    "Change",
    "Change%",
    "Amount"
  ];
  List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity>(
        stream: mInfoWindowStream?.stream,
        builder: (context, snapshot) {
          if (!isLongPress ||
              // TODO: fix isLine condition
              //widget.isLine == true ||
              !snapshot.hasData ||
              snapshot.data.kLineEntity == null) return Container();
          KLineEntity entity = snapshot.data.kLineEntity;
          double upDown = entity.change ?? entity.close - entity.open;
          double upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
          infos = [
            getDate(entity.time),
            entity.open.toStringAsFixed(widget.fixedLength),
            entity.high.toStringAsFixed(widget.fixedLength),
            entity.low.toStringAsFixed(widget.fixedLength),
            entity.close.toStringAsFixed(widget.fixedLength),
            "${upDown > 0 ? "+" : ""}${upDown.toStringAsFixed(widget.fixedLength)}",
            "${upDownPercent > 0 ? "+" : ''}${upDownPercent.toStringAsFixed(2)}%",
            entity.amount.toInt().toString()
          ];
          return Container(
            margin: EdgeInsets.only(
                left: snapshot.data.isLeft ? 4 : mWidth - mWidth / 3 - 4,
                top: 25),
            width: mWidth / 3,
            decoration: BoxDecoration(
                color: ChartColors.selectFillColor,
                border: Border.all(
                    color: ChartColors.selectBorderColor, width: 0.5)),
            child: ListView.builder(
              padding: EdgeInsets.all(4),
              itemCount: infoNamesEN.length,
              itemExtent: 14.0,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                return _buildItem(infos[index], infoNamesEN[index]);
              },
            ),
          );
        });
  }

  Widget _buildItem(String info, String infoName) {
    Color color = Colors.white;
    if (info.startsWith("+"))
      color = Colors.green;
    else if (info.startsWith("-"))
      color = Colors.red;
    else
      color = Colors.white;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
            child: Text("$infoName",
                style: const TextStyle(color: Colors.white, fontSize: 10.0))),
        Text(info, style: TextStyle(color: color, fontSize: 10.0)),
      ],
    );
  }

  String getDate(int date) =>
      dateFormat(DateTime.fromMillisecondsSinceEpoch(date), widget.timeFormat);
}
