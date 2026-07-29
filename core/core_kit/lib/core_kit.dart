/// Pure-Dart foundation shared by every other package.
///
/// Rule: nothing here may import `package:flutter/*`. If a helper needs a
/// `BuildContext`, a `Color` or a `Widget`, it belongs in `core_ui`.
library core_kit;

export 'package:formz/formz.dart' show Formz, FormzInput, FormzSubmissionStatus;

export 'src/config/app_environment.dart';
export 'src/connectivity/connectivity_monitor.dart';
export 'src/error/app_exception.dart';
export 'src/error/failure.dart';
export 'src/error/failure_mapper.dart';
export 'src/extensions/datetime_x.dart';
export 'src/extensions/iterable_x.dart';
export 'src/extensions/num_x.dart';
export 'src/extensions/string_x.dart';
export 'src/forms/form_inputs.dart';
export 'src/logging/app_logger.dart';
export 'src/logging/log_redactor.dart';
export 'src/pagination/paged_list.dart';
export 'src/result/result.dart';
export 'src/result/unit.dart';
export 'src/utils/debouncer.dart';
