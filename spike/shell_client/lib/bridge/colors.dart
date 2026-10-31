// spike/shell_client/lib/bridge/colors.dart
//
// As cores fixas do Psito que a ponte passa para o compositor e para o GTK.
import 'dart:ui';

const psitoBackground = Color(0xFF12181B);
const psitoSurface = Color(0xFF1E262A);
const psitoText = Color(0xFFE0E0E0);

const psitoBackgroundHex = '#12181B';
const psitoTextHex = '#E0E0E0';

int _channel(double c) => (c * 255).round() & 0xFF;

/// `#RRGGBB`, sem a transparência.
String hexColor(Color color) =>
    '#${[color.r, color.g, color.b].map((c) => _channel(c).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

/// `r g b a` de 0 a 1, como o Wayfire quer.
String wayfireColor(Color color) => [
  color.r,
  color.g,
  color.b,
  color.a,
].map((c) => c.toStringAsFixed(3)).join(' ');

/// Texto legível sobre [color]: o fundo do Psito nas cores claras, branco
/// nas escuras.
Color onColor(Color color) =>
    color.computeLuminance() > 0.35 ? psitoBackground : const Color(0xFFFFFFFF);
