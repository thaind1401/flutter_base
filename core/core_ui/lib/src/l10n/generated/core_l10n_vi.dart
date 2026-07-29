// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'core_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class CoreL10nVi extends CoreL10n {
  CoreL10nVi([String locale = 'vi']) : super(locale);

  @override
  String get commonOk => 'Đồng ý';

  @override
  String get commonCancel => 'Huỷ';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonSave => 'Lưu';

  @override
  String get commonDelete => 'Xoá';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get commonSearch => 'Tìm kiếm';

  @override
  String get commonLoading => 'Đang tải…';

  @override
  String get commonSeeAll => 'Xem tất cả';

  @override
  String get commonSettings => 'Cài đặt';

  @override
  String get emptyTitle => 'Chưa có dữ liệu';

  @override
  String get emptyDescription => 'Nội dung sẽ hiển thị ở đây khi có dữ liệu.';

  @override
  String get emptySearchTitle => 'Không tìm thấy kết quả';

  @override
  String get emptySearchDescription => 'Hãy thử từ khoá khác.';

  @override
  String get errorGenericTitle => 'Đã có lỗi xảy ra';

  @override
  String get errorGenericMessage => 'Vui lòng thử lại sau ít phút.';

  @override
  String get errorNetworkTitle => 'Mất kết nối';

  @override
  String get errorNetworkMessage => 'Kiểm tra kết nối mạng và thử lại.';

  @override
  String get errorTimeoutTitle => 'Máy chủ phản hồi quá lâu';

  @override
  String get errorTimeoutMessage => 'Máy chủ không phản hồi kịp. Vui lòng thử lại.';

  @override
  String get errorServerTitle => 'Lỗi máy chủ';

  @override
  String get errorServerMessage => 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.';

  @override
  String get errorUnauthorizedTitle => 'Phiên đăng nhập đã hết hạn';

  @override
  String get errorUnauthorizedMessage => 'Vui lòng đăng nhập lại để tiếp tục.';

  @override
  String get errorForbiddenTitle => 'Không có quyền truy cập';

  @override
  String get errorForbiddenMessage => 'Bạn không có quyền thực hiện thao tác này.';

  @override
  String get errorNotFoundTitle => 'Không tìm thấy';

  @override
  String get errorNotFoundMessage => 'Không tìm thấy nội dung bạn cần.';

  @override
  String get errorValidationTitle => 'Vui lòng kiểm tra lại thông tin';

  @override
  String get errorValidationMessage => 'Một số thông tin bạn nhập chưa hợp lệ.';

  @override
  String get errorCacheTitle => 'Lỗi bộ nhớ';

  @override
  String get errorCacheMessage => 'Không đọc được dữ liệu đã lưu trên thiết bị.';

  @override
  String get errorPermissionTitle => 'Cần cấp quyền';

  @override
  String get errorPermissionMessage => 'Hãy cấp quyền cần thiết để tiếp tục.';

  @override
  String get errorPermissionOpenSettings => 'Mở cài đặt';

  @override
  String errorTraceId(String traceId) {
    return 'Mã tra cứu: $traceId';
  }

  @override
  String get formFieldRequired => 'Trường này là bắt buộc';

  @override
  String formFieldTooShort(int min) {
    return 'Tối thiểu $min ký tự';
  }

  @override
  String formFieldTooLong(int max) {
    return 'Tối đa $max ký tự';
  }

  @override
  String get formEmailInvalid => 'Email không hợp lệ';

  @override
  String formPasswordTooShort(int min) {
    return 'Mật khẩu tối thiểu $min ký tự';
  }

  @override
  String get formPasswordMissingUppercase => 'Cần ít nhất một chữ in hoa';

  @override
  String get formPasswordMissingDigit => 'Cần ít nhất một chữ số';

  @override
  String get formPasswordMissingSymbol => 'Cần ít nhất một ký tự đặc biệt';

  @override
  String get formPasswordMismatch => 'Mật khẩu nhập lại không khớp';

  @override
  String get formPhoneInvalid => 'Số điện thoại không hợp lệ';

  @override
  String get connectivityOffline => 'Không có kết nối internet';

  @override
  String get connectivityRestored => 'Đã kết nối lại';

  @override
  String get loadMoreFailed => 'Không tải thêm được';

  @override
  String get pullToRefresh => 'Kéo để làm mới';
}
