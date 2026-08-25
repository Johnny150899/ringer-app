import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth = 720,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int cacheWidth;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    width: width,
    height: height,
    memCacheWidth: cacheWidth,
    maxWidthDiskCache: cacheWidth * 2,
    fadeInDuration: const Duration(milliseconds: 160),
    placeholder: (_, _) => placeholder ?? const SizedBox.expand(),
    errorWidget: (_, _, _) => errorWidget ?? const SizedBox.expand(),
  );
}
