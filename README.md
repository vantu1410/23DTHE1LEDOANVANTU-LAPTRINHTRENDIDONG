# TuTime chấm công

TuTime là ứng dụng Flutter chấm công cho nhân viên. Ứng dụng xác thực bằng QR theo ngày, sinh trắc học có sẵn trên điện thoại và vị trí GPS quanh văn phòng. Chỉ gửi vị trí khi nhân viên bấm chấm công; backend kiểm tra khoảng cách rồi chỉ lưu khoảng cách tới văn phòng, không lưu tọa độ chính xác.

Project Flutter mang tên cá nhân `LEDOANVANTU2`. Mã Flutter nằm trong `lib/`; API ASP.NET Core nằm trong `backend/LEDOANVANTU2.Api/`. Thư mục `app/` ở gốc là project Kotlin ban đầu, được giữ lại làm bản gốc tham khảo; ứng dụng Flutter Android được build từ `android/`.

## Chạy Flutter

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://ledoanvantu2-api.onrender.com --dart-define=OFFICE_LAT=10.7769 --dart-define=OFFICE_LNG=106.7009 --dart-define=OFFICE_RADIUS_M=150
```

Không đặt `API_BASE_URL` thì app chạy chế độ demo. Đăng nhập demo bằng tên/mật khẩu mẫu trên màn hình, chọn vai trò demo, rồi nhập OTP `123456`. Chế độ demo không tạo tài khoản thật và CRUD chỉ lưu trong bộ nhớ.

Khi API đã deploy, nhân viên đăng ký bằng email, username và mật khẩu; backend gửi OTP qua email. Đăng nhập dùng username, mật khẩu và OTP. Vai trò nhận từ token backend; tài khoản mới là `Employee`. Tài khoản admin được khởi tạo riêng bằng các biến `BootstrapAdmin__...` trên Render.

Admin mở **Tài khoản → Mã QR điểm danh hôm nay** để hiển thị QR. Nhân viên quét QR đó trên điện thoại, xác thực sinh trắc học, rồi app kiểm tra GPS. QR có hiệu lực theo ngày Việt Nam. Tọa độ văn phòng hiện dùng là tọa độ mẫu ở TP.HCM (`10.7769`, `106.7009`); thay `Office__Latitude`, `Office__Longitude` trên Render và dùng cùng giá trị `OFFICE_LAT`/`OFFICE_LNG` khi build APK để geofence khớp văn phòng thực tế.

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

Trong Development, nếu SMTP chưa cấu hình, API trả OTP thử nghiệm trong response. Production không trả OTP; phải cấu hình SMTP trước để đăng ký và đăng nhập email OTP hoạt động.

## Deploy lên Render

`render.yaml` tạo web service API bằng Docker và PostgreSQL free ở Singapore. Từ Render chọn **New → Blueprint**, chọn repo công khai của project và dùng file `render.yaml`. Khi Render yêu cầu các biến `sync: false`, điền thông tin admin khởi tạo và SMTP trực tiếp trên Render; không commit các giá trị này vào GitHub.

API đã deploy tại `https://ledoanvantu2-api.onrender.com`; kiểm tra `/health`, rồi build APK:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://ledoanvantu2-api.onrender.com --dart-define=OFFICE_LAT=10.7769 --dart-define=OFFICE_LNG=106.7009 --dart-define=OFFICE_RADIUS_M=150
```

Render và GitHub là dịch vụ bên ngoài. Trước khi public API, thay tọa độ mẫu, cấu hình SMTP, nhập thông tin admin và kiểm tra môi trường database của nhóm.
