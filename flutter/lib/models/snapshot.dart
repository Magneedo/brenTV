import 'package:brentv/models/filters.dart';
import 'package:brentv/models/stack.dart';

class Snapshot {
  final Stack stack;
  final Filters filters;
  Snapshot({required this.stack, required this.filters});
}
