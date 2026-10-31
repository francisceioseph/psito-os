// spike/shell_client/lib/size_reporter.dart
//
// Avisa o tamanho do filho depois de cada layout em que ele mudou.
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class SizeReporter extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSize;

  const SizeReporter({super.key, required this.onSize, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class RenderSizeReporter extends RenderProxyBox {
  RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    _reported = size;
    // Fora do layout: quem recebe pode mexer na árvore
    SchedulerBinding.instance.addPostFrameCallback((_) => onSize(size));
  }
}
