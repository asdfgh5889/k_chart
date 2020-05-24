import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:k_chart/chart_container.dart';
import 'package:k_chart/flutter_k_chart.dart';
import 'package:k_chart/k_chart_widget.dart';
import 'package:http/http.dart' as http;
import 'package:k_chart/renderer/single_base_chart_painter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<KLineEntity> data;
  bool showLoading = true;
  bool changeKey = true;
  bool reorder = false;
  bool resize = false;
  bool line = false;
  List<DepthEntity> _bids, _asks;
  Map<Key, SingleBaseChartState> states;
  List<Key> order;

  @override
  void initState() {
    super.initState();
    getData('1day');
    rootBundle.loadString('assets/depth.json').then((result) {
      final parseJson = json.decode(result);
      Map tick = parseJson['tick'];
      var bids = tick['bids']
          .map((item) => DepthEntity(item[0], item[1]))
          .toList()
          .cast<DepthEntity>();
      var asks = tick['asks']
          .map((item) => DepthEntity(item[0], item[1]))
          .toList()
          .cast<DepthEntity>();
      initDepth(bids, asks);
    });
    final charts = [
      SingleMainChartState(isLine: this.line, state: MainState.NONE),
      SingleMainChartState(isLine: this.line, state: MainState.BOLL),
      SingleVolChartState(),
      SingleSecondaryChartState(state: SecondaryState.MACD,),
      SingleSecondaryChartState(state: SecondaryState.KDJ),
      SingleSecondaryChartState(state: SecondaryState.RSI),
      SingleSecondaryChartState(state: SecondaryState.WR),
    ];
    this.order = List.generate(charts.length, (i) => UniqueKey());
    this.states = Map();
    for (int i = 0; i < this.order.length; i++) {
      this.states[this.order[i]] = charts[i];
    }
  }

  void initDepth(List<DepthEntity> bids, List<DepthEntity> asks) {
    if (bids == null || asks == null || bids.isEmpty || asks.isEmpty) return;
    _bids = List();
    _asks = List();
    double amount = 0.0;
    bids?.sort((left, right) => left.price.compareTo(right.price));
    bids.reversed.forEach((item) {
      amount += item.vol;
      item.vol = amount;
      _bids.insert(0, item);
    });

    amount = 0.0;
    asks?.sort((left, right) => left.price.compareTo(right.price));
    asks?.forEach((item) {
      amount += item.vol;
      item.vol = amount;
      _asks.add(item);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff17212F),
      appBar: AppBar(
        actions: <Widget>[
          FlatButton(
            onPressed: () {
              setState(() {
                this.changeKey = !changeKey;
              });
            },
            child: Text("Rebuild"),
          ),
          FlatButton(
            onPressed: () {
              setState(() {
                this.reorder = !this.reorder;
              });
            },
            child: Text("Reorder"),
          ),
          FlatButton(
            onPressed: () {
              setState(() {
                this.resize = !this.resize;
              });
            },
            child: Text("Resize"),
          ),
          FlatButton(
            onPressed: () {
              this.line = !this.line;
              Key key;
              this.states.forEach((k, v) {
                if (v is SingleMainChartState) {
                  key = k;
                }
              });
              if (key != null) {
                setState(() {
                  this.states[key] = (this.states[key] as SingleMainChartState).copyWith(
                    isLine: this.line
                  );
                });
              }
            },
            child: Text("Line"),
          ),
        ],
      ),
      body: SafeArea(
        child: ChartContainer(
          data,
          key: Key("chart_container $changeKey"),
          orderMode: this.reorder,
          resizeMode: this.resize,
          fixedLength: 2,
          timeFormat: TimeFormat.YEAR_MONTH_DAY,
          onReorder: (int oldIndex, int newIndex) {
            final Key item = this.order.removeAt(oldIndex);
            this.order.insert(newIndex, item);
            setState(() {
            });
          },
          onResize: (k, oldHeight, newHeight) {
            setState(() {
              this.states[k].size = Size.fromHeight(newHeight);
            });
          },
          states: this.states,
          order: this.order,
        ),
      ),
    );
  }

  Widget button(String text, {VoidCallback onPressed}) {
    return FlatButton(
        onPressed: () {
          if (onPressed != null) {
            onPressed();
            setState(() {});
          }
        },
        child: Text("$text"),
        color: Colors.blue);
  }

  void getData(String period) {
    Future<String> future = getIPAddress('$period');
    future.then((result) {
      Map parseJson = json.decode(result);
      List list = parseJson['data'];
      data = list
          .map((item) => KLineEntity.fromJson(item))
          .toList()
          .reversed
          .toList()
          .cast<KLineEntity>();
      DataUtil.calculate(data);
      showLoading = false;
      setState(() {});
    }).catchError((_) {
      showLoading = false;
      setState(() {});
    });
  }

  Future<String> getIPAddress(String period) async {
    var url =
        'https://api.huobi.br.com/market/history/kline?period=${period ?? '1day'}&size=300&symbol=btcusdt';
    String result;
    var response = await http.get(url);
    if (response.statusCode == 200) {
      result = response.body;
    } else {
      print('Failed getting IP address');
    }
    return result;
  }
}
