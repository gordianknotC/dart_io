

<!--#-->

撰寫 IO 相關工具，之前想要寫 dart-vue transpiler builder 時準備的，後來沒時間發展.
以下作為封存，只有部份單元測試，不建議使用，版本目前過舊待更新，細部使用見 test。


## 內容
- io.cmd
  - CommonEnv
  - Shell
- io.codecs
  - Img
  - Crypto
- io.glob
  - MGlobMatcher - glob matcher mixin
  - GlobPtnRectifier
- io.path
  - Path
- io.simpleserver
  - WatchServer
- io.walk
  - DirectoryWatcher
  - DirectoryWalker
- io.yamlconfig
  - YamlConfig

## todos
- [V] 更新 dart sdk
- [ ] 更新單元測試 
- [ ] 補 doc


# Table of Content
<!-- START doctoc -->
<!-- END doctoc -->


[tracker]: http://example.com/issues/replaceme
[cmd-test]: ../test/io.cmd.test.dart
[codec-test]: ../test/io.codec.test.dart
[glob-test]: ../test/io.glob.test.dart
[logger-test]: ../test/io.logger.test.dart
[fileio-test]: ../test/fileio.test.dart
[watch-test]: ../test/watchServer.test.dart
[path-test]: ../test/tempPath.test.dart
[yaml-test]: ../test/io.yamlconfig.test.dart
