import 'dart:math';
export 'package:flutter/material.dart'
    show Color, required, TextStyle, Rect, Canvas, Size, CustomPainter;
import 'package:flutter/material.dart'
    show Color, required, TextStyle, Rect, Canvas, Size, CustomPainter;
import 'package:k_chart/utils/date_format_util.dart';
import '../entity/k_line_entity.dart';
import '../k_chart_widget.dart';
import '../chart_style.dart' show ChartStyle;
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'vol_renderer.dart';
import 'secondary_renderer.dart';
import '../entity/volume_entity.dart';
import '../entity/macd_entity.dart';
import '../entity/candle_entity.dart';

typedef MaxMinValueCalculator(KLineEntity item, int i, SingleBaseChartPainter painter);

abstract class SingleBaseChartPainter extends CustomPainter {
  static double maxScrollX = 0.0;
  SingleBaseChartState state;
  List<KLineEntity> data;
  double scaleX = 1.0, scrollX = 0.0, selectX;
  bool isLongPress = false;

  Rect mRect;
  double mDisplayHeight, mWidth;
  double mTopPadding = 30.0, mBottomPadding = 20.0, mChildPadding = 12.0;
  int mGridRows = 4, mGridColumns = 4;
  int mStartIndex = 0, mStopIndex = 0;
  double mMaxValue = double.minPositive, mMinValue = double.maxFinite;
  double mTranslateX = double.minPositive;
  int mMaxIndex = 0, mMinIndex = 0;
  double mHighMaxValue = double.minPositive,
      mLowMinValue = double.maxFinite;
  int mItemCount = 0;
  double mDataLen = 0.0; //Data accounts for the total length of the screen
  double mPointWidth = ChartStyle.pointWidth;
  List<String> mFormats = [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn]; //Format time

  SingleBaseChartPainter({
    @required this.data,
    @required this.scaleX,
    @required this.scrollX,
    @required this.isLongPress,
    @required this.selectX,
    @required this.state,
  }) {
    mItemCount = data?.length ?? 0;
    mDataLen = mItemCount * mPointWidth;
    initFormats();
  }

  void initFormats() {
//    [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn]
    if (mItemCount < 2) return;
    int firstTime = data.first?.time ?? 0;
    int secondTime = data[1]?.time ?? 0;
    int time = secondTime - firstTime;
    time ~/= 1000;
    //月线
    if (time >= 24 * 60 * 60 * 28)
      mFormats = [yy, '-', mm];
    //日线等
    else if (time >= 24 * 60 * 60)
      mFormats = [yy, '-', mm, '-', dd];
    //小时线等
    else
      mFormats = [mm, '-', dd, ' ', HH, ':', nn];
  }

  @override
  void paint(Canvas canvas, Size size) {
    mDisplayHeight = size.height - mTopPadding - mBottomPadding;
    mWidth = size.width;
    initRect(size);
    calculateValue();
    initChartRenderer();

    canvas.save();
    canvas.scale(1, 1);
    drawBg(canvas, size);
    drawGrid(canvas);
    if (data != null && data.isNotEmpty) {
      drawChart(canvas, size);
      drawRightText(canvas);
      drawDate(canvas, size);
      if (isLongPress == true) drawCrossLineText(canvas, size);
      drawText(canvas, data?.last, 5);
      drawMaxAndMin(canvas);
    }
    canvas.restore();
  }

  void initChartRenderer();

  //Background
  void drawBg(Canvas canvas, Size size);

  //Grid
  void drawGrid(canvas);

  //Chart
  void drawChart(Canvas canvas, Size size);

  //Right text
  void drawRightText(canvas);

  //Date
  void drawDate(Canvas canvas, Size size);

  //Text
  void drawText(Canvas canvas, KLineEntity data, double x);

  //Draw maximum and minimum
  void drawMaxAndMin(Canvas canvas);

  //Cross line value
  void drawCrossLineText(Canvas canvas, Size size);

  void initRect(Size size) {
    mRect = Rect.fromLTRB(0, mTopPadding, mWidth, mTopPadding + mDisplayHeight);
  }

