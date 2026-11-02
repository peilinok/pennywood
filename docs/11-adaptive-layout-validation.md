# Adaptive Orientation and Window Validation

The iPhone supports portrait and both landscapes. iPad supports four orientations with `UIRequiresFullScreen=false`. Only iOS is generated.

## Layout contract

`SafeArea` and `LayoutBuilder` reflow from actual available dimensions. Use a sidebar only with sufficient width/height and moderate text size; otherwise use bottom navigation. Quick tasks use five, three, or two columns according to content width. Narrow layouts scroll rather than shrink text. Reuse controller/widget state during orientation changes.

Ordinary input, page, child, and ledger survive orientation, keyboard, and window changes. Leaving the foreground relocks the parent and clears/conceals secrets while preserving ordinary fields. Secret protection is a lifecycle behavior, not a rotation reset.

## Existing evidence

The 0.3.5 production package was checked on iOS 18.1 simulators at iPhone 402 x 874 / 874 x 402 and iPad 834 x 1210 / 1210 x 834, including upside-down portrait. Native XCTest rotated the OS and verified unfinished forms and current page. Actual iPad split view with Safari changed app width 1210 -> 600 -> 1210 pt without losing input. Upgrade installation/system checks retained all 16 production tables and historical ledger rows.

Widget tests cover five window sizes, light/dark, 200% text, software keyboard, and repeated reflow. These do not prove system split view. Additional physical production-main rotation was not executed after devices locked; do not report it as passed. The 0.3.6 round did not repeat the complete orientation/window suite.

## Further acceptance

Divider dragging, complete physical orientations/windows, iPadOS 26 window behavior, human VoiceOver, and actual system large-text settings remain pending. Preserve OS action records and isolated test ledgers. Reopening a widget is not continuous state-retention proof; never clear real families for a test.

Manually rotate using the simulator Device menu or enter iPad split view using available system multitasking controls. Verify unchanged child/page/input/payment checkbox/ledger and accessible save/back controls around safe areas and keyboard. See [native validation](10-native-validation.md).
