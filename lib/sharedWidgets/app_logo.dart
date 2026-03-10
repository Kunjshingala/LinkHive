import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 40.0});

  @override
  Widget build(BuildContext context) {
    const String svgString = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <!-- Top Face -->
  <polygon points="11.03,27.5 50,5 88.97,27.5 71.65,37.5 50,25 28.35,37.5" fill="#3D4B5C"/>
  <!-- Right Face -->
  <polygon points="88.97,27.5 88.97,72.5 50,95 50,75 71.65,62.5 71.65,37.5" fill="#324050"/>
  <!-- Left Face -->
  <polygon points="50,95 11.03,72.5 11.03,27.5 28.35,37.5 28.35,62.5 50,75" fill="#273240"/>
  <!-- Center Dot -->
  <circle cx="50" cy="50" r="8" fill="#273240"/>
</svg>
''';

    return SizedBox(
      width: size,
      height: size,
      // If flutter_svg doesn't support SvgPicture.string directly, SvgPicture.memory can be used,
      // but SvgPicture.string is standard.
      child: SvgPicture.string(svgString),
    );
  }
}