  calculateValue() {
    if (data == null || data.isEmpty) return;
    maxScrollX = getMinTranslateX().abs();
    setTranslateXFromScrollX(scrollX);
    mStartIndex = indexOfTranslateX(xToTranslateX(0));
    mStopIndex = indexOfTranslateX(xToTranslateX(mWidth));
    for (int i = mStartIndex; i <= mStopIndex; i++) {
      var item = data[i];
      this.state.maxMinValue(item, i, this);
    }
  }

  double _findMaxMA(List<double> a) {
    double result = double.minPositive;
    for (double i in a) {
      result = max(result, i);
    }
    return result;
  }

  double _findMinMA(List<double> a) {
    double result = double.maxFinite;
    for (double i in a) {
      result = min(result, i == 0 ? double.maxFinite : i);
    }
    return result;
  }

  double xToTranslateX(double x) => -mTranslateX + x / scaleX;

  int indexOfTranslateX(double translateX) =>
      _indexOfTranslateX(translateX, 0, mItemCount - 1);

  ///Binary search for the index of the current value
  int _indexOfTranslateX(double translateX, int start, int end) {
    if (end == start || end == -1) {
      return start;
    }
    if (end - start == 1) {
      double startValue = getX(start);
      double endValue = getX(end);
      return (translateX - startValue).abs() < (translateX - endValue).abs()
          ? start
          : end;
    }
    int mid = start + (end - start) ~/ 2;
    double midValue = getX(mid);
    if (translateX < midValue) {
      return _indexOfTranslateX(translateX, start, mid);
    } else if (translateX > midValue) {
      return _indexOfTranslateX(translateX, mid, end);
    } else {
      return mid;
    }
  }

  ///Get the x coordinate according to the index
  ///+ mPointWidth / 2 Prevent the first and last k-line from displaying
  ///@param position Index value
  double getX(int position) => position * mPointWidth + mPointWidth / 2;

  Object getItem(int position) {
    if (data != null) {
      return data[position];
    } else {
      return null;
    }
  }

  ///scrollX 转换为 TranslateX
  void setTranslateXFromScrollX(double scrollX) {
    mTranslateX = scrollX + getMinTranslateX();
  }

  ///获取平移的最小值
  double getMinTranslateX() {
    var x = -mDataLen + mWidth / scaleX - mPointWidth / 2;
    return x >= 0 ? 0.0 : x;
  }

  ///计算长按后x的值，转换为index
  int calculateSelectedX(double selectX) {
    int mSelectedIndex = indexOfTranslateX(xToTranslateX(selectX));
    if (mSelectedIndex < mStartIndex) {
      mSelectedIndex = mStartIndex;
    }
    if (mSelectedIndex > mStopIndex) {
      mSelectedIndex = mStopIndex;
    }
    return mSelectedIndex;
  }

  ///translateX转化为view中的x
  double translateXtoX(double translateX) =>
      (translateX + mTranslateX) * scaleX;

  TextStyle getTextStyle(Color color) {
    return TextStyle(fontSize: 10.0, color: color);
  }

  @override
  bool shouldRepaint(SingleBaseChartPainter oldDelegate) {
    return true;
  }
}

abstract class SingleBaseChartState<T> {
  MaxMinValueCalculator get maxMinValue;
  Size get size;
  set size(Size s);
  bool get drawCrossLine => false;
  bool get drawMinMax => true;

  BaseChartRenderer<T> getRenderer(Rect rect, double maxValue, double minValue,
      double topPadding, int fixedLength);
}

class SingleMainChartState extends SingleBaseChartState {
  MainState state;
  bool isLine;
  List<int> maDayList;
  Size _size;
  @override
  Size get size => this._size ?? Size(double.infinity, 300);
  @override
  set size(Size s) => this._size = s;
  bool get drawCrossLine => true;
  bool get drawMinMax => !isLine;

  SingleMainChartState({
    this.state = MainState.MA,
    this.isLine = false,
    this.maDayList = const [5, 10, 20],
    Size size
  }): this._size = size;

