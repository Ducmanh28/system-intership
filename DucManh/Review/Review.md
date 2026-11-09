# Ôn tập mạng
## OSI
### Là gì? Dùng để làm gì?
Là mô hình tham chiếu tiêu chuẩn chung gồm 7 tầng, mô tả cách mạng hoạt động. Được đưa ra bởi ISO làm 1 quy chuẩn chung cho mạng. Thường được sử dụng để giảng dạy, phân chia thiết bị, thành phần trong mạng, hỗ trợ kĩ sư nắm bắt lỗi nhanh chóng.

### 7 tầng của OSI là những tầng nào? Chức năng từng tầng?
Mô hình OSI gồm 7 tầng với chức năng từng tầng như sau:
- Tầng Application: Cung cấp giao diện kết nối mạng cho các ứng dụng của người dùng.
- Tầng Presentation: Chịu trách nhiệm định dạng, mã hóa và nén dữ liệu.
- Tầng Session: Thiết lập, duy trì và đóng các phiên kết nối giữa các ứng dụng.
- Tầng Transport: Phân mảnh dữ liệu, kiểm soát luồng và đảm bảo tiến trình truyền tải.
- Tầng Network: Cung cấp địa chỉ logic (IP) và định tuyến (tìm đường đi) xuyên mạng.
- Tầng Data Link: Cung cấp địa chỉ vật lý (MAC), kiểm tra lỗi, luồng và truyền dữ liệu trong cùng mạng nội bộ.
- Tầng Physical: Chuyển đổi dữ liệu thành các bit (0,1) để truyền qua các môi trường vật lý (cáp, sóng).

### Cách 1 gói tin đi qua mô hình OSI
Trong mô hình OSI, ở từng tầng mà gói tin đi qua, nó sẽ được thêm vào các header hỗ trợ cho việc truyền. Ví dụ khi muốn gửi 1 gói tin từ máy A->B thì quy trình cụ thể như sau:
- Máy A (Máy gửi): Quy trình đóng gói dữ liệu và gửi đi
  - **Tầng Application**: Người dùng bấm gửi ở màn hình máy tính, máy tính nhận được yêu cầu gửi gói tin, quy trình gửi bắt đầu. `PDU: Data`  
  - **Tầng Presentation**: Dữ liệu lúc này được định dạng, nén lại và mã hóa(TLS/SSL). `PDU: Data`
  - **Tầng Session**: Ở tầng này, 1 phiên truyền được khởi tạo, dữ liệu được thêm vào các Header định danh phiên giao tiếp, thêm checkpoint vào trong luồng dữ liệu. `PDU: Data`
  - **Tầng Transport**: Ở tầng này, dữ liệu được chia nhỏ, thêm vào các Transport Header chứa thông tin liên quan tới Port, luồng(TCP/UDP). `PDU: Segment(TCP) hoặc Datagram(UDP)`
  - **Tầng Network**: Ở tầng này, (quy trình chia nhỏ gói tin cũng có thể diễn ra nếu đường truyền hẹp, biến gói tin thành Fragment) dữ liệu được gắn thêm Network Header chứa IP, đường đi cho gói tin. `PDU: Packets`
  - **Tầng Data-Link**: Dữ liệu được gắn thêm Header chứa MAC, và trailer FCS để kiểm tra lỗi bit. `PDU: Frames`
  - **Tầng Physical**: Chuyển đổi Frame thành các bit nhị phân, sau đó biến chúng thành các tín hiệu điện để truyền qua môi trường vật lý. `PDU: Bit`
- Máy B (Máy nhận): Quy trình nhận và mở gói dữ liệu
  - **Tầng Physical**: Nhận các tín hiệu điện và chuyển thành Bit(0,1) sau đó chuyển lên tầng trên.
  - **Tầng Data-Link**: Kiểm tra FCS xem có lỗi Bit không, đọc MAC và kiểm tra xem trùng không. Nếu không có lỗi và MAC đúng, bóc Header/Trailer của Frame để lấy Packet chuyển lên tầng trên
  - **Tầng Network**: Kiểm tra IP xem trùng không, nếu đúng thì gỡ bỏ IP Header và chuyển lên tầng trên. Nếu ở chiều gửi gói tin từng bị chia nhỏ , thì tại tầng này sẽ thực hiện thêm bước ghép các Fragment lại thành Packet hoàn chỉnh rồi mới bóc IP Header
  - **Tầng Transport**: Kiểm tra Port để xem đưa dữ liệu về ứng dụng nào, ghép nối dữ liệu và gỡ bỏ Transport Header. Sau đó chuyển lên tầng trên.
  - **Tầng Session**: Nhận Data, kiểm tra và duy trì phiên hợp lệ(phiên chỉ đóng khi có yêu cầu đóng từ ứng dụng, quy trình truyền toàn bộ hoàn tất hoặc mất mạng, hết thời gian chờ). Gỡ bỏ Session Header và gửi data lên tầng trên.
  - **Tầng Presentation**: Lúc này, dữ liệu được giải mã, giải nén, đưa về định dạng ban đầu, sau đó được chuyển lên tầng trên.
  - **Tầng Applications**: Ứng dụng nhận dữ liệu và hiển thị cho người dùng

## TCP/IP
Mô hình TCP/IP là kiến trúc mạng 4 tầng thực tiễn, đóng vai trò làm chuẩn truyền thông duy nhất để vận hành toàn bộ Internet và các mạng nội bộ. Mô hình này được sử dụng để trừu tượng hóa sự phức tạp của hạ tầng phần cứng bên dưới, đồng thời quy định toàn bộ quy trình truyền tải dữ liệu trong mạng, và đảm bảo khả năng giao tiếp liền mạch giữa mọi hệ thống bất kể sự khác biệt về phần cứng hay hệ điều hành.

### 4 tầng của TCP/IP gồm những tầng nào? Chức năng từng tầng
Mô hình TCP/IP gồm có 4 tầng, chức năng chi tiết từng tầng như sau:

