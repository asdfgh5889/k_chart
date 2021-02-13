import 'dart:async';

import 'package:flutter/gestures.dart';
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

  final bool showLatestValue;
  final Color latestValueColor;
  final double latestValueWidth;
  final Color latestValueTextColor;
  final double paddingRight;
  final List<TargetPriceModel> targetPrices;
  final ScrollPhysics scrollPhysics;

  ChartContainer(
    this.data, {
    Key key,
    this.scrollPhysics,
    this.targetPrices,
    this.paddingRight,
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
    this.showLatestValue,
    this.latestValueColor,
    this.latestValueWidth,
    this.latestValueTextColor,
    this.dividerColor = const Color(0xff2D4158),
    this.orderMode = false,
    this.resizeMode = false,
  }) : super(key: key);

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
  final PageStorageBucket _bucket = PageStorageBucket();

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

    final editMode = this.widget.orderMode || this.widget.resizeMode;

    return GestureDetector(
      onHorizontalDragDown: editMode
          ? null
          : (details) {
              _stopAnimation();
              _onDragChanged(true);
            },
      onHorizontalDragUpdate: editMode
          ? null
          : (details) {
              if (isScale || isLongPress) return;
              mScrollX = (details.primaryDelta / mScaleX + mScrollX)
                  .clamp(0.0, SingleBaseChartPainter.maxScrollX);
              notifyChanged();
            },
      onHorizontalDragEnd: editMode
          ? null
          : (DragEndDetails details) {
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
      onLongPressStart: editMode
          ? null
          : (details) {
              isLongPress = true;
              if (mSelectX != details.globalPosition.dx) {
                mSelectX = details.globalPosition.dx;
                notifyChanged();
              }
            },
      onLongPressMoveUpdate: editMode
          ? null
          : (details) {
              if (mSelectX != details.globalPosition.dx) {
                mSelectX = details.globalPosition.dx;
                notifyChanged();
              }
            },
      onLongPressEnd: editMode
          ? null
          : (details) {
              isLongPress = false;
              mInfoWindowStream?.sink?.add(null);
              notifyChanged();
            },
      child: Container(
        color: ChartColors.bgColor,
        child:
            PageStorage(bucket: this._bucket, child: _buildChartList(context)),
      ),
    );
  }

  Widget _buildChartList(BuildContext context) {
    if (this.widget.orderMode) {
      return ReorderableColumn(
        key: PageStorageKey("chart_list"),
        onReorder: this.widget.onReorder,
        children: this.widget.order.map((k) => _buildEditableChart(k)).toList(),
      );
    } else {
      return ListView(
        physics: this.widget.scrollPhysics,
        key: PageStorageKey("chart_list"),
        children: this
            .widget
            .order
            .map((k) => this.widget.resizeMode
                ? _buildEditableChart(k)
                : _buildSingleChart(k))
            .toList(),
      );
    }
  }

  double _resizeHeight;
  Key _isResizing;
  Widget _buildEditableChart(Key k) {
    return ClipRRect(
      key: Key(k.toString()),
      child: LayoutBuilder(
        builder: (context, constraint) {
          return Stack(
            children: <Widget>[
              _buildSingleChart(k),
              if (this.widget.orderMode)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: SizedBox(
                    width: constraint.maxWidth,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                          color: Color(
                              0xff18191d), //this.widget.dividerColor.withOpacity(0.5),
                          border: Border(
                            top: BorderSide(
                                color: this.widget.dividerColor, width: 1),
                            left: BorderSide(
                                color: this.widget.dividerColor, width: 1),
                            right: BorderSide(
                                color: this.widget.dividerColor, width: 1),
                          )),
                      child: Icon(
                        Icons.reorder,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (this.widget.resizeMode)
                Positioned(
                    bottom: 0,
                    left: 0,
                    child: _Resizable(
                      key: Key("$k gesture"),
                      onStart: (touch) {
                        _resizeHeight = this.widget.states[k].size.height;
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isResizing = k;
                        });
                      },
                      onUpdate: (dy) {
                        if (_resizeHeight + dy > 100) {
                          this.widget.onResize(
                              k,
                              this.widget.states[k].size.height,
                              _resizeHeight + dy);
                        }
                      },
                      onEnd: (_) => setState(() {
                        _isResizing = null;
                      }),
                      child: Container(
                        height: 40,
                        width: constraint.maxWidth,
                        decoration: BoxDecoration(
                            color: this._isResizing == k
                                ? Color(0xff0B0E1A)
                                : Color(0xff18191d),
                            border: Border(
                              top: BorderSide(
                                  color: this.widget.dividerColor, width: 1),
                              left: BorderSide(
                                  color: this.widget.dividerColor, width: 1),
                              right: BorderSide(
                                  color: this.widget.dividerColor, width: 1),
                            )),
                        child: Icon(
                          Icons.unfold_more,
                          color: Colors.white,
                        ),
                      ),
                    ))
            ],
          );
        },
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
          width: constraint.maxWidth,
          height: this.widget.states[k].size.height,
          padding: EdgeInsets.symmetric(vertical: 1),
          child: CustomPaint(
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
              showLatestValue: this.widget.showLatestValue,
              latestValueColor: this.widget.latestValueColor,
              latestValueWidth: this.widget.latestValueWidth,
              latestValueTextColor: this.widget.latestValueTextColor,
              paddingRight: this.widget.paddingRight,
              targetPrices: this.widget.targetPrices,
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

  @override
  void deactivate() {
    super.deactivate();
  }
}

class _Resizable extends StatefulWidget {
  final Function(LongPressStartDetails) onStart;
  final Function(double) onUpdate;
  final Function(PointerUpEvent) onEnd;
  final Widget child;

  _Resizable({Key key, this.child, this.onStart, this.onUpdate, this.onEnd})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ResizableState();
}

class _ResizableState extends State<_Resizable> {
  bool _resizing = false;
  double _position;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (touch) {
        _resizing = true;
        this.widget.onStart(touch);
        _position = touch.globalPosition.dy;
      },
      child: Listener(
        onPointerMove: (pointer) {
          if (_resizing) {
            this.widget.onUpdate(pointer.position.dy - _position);
          }
        },
        onPointerUp: (pointer) {
          this._resizing = false;
          this.widget.onEnd(pointer);
        },
        onPointerCancel: (_) {
          this._resizing = false;
          this.widget.onEnd(null);
        },
        child: this.widget.child,
      ),
    );
  }
}
