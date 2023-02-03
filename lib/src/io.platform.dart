library io_simple;

export 'sketch/io.platform.loader.dart'
if (dart.library.io) 'mobile/io.platform.mobile.dart'
if (dart.library.html) 'web/io.platform.web.dart';