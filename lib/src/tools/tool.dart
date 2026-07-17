import 'package:flutter/widgets.dart';

/// A tool hosted inside the toolbox app.
///
/// Register new tools in [main.dart]'s `tools` list; the side panel and
/// routing are generated from this registry.
class Tool {
  const Tool({
    required this.id,
    required this.name,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String name;

  /// Shown in the side panel. Typically an [Icon] or an [Image] sized ~24px.
  final Widget icon;

  final WidgetBuilder builder;
}
