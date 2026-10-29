# TuTime chấm công

TuTime là ứng dụng Flutter chấm công cho nhân viên. Ba chức năng trình bày đã chọn là **chia sẻ vị trí GPS (b)**, **đo áp suất khí quyển (d)** và **nhận diện QR (e)**. Nhân viên quét QR cố định của công ty, sau đó app kiểm tra vị trí GPS; backend chỉ lưu khoảng cách tới văn phòng, không lưu tọa độ chính xác.

Project Flutter mang tên cá nhân `LEDOANVANTU2`. Mã Flutter nằm trong `lib/`; API ASP.NET Core nằm trong `backend/LEDOANVANTU2.Api/`. Thư mục `app/` ở gốc là project Kotlin ban đầu, được giữ lại làm bản gốc tham khảo; ứng dụng Flutter Android được build từ `android/`.

## Chạy Flutter

```powershell
flutter pub get
flutter run --dart-define=OFFICE_LAT=10.7769 --dart-define=OFFICE_LNG=106.7009 --dart-define=OFFICE_RADIUS_M=150
```

App mặc định kết nối API đã deploy tại Render. Nếu nhóm có API riêng, truyền `--dart-define=API_BASE_URL=https://...` khi chạy/build. Chế độ demo ngoại tuyến chỉ bật khi chủ động truyền `--dart-define=API_BASE_URL=`; dữ liệu demo không tạo tài khoản thật và CRUD chỉ lưu trong bộ nhớ.

Khi API đã deploy, nhân viên đăng ký bằng email, username và mật khẩu; backend gửi OTP qua email. Đăng nhập dùng username, mật khẩu và OTP. Vai trò nhận từ token backend; tài khoản mới là `Employee`. Tài khoản admin được khởi tạo riêng bằng các biến `BootstrapAdmin__...` trên Render.

Admin mở **Tài khoản → Mã QR công ty cố định** để hiển thị mã. Nhân viên có thể quét bằng camera, chọn ảnh QR đã lưu, hoặc trong một giả lập dùng nút **Dùng QR demo đã lưu trong app** để kiểm tra giải mã ảnh QR. QR cố định có thể bị sao chép, vì vậy API vẫn kiểm tra bán kính GPS. Tọa độ văn phòng hiện dùng là tọa độ mẫu ở TP.HCM (`10.7769`, `106.7009`); thay `Office__Latitude`, `Office__Longitude` trên Render và dùng cùng giá trị `OFFICE_LAT`/`OFFICE_LNG` khi build APK để geofence khớp văn phòng thực tế.

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
flutter build apk --release --dart-define=OFFICE_LAT=10.7769 --dart-define=OFFICE_LNG=106.7009 --dart-define=OFFICE_RADIUS_M=150
```

Render và GitHub là dịch vụ bên ngoài. Trước khi public API, thay tọa độ mẫu, cấu hình email provider, nhập thông tin admin và kiểm tra môi trường database của nhóm.