  @override
  BaseChartRenderer getRenderer(Rect rect, double maxValue, double minValue,
      double topPadding, int fixedLength) {
    return MainRenderer(rect, maxValue, minValue, topPadding, state, isLine, fixedLength, maDayList);
  }

  @override
  MaxMinValueCalculator get maxMinValue => (KLineEntity item, int i, SingleBaseChartPainter painter) {
    if (isLine == true) {
      painter.mMaxValue = max(painter.mMaxValue, item.close);
      painter.mMinValue = min(painter.mMinValue, item.close);
    } else {
      double maxPrice, minPrice;
      if (state == MainState.MA) {
        maxPrice = max(item.high, painter._findMaxMA(item.maValueList));
        minPrice = min(item.low, painter._findMinMA(item.maValueList));
      } else if (state == MainState.BOLL) {
        maxPrice = max(item.up ?? 0, item.high);
        minPrice = min(item.dn ?? 0, item.low);
      } else {
        maxPrice = item.high;
        minPrice = item.low;
      }
      painter.mMaxValue = max(painter.mMaxValue, maxPrice);
      painter.mMinValue = min(painter.mMinValue, minPrice);

      if (painter.mHighMaxValue < item.high) {
        painter.mHighMaxValue = item.high;
        painter.mMaxIndex = i;
      }
      if (painter.mLowMinValue > item.low) {
        painter.mLowMinValue = item.low;
        painter.mMinIndex = i;
      }
    }
  };
}

class SingleSecondaryChartState extends SingleBaseChartState {
  SecondaryState state;
  Size _size;
  Size get size => this._size ?? Size(double.infinity, 150);
  @override
  set size(Size s) => this._size = s;

  SingleSecondaryChartState({
    this.state = SecondaryState.MACD,
    Size size,
  }): _size = size;

  @override
  BaseChartRenderer getRenderer(Rect rect, double maxValue, double minValue,
      double topPadding, int fixedLength) {
    return SecondaryRenderer(rect, maxValue, minValue, topPadding, state, fixedLength);
  }

  MaxMinValueCalculator get maxMinValue => (KLineEntity item, int i, SingleBaseChartPainter painter) {
    if (state == SecondaryState.MACD) {
      painter.mMaxValue = max(painter.mMaxValue, max(item.macd, max(item.dif, item.dea)));
      painter.mMinValue = min(painter.mMinValue, min(item.macd, min(item.dif, item.dea)));
    } else if (state == SecondaryState.KDJ) {
      if (item.d != null) {
        painter.mMaxValue = max(painter.mMaxValue, max(item.k, max(item.d, item.j)));
        painter.mMinValue = min(painter.mMinValue, min(item.k, min(item.d, item.j)));
      }
    } else if (state == SecondaryState.RSI) {
      if (item.rsi != null) {
        painter.mMaxValue = max(painter.mMaxValue, item.rsi);
        painter.mMinValue = min(painter.mMinValue, item.rsi);
      }
    } else if (state == SecondaryState.WR) {
      painter.mMaxValue = 0;
      painter.mMinValue = -100;
    } else {
      painter.mMaxValue = 0;
      painter.mMinValue = 0;
    }
  };
}

class SingleVolChartState extends SingleBaseChartState {
  Size _size;
  Size get size => this._size ?? Size(double.infinity, 150);
  @override
  set size(Size s) => this._size = s;

  SingleVolChartState({Size size}): _size = size;

  @override
  BaseChartRenderer getRenderer(Rect rect, double maxValue, double minValue,
      double topPadding, int fixedLength) {
    return VolRenderer(rect, maxValue, minValue, topPadding, fixedLength);
  }

  MaxMinValueCalculator get maxMinValue => (KLineEntity item, int i, SingleBaseChartPainter painter) {
    painter.mMaxValue = max(painter.mMaxValue, max(item.vol, max(item.MA5Volume ?? 0, item.MA10Volume ?? 0)));
    painter.mMinValue = min(painter.mMinValue, min(item.vol, min(item.MA5Volume ?? 0, item.MA10Volume ?? 0)));
  };
}