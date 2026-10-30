# TuTime chấm công

TuTime là ứng dụng Flutter chấm công cho nhân viên. Ba chức năng trình bày đã chọn là **chia sẻ vị trí GPS (b)**, **đo áp suất khí quyển (d)** và **nhận diện QR (e)**. Nhân viên quét QR cố định của công ty; app lưu tọa độ, sai số GPS và khoảng cách tới văn phòng. Bán kính không chặn lượt chấm công.

**Tính năng đề xuất:** Xin đi muộn/về sớm. Nhân viên gửi đơn theo ngày, thời gian và lý do; admin duyệt hoặc từ chối. Lịch sử chấm công hiển thị nhãn khi lượt vào/tan ca phù hợp với đơn đã được duyệt.

Project Flutter mang tên cá nhân `LEDOANVANTU2`. Kho này chứa cả frontend Flutter trong `lib/` và backend ASP.NET Core trong `backend/LEDOANVANTU2.Api/`. Ứng dụng Flutter Android được build từ `android/`.

## Các chức năng đã bổ sung

- Đăng ký và xác nhận OTP thành công tự tạo hồ sơ nhân viên trong danh sách của admin. Nếu đã có hồ sơ thủ công khớp họ tên/email, hệ thống dùng lại hồ sơ đó.
- Admin thêm thủ công có thể tạo cả tài khoản đăng nhập bằng tên đăng nhập và mật khẩu ban đầu; nhân viên đăng nhập bằng tên đăng nhập hoặc email rồi xác nhận OTP, không cần đăng ký lại.
- Tài khoản đã xác nhận được liên kết theo họ tên/email mà không đổi mật khẩu; cập nhật số nhân viên có mặt từ lượt chấm công thực tế.
- Cả nhân viên và quản trị viên có mục **Quét / đăng ký khuôn mặt** tại Tổng quan và Tài khoản; camera trích đặc trưng, API mã hóa mẫu và đối chiếu khuôn mặt trong phiên OTP còn hiệu lực.
- Cài đặt đổi cỡ chữ, màu nền và cập nhật họ tên; họ tên được đồng bộ với hồ sơ nhân viên đã liên kết.
- Biểu đồ áp suất trong 5 phút, thống kê thấp nhất/cao nhất/trung bình, tạm dừng và đo lại.
- Gửi và duyệt đơn xin đi muộn/về sớm; xem trạng thái và đối chiếu với lịch sử chấm công.
- Sửa luồng lưu nhân viên, hủy chấm công và tính tổng giờ làm theo dữ liệu thực tế.

Danh sách chức năng ngắn gọn nằm trong [Lê Đoàn Văn Tú.txt](L%C3%AA%20%C4%90o%C3%A0n%20V%C4%83n%20T%C3%BA.txt). Điểm trong file là tự đánh giá tham khảo.

## Chạy Flutter

Đặt dự án ở đường dẫn không dấu, ví dụ `C:\Projects\TuTime`, để tránh lỗi đường dẫn của Java/aapt trên Windows. Khởi động giả lập và dùng `flutter devices` kiểm tra mã thiết bị trước khi chạy:

```powershell
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://ledoanvantu2-api.onrender.com --dart-define=OFFICE_LAT=10.7769 --dart-define=OFFICE_LNG=106.7009 --dart-define=OFFICE_RADIUS_M=150
```

Thay `emulator-5554` bằng mã thiết bị thực tế. Không thêm dấu `\` ở cuối lệnh PowerShell và chỉ chạy một phiên `flutter run` cho cùng thiết bị. Cấu hình debug tắt Impeller; Gradle giới hạn heap 3 GB và tự dừng daemon sau 2 phút không hoạt động để giảm tải khi chạy giả lập.

App mặc định kết nối API đã deploy tại Render. Nếu nhóm có API riêng, truyền `--dart-define=API_BASE_URL=https://...` khi chạy/build. Chế độ demo ngoại tuyến chỉ bật khi chủ động truyền `--dart-define=API_BASE_URL=`; dữ liệu demo không tạo tài khoản thật và CRUD chỉ lưu trong bộ nhớ.

