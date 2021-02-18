import 'dart:ui';

import 'package:flutter/material.dart';
import '../entity/macd_entity.dart';
import '../k_chart_widget.dart' show SecondaryState;

import 'base_chart_renderer.dart';

class SecondaryRenderer extends BaseChartRenderer<MACDEntity> {
  double mMACDWidth = ChartStyle.macdWidth;
  SecondaryState state;

  SecondaryRenderer(Rect mainRect, double maxValue, double minValue,
      double topPadding, this.state, int fixedLength)
      : super(
            chartRect: mainRect,
            maxValue: maxValue,
            minValue: minValue,
            topPadding: topPadding,
            fixedLength: fixedLength);

  @override
  void drawChart(
    MACDEntity lastPoint,
    MACDEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas, [
    Color color,
  ]) {
    switch (state) {
      case SecondaryState.MACD:
        drawMACD(curPoint, canvas, curX, lastPoint, lastX);
        break;
      case SecondaryState.KDJ:
        drawLine(
            lastPoint.k, curPoint.k, canvas, lastX, curX, ChartColors.kColor);
        drawLine(
            lastPoint.d, curPoint.d, canvas, lastX, curX, ChartColors.dColor);
        drawLine(
            lastPoint.j, curPoint.j, canvas, lastX, curX, ChartColors.jColor);
        break;
      case SecondaryState.RSI:
        drawLine(lastPoint.rsi, curPoint.rsi, canvas, lastX, curX,
            ChartColors.rsiColor);
        break;
      case SecondaryState.WR:
        drawLine(
            lastPoint.r, curPoint.r, canvas, lastX, curX, ChartColors.rsiColor);
        break;
      case SecondaryState.VWAP:
        drawLine(lastPoint.vwap, curPoint.vwap, canvas, lastX, curX,
            ChartColors.rsiColor);
        break;
      default:
        break;
    }
  }

  void drawMACD(MACDEntity curPoint, Canvas canvas, double curX,
      MACDEntity lastPoint, double lastX) {
    double macdY = getY(curPoint.macd);
    double r = mMACDWidth / 2;
    double zeroy = getY(0);
    if (curPoint.macd > 0) {
      canvas.drawRect(Rect.fromLTRB(curX - r, macdY, curX + r, zeroy),
          chartPaint..color = ChartColors.upColor);
    } else {
      canvas.drawRect(Rect.fromLTRB(curX - r, zeroy, curX + r, macdY),
          chartPaint..color = ChartColors.dnColor);
    }
    if (lastPoint.dif != 0) {
      drawLine(lastPoint.dif, curPoint.dif, canvas, lastX, curX,
          ChartColors.difColor);
    }
    if (lastPoint.dea != 0) {
      drawLine(lastPoint.dea, curPoint.dea, canvas, lastX, curX,
          ChartColors.deaColor);
    }
  }

  @override
  void drawText(Canvas canvas, MACDEntity data, double x) {
    List<TextSpan> children;
    switch (state) {
      case SecondaryState.MACD:
        children = [
          TextSpan(
              text: "MACD(12,26,9)    ",
              style: getTextStyle(ChartColors.defaultTextColor)),
          if (data.macd != 0)
            TextSpan(
                text: "MACD:${format(data.macd)}    ",
                style: getTextStyle(ChartColors.macdColor)),
          if (data.dif != 0)
            TextSpan(
                text: "DIF:${format(data.dif)}    ",
                style: getTextStyle(ChartColors.difColor)),
          if (data.dea != 0)
            TextSpan(
                text: "DEA:${format(data.dea)}    ",
                style: getTextStyle(ChartColors.deaColor)),
        ];
        break;
      case SecondaryState.KDJ:
        children = [
          TextSpan(
              text: "KDJ(14,1,3)    ",
              style: getTextStyle(ChartColors.defaultTextColor)),
          if (data.macd != 0)
            TextSpan(
                text: "K:${format(data.k)}    ",
                style: getTextStyle(ChartColors.kColor)),
          if (data.dif != 0)
            TextSpan(
                text: "D:${format(data.d)}    ",
                style: getTextStyle(ChartColors.dColor)),
          if (data.dea != 0)
            TextSpan(
                text: "J:${format(data.j)}    ",
                style: getTextStyle(ChartColors.jColor)),
        ];
        break;
      case SecondaryState.RSI:
        children = [
          TextSpan(
              text: "RSI(14):${format(data.rsi)}    ",
              style: getTextStyle(ChartColors.rsiColor)),
        ];
        break;
      case SecondaryState.WR:
        children = [
          TextSpan(
              text: "WR(14):${format(data.r)}    ",
              style: getTextStyle(ChartColors.rsiColor)),
        ];
        break;
      default:
        break;
    }
    TextPainter tp = TextPainter(
        text: TextSpan(children: children ?? []),
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawRightText(
      Canvas canvas, Rect backgroundRect, TextStyle textStyle, int gridRows) {
    double rowSpace = backgroundRect.height / gridRows;
    for (var i = 0; i <= gridRows; ++i) {
      double value = (gridRows - i) * rowSpace / scaleY + minValue;
      TextSpan span = TextSpan(text: "${format(value)}", style: textStyle);
      TextPainter tp =
          TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      if (i == 0) {
        tp.paint(canvas, Offset(backgroundRect.width - tp.width, topPadding));
      } else {
        tp.paint(
            canvas,
            Offset(backgroundRect.width - tp.width,
                rowSpace * i - tp.height + topPadding));
      }
    }
  }

  @override
  void drawGrid(Canvas canvas, Rect chartRect, int gridRows, int gridColumns,
      [EdgeInsets padding]) {
    double rowSpace = chartRect.height / gridRows;
    for (int i = 0; i <= gridRows; i++) {
      canvas.drawLine(
          Offset(0, rowSpace * i + topPadding),
          Offset(chartRect.width + (padding?.right ?? 0),
              rowSpace * i + topPadding),
          gridPaint);
    }
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= columnSpace; i++) {
      canvas.drawLine(Offset(columnSpace * i, topPadding / 3),
          Offset(columnSpace * i, chartRect.bottom), gridPaint);
    }
  }
}
