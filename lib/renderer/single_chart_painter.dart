import 'dart:async' show StreamSink;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:k_chart/utils/number_util.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import '../entity/info_window_entity.dart';

import 'single_base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

class SingleChartPainter extends SingleBaseChartPainter {
  static get maxScrollX => SingleBaseChartPainter.maxScrollX;
  BaseChartRenderer renderer;
  StreamSink<InfoWindowEntity> sink;
  List<Color> bgColor;
  int fixedLength;
  double paddingRight;

  final bool showLatestValue;
  final Color latestValueColor;
  final double latestValueWidth;
  final Color latestValueTextColor;

  SingleChartPainter({
    @required data,
    @required scaleX,
    @required scrollX,
    @required isLongPass,
    @required double selectX,
    @required SingleBaseChartState state,
    this.showLatestValue = false,
    this.latestValueColor = Colors.amber,
    this.latestValueWidth = 2,
    this.latestValueTextColor = Colors.white,
    double paddingRight = 0,
    BoxConstraints constraints,
    this.sink,
    this.bgColor,
    this.fixedLength,
  })  : assert(bgColor == null || bgColor.length >= 2),
        super(
          data: data,
          scaleX: scaleX,
          scrollX: scrollX,
          isLongPress: isLongPass,
          selectX: selectX,
          state: state,
          paddingRight: paddingRight,
        ) {
    this.paddingRight = paddingRight;
    if (constraints != null && constraints.maxWidth != 0) {
      final gridRatio = 3 / 4;
      this.mGridColumns = 4;
      this.mGridRows = max(
          (state.size.height *
                  this.mGridColumns /
                  (gridRatio * constraints.maxWidth))
              .floor(),
          1);
    }
  }