Khi API đã deploy, nhân viên đăng ký bằng email, username và mật khẩu; backend gửi OTP qua email. Đăng nhập dùng username, mật khẩu và OTP. Vai trò nhận từ token backend; tài khoản mới là `Employee`. Tài khoản admin được khởi tạo riêng bằng các biến `BootstrapAdmin__...` trên Render.

Sau khi đăng nhập bằng mật khẩu và OTP, có thể đăng ký khuôn mặt để mở lại phiên trên thiết bị đã đăng ký khi phiên API còn hiệu lực. Phiên hết hạn sau 8 giờ, đã đăng xuất hoặc sai khuôn mặt 5 lần thì cần đăng nhập OTP lại. Camera trích đặc trưng, API mã hóa mẫu bằng AES-GCM và so sánh đặc trưng; thiết bị chỉ giữ thông tin phiên trong secure storage. Đây là nhận diện camera phục vụ demo, chưa có cơ chế chống ảnh/video giả mạo. Trên giả lập, cấu hình camera trước dùng webcam laptop; GPS và áp suất của giả lập là dữ liệu mô phỏng.

### API cho chức năng thiết bị và đăng xuất

- `POST /api/Auth/logout`: vô hiệu hóa token hiện tại; token đó bị từ chối trên các API yêu cầu đăng nhập.
- `GET /api/Face`, `POST /api/Face/enroll`, `POST /api/Face/verify`, `DELETE /api/Face`: trạng thái, đăng ký, đối chiếu và xóa mẫu khuôn mặt. Cần token OTP còn hiệu lực, không cấp mới hay gia hạn token bằng mẫu khuôn mặt.
- `GET/POST /api/Locations`: lịch sử vị trí của tài khoản, lưu GPS/sai số và tạo liên kết Google Maps để Flutter mở bảng chia sẻ của hệ điều hành.
- `GET/POST /api/Pressure`: lưu cửa sổ số đo tối đa 600 mẫu, tính thấp nhất/cao nhất/trung bình và cảnh báo biến động từ 2 hPa; Flutter đồng bộ cửa sổ 5 phút khi đang đo.
- `GET/PUT /api/Settings`: lưu và tải cỡ chữ, màu nền theo tài khoản. Trong Cài đặt, bấm **Lưu giao diện vào tài khoản** sau khi chọn.

Swagger có nút **Authorize**: nhập `accessToken` sau khi xác nhận OTP để thử các API có khóa. Camera, GPS và cảm biến vẫn thu dữ liệu trên điện thoại; xử lý/lưu dữ liệu của các mục trên đã nối với backend. Các API này chỉ trả dữ liệu của tài khoản đang đăng nhập. Không cần đổi link Swagger đã nộp khi triển khai bản mới.

### Thêm nhân viên và tài khoản

- **Nhân viên tự đăng ký:** hoàn tất OTP đăng ký để tự xuất hiện trong danh sách nhân viên của admin; mã nhân viên được cấp tự động, không cần admin thêm lại.
- **Admin thêm thủ công:** nhập họ tên, email, mã nhân viên, chức vụ và mật khẩu ban đầu. Tên đăng nhập có thể tự đặt hoặc để trống để dùng mã nhân viên. Admin cung cấp thông tin đăng nhập cho nhân viên; lần đầu đăng nhập vẫn nhận OTP qua email.
- **Email đã có tài khoản xác nhận:** họ tên phải khớp; dùng lại tài khoản và mật khẩu hiện có. Nếu hồ sơ nhân viên đã tồn tại, sửa hồ sơ sẵn có thay vì thêm trùng.
- Tài khoản do admin tạo chưa xác nhận email cần giữ nguyên email cho đến khi hoàn tất lần đăng nhập OTP đầu tiên.

Kiểm tra backend bằng `dotnet test backend/LEDOANVANTU2.Api.Tests/LEDOANVANTU2.Api.Tests.csproj`. Bộ test dùng SQLite tạm trong bộ nhớ, không gửi email và không sửa dữ liệu Render.

