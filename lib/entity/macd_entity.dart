import 'package:k_chart/entity/vwap_entity.dart';

import 'kdj_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';

mixin MACDEntity on KDJEntity, RSIEntity, WREntity, VWAPEntity {
  double dea;
  double dif;
  double macd;
}