  @override
  void initChartRenderer() {
    if (fixedLength == null) {
      if (data == null || data.isEmpty) {
        fixedLength = 2;
      } else {
        var t = data[0];
        fixedLength =
            NumberUtil.getMaxDecimalLength(t.open, t.close, t.high, t.low);
      }
    }
    this.renderer ??= this
        .state
        .getRenderer(mRect, mMaxValue, mMinValue, mTopPadding, fixedLength);
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    Paint mBgPaint = Paint();
    Gradient mBgGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: bgColor ?? [Color(0xff18191d), Color(0xff18191d)],
    );
    if (mRect != null) {
      Rect mainRect = Rect.fromLTRB(
          0, 0, mRect.width + this.paddingRight, mRect.height + mTopPadding);
      canvas.drawRect(
          mainRect, mBgPaint..shader = mBgGradient.createShader(mainRect));
    }
    Rect dateRect =
        Rect.fromLTRB(0, size.height - mBottomPadding, size.width, size.height);
    canvas.drawRect(
        dateRect, mBgPaint..shader = mBgGradient.createShader(dateRect));
  }

  @override
  void drawGrid(Canvas canvas, Rect chartRect, [EdgeInsets padding]) {
    renderer?.drawGrid(canvas, chartRect, mGridRows, mGridColumns, padding);
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate((mTranslateX) * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);
    for (int i = mStartIndex; data != null && i <= mStopIndex; i++) {
      KLineEntity curPoint = data[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : data[i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);
      renderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
    }

    if (this.showLatestValue) {
      drawCrossLine(canvas, size, this.data.length - 1,
          drawVertical: false,
          color: this.latestValueColor,
          width: this.latestValueWidth);
    }

    if (isLongPress == true) {
      var index = calculateSelectedX(selectX);
      drawCrossLine(canvas, size, index);
    }
    canvas.restore();

    if (this.showLatestValue) {
      drawCrossLineTextFor(canvas, size, this.data.length - 1,
          drawDate: false,
          tagColor: this.latestValueColor,
          textColor: this.latestValueTextColor);
    }
  }

  @override
  void drawRightText(Canvas canvas, Rect backgraoundRect) {
    var textStyle = getTextStyle(ChartColors.defaultTextColor);
    renderer?.drawRightText(canvas, backgraoundRect, textStyle, mGridRows);
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    double columnSpace = size.width / mGridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double y = 0.0;
    for (var i = 0; i <= mGridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);
      if (translateX >= startX && translateX <= stopX) {
        int index = indexOfTranslateX(translateX);
        if (data[index] == null) continue;
        TextPainter tp = getTextPainter(getDate(data[index].time));
        y = size.height - (mBottomPadding - tp.height) / 2 - tp.height;
        tp.paint(canvas, Offset(columnSpace * i - tp.width / 2, y));
      }
    }
  }

  Paint selectPointPaint = Paint()
    ..isAntiAlias = true
    ..strokeWidth = 0.5
    ..color = ChartColors.selectFillColor;
  Paint selectorBorderPaint = Paint()
    ..isAntiAlias = true
    ..strokeWidth = 0.5
    ..style = PaintingStyle.stroke
    ..color = ChartColors.selectBorderColor;

  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);
    final isLeft = drawCrossLineTextFor(
      canvas,
      size,
      index,
    );

    //长按显示这条数据详情
    sink?.add(InfoWindowEntity(point, isLeft));
  }

  bool drawCrossLineTextFor(
    Canvas canvas,
    Size size,
    int index, {
    bool drawDate = true,
    Color textColor,
    Color tagColor,
  }) {
    canvas.save();
    KLineEntity point = getItem(index);

    TextPainter tp = getTextPainter(point.close, textColor ?? Colors.white);
    double textHeight = tp.height;
    double textWidth = tp.width;

    double w1 = 5;
    double w2 = 3;
    double r = textHeight / 2 + w2;
    double y = getMainY(point.close);
    double x;
    bool isLeft = false;
    final selectPointPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..color = tagColor ?? ChartColors.selectFillColor;
    final selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..color = tagColor ?? ChartColors.selectBorderColor;

    if (y < this.mTopPadding) {
      y = this.mTopPadding;
    }

    if (y > size.height) {
      y = size.height - this.mBottomPadding;
    }
    if (state.drawCrossLine) {
      if (translateXtoX(getX(index)) < mWidth / 2) {
        isLeft = false;
        x = 1;
        Path path = new Path();
        path.moveTo(x, y - r);
        path.lineTo(x, y + r);
        path.lineTo(textWidth + 2 * w1, y + r);
        path.lineTo(textWidth + 2 * w1 + w2, y);
        path.lineTo(textWidth + 2 * w1, y - r);
        path.close();
        canvas.drawPath(path, selectPointPaint);
        canvas.drawPath(path, selectorBorderPaint);
        tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
      } else {
        isLeft = true;
        x = mWidth - textWidth - 1 - 2 * w1 - w2;
        Path path = new Path();
        path.moveTo(x, y);
        path.lineTo(x + w2, y + r);
        path.lineTo(mWidth - 2, y + r);
        path.lineTo(mWidth - 2, y - r);
        path.lineTo(x + w2, y - r);
        path.close();
        canvas.drawPath(path, selectPointPaint);
        canvas.drawPath(path, selectorBorderPaint);
        tp.paint(canvas, Offset(x + w1 + w2, y - textHeight / 2));
      }
    }

    if (drawDate) {
      TextPainter dateTp = getTextPainter(getDate(point.time), Colors.white);
      textWidth = dateTp.width;
      r = textHeight / 2;
      x = translateXtoX(getX(index));
      y = size.height - mBottomPadding;

      if (x < textWidth + 2 * w1) {
        x = 1 + textWidth / 2 + w1;
      } else if (mWidth - x < textWidth + 2 * w1) {
        x = mWidth - 1 - textWidth / 2 - w1;
      }
      double baseLine = textHeight / 2;
      canvas.drawRect(
          Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
              y + baseLine + r),
          selectPointPaint);
      canvas.drawRect(
          Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
              y + baseLine + r),
          selectorBorderPaint);

      dateTp.paint(canvas, Offset(x - textWidth / 2, y));
    }
    canvas.restore();
    return isLeft;
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    //长按显示按中的数据
    if (isLongPress) {
      var index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    //松开显示最后一条数据
    renderer?.drawText(canvas, data, x);
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (!state.drawMinMax) {
      return;
    }

    //绘制最大值和最小值
    double x = translateXtoX(getX(mMinIndex));
    double y = getMainY(mLowMinValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mLowMinValue.toStringAsFixed(fixedLength), Colors.white);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mLowMinValue.toStringAsFixed(fixedLength) + " ──", Colors.white);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
    x = translateXtoX(getX(mMaxIndex));
    y = getMainY(mHighMaxValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mHighMaxValue.toStringAsFixed(fixedLength), Colors.white);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mHighMaxValue.toStringAsFixed(fixedLength) + " ──", Colors.white);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
  }

  ///画交叉线
  void drawCrossLine(
    Canvas canvas,
    Size size,
    int index, {
    bool drawVertical = true,
    Color color,
    double width,
  }) {
    //var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);

    double x = getX(index);
    double y = getMainY(point.close);

    if (y < this.mTopPadding) {
      y = this.mTopPadding;
    }

    if (y > size.height) {
      y = size.height - this.mBottomPadding;
    }

    if (drawVertical) {
      Paint paintY = Paint()
        ..color = Colors.white12
        ..strokeWidth = ChartStyle.vCrossWidth
        ..isAntiAlias = true;

      // k线图竖线
      canvas.drawLine(Offset(x, mTopPadding),
          Offset(x, size.height - mBottomPadding), paintY);
    }

    if (state.drawCrossLine) {
      Paint paintX = Paint()
        ..color = color ?? Colors.white
        ..strokeWidth = width ?? ChartStyle.hCrossWidth
        ..isAntiAlias = true;
      // k线图横线
      canvas.drawLine(Offset(-mTranslateX, y),
          Offset(-mTranslateX + mWidth / scaleX, y), paintX);
      canvas.drawCircle(Offset(x, y), 2.0, paintX);
    }
  }

  TextPainter getTextPainter(text, [color = ChartColors.defaultTextColor]) {
    TextSpan span = TextSpan(text: "$text", style: getTextStyle(color));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  String getDate(int date) =>
      dateFormat(DateTime.fromMillisecondsSinceEpoch(date), mFormats);

  double getMainY(double y) => renderer?.getY(y) ?? 0.0;
}