Admin mở **Tài khoản → Mã QR công ty cố định** để hiển thị mã. Nhân viên có thể quét bằng camera, chọn ảnh QR đã lưu, hoặc trong một giả lập dùng nút **Dùng QR demo đã lưu trong app** để kiểm tra giải mã ảnh QR. QR cố định có thể bị sao chép; app lưu GPS và khoảng cách để admin đối soát, không chặn theo bán kính. Tọa độ văn phòng hiện dùng là tọa độ mẫu ở TP.HCM (`10.7769`, `106.7009`); thay `Office__Latitude`, `Office__Longitude` trên Render và dùng cùng giá trị `OFFICE_LAT`/`OFFICE_LNG` khi build APK để tính khoảng cách chính xác.

Mục d mở tại **Tài khoản → Đo áp suất không khí**. Trên Android Emulator, mở **⋮ → Virtual sensors → Additional sensors → Pressure** để thay đổi giá trị cảm biến mô phỏng. Một đăng ký chưa xác nhận có thể gửi lại cùng email và tên đăng nhập để nhận OTP mới; OTP đăng ký/đăng nhập hết hạn sau 5 phút.

## API theo bài Tuần 6

API dùng ASP.NET Core 8, Entity Framework Core, Repository-style controller endpoints, SQL Server trong môi trường phát triển và PostgreSQL trên Render. Các CRUD nhân viên nằm tại `/api/EmployeeApi`:

| Method | Endpoint | Quyền |
| --- | --- | --- |
| GET | `/api/EmployeeApi` | Nhân viên đã đăng nhập |
| GET | `/api/EmployeeApi/{id}` | Nhân viên đã đăng nhập |
| POST | `/api/EmployeeApi` | Admin |
| PUT | `/api/EmployeeApi/{id}` | Admin |
| DELETE | `/api/EmployeeApi/{id}` | Admin |

Xác thực nằm tại `/api/Auth/register`, `/api/Auth/login`, `/api/Auth/verify-otp`. Chấm công dùng `POST /api/AttendanceApi`; lịch sử dùng `GET /api/AttendanceApi`. `/health` là health check; `/swagger` mở tài liệu endpoint.

### Chạy backend cục bộ

```powershell
cd backend
dotnet tool restore
dotnet user-secrets init --project LEDOANVANTU2.Api
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=<sql-server>;Database=TuTimeDb;Trusted_Connection=True;TrustServerCertificate=True" --project LEDOANVANTU2.Api
dotnet user-secrets set "Jwt:Key" "<random-secret-minimum-32-bytes>" --project LEDOANVANTU2.Api
dotnet ef database update --project LEDOANVANTU2.Api --startup-project LEDOANVANTU2.Api
dotnet run --project LEDOANVANTU2.Api
```

Trong Development, nếu chưa cấu hình nhà cung cấp email, API trả OTP thử nghiệm trong response. Production không trả OTP. Trên Render miễn phí, SMTP cổng 25/465/587 bị chặn nên hãy dùng Brevo API qua HTTPS; cấu hình `Brevo__ApiKey` và `Smtp__From` là địa chỉ sender đã xác minh trong Brevo. `Brevo__SenderName` mặc định là `TuTime`. Khi có Brevo API key, API ưu tiên gửi OTP qua Brevo. SMTP chỉ dùng làm phương án dự phòng trên hosting cho phép kết nối SMTP.

## Deploy lên Render

`render.yaml` tạo web service API bằng Docker và PostgreSQL free ở Singapore. Từ Render chọn **New → Blueprint**, chọn repo công khai của project và dùng file `render.yaml`. Khi Render yêu cầu các biến `sync: false`, điền thông tin admin khởi tạo và `Brevo__ApiKey` trực tiếp trên Render; `Smtp__From` phải trùng địa chỉ sender đã xác minh ở Brevo. Không commit API key vào GitHub. Render miễn phí chặn SMTP 25/465/587, vì vậy chỉ nhập Gmail SMTP sẽ không gửi được OTP.

API đã deploy tại `https://ledoanvantu2-api.onrender.com`; kiểm tra `/health`, rồi build APK:

```powershell
flutter build apk --release --dart-define=OFFICE_LAT=10.7769 --dart-define=OFFICE_LNG=106.7009
```

Render và GitHub là dịch vụ bên ngoài. Trước khi public API, thay tọa độ mẫu, cấu hình email provider, nhập thông tin admin và kiểm tra môi trường database của nhóm.
