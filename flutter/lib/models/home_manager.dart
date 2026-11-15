import 'package:brentv/models/filters.dart';
import 'package:brentv/models/node.dart';
import 'package:brentv/models/view_type.dart';

class HomeManager {
  final Filters filters;
  final Node? node;
  HomeManager({required this.filters, this.node});
  static HomeManager defaultManager() {
    return HomeManager(
      filters: Filters(viewType: ViewType.all, page: 1, useKeywords: false),
      node: null,
    );
  }
}
