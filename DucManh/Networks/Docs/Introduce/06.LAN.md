# So sánh LAN/ VLAN/ VXLAN
LAN, VLAN và VXLAN đại diện cho ba giai đoạn phát triển của kiến trúc mạng: đi từ hạ tầng vật lý cục bộ (LAN) $\rightarrow$ phân chia logic trên Layer 2 (VLAN) $\rightarrow$ mạng ảo đè Overlay truyền qua Layer 3 (VXLAN) trong môi trường ảo hóa và Điện toán đám mây.

# Bảng so sánh tổng quan
|Tiêu chí|LAN (Physical LAN)|VLAN (802.1Q)|VXLAN (RFC 7348)|
|-|-|-|-|
|Bản chất|Mạng cục bộ vật lý thuần túy.|Mạng LAN ảo phân chia trên Layer 2.|Mạng ảo đè (Overlay) đóng gói L2-in-UDP.|
|Tầng OSI hoạt động|Layer 2 (Data Link).|Layer 2 (Data Link).|Layer 2 đè lên Layer 3/Layer 4 (UDP:4789).|
|Thẻ định danh|Không có (Phân biệt theo cổng vật lý).|VLAN ID (12-bit).|VNI (VXLAN Network Identifier - 24-bit).|
|Số lượng mạng tối đa|1 Broadcast Domain / 1 Switch.|4,094 mạng ảo ($2^{12} - 2$).|~16.7 triệu mạng ảo ($2^{24}$).|
|Phạm vi hoạt động|Giới hạn trong khoảng cách cáp vật lý.|Giới hạn trong cùng miền Layer 2 (Trunking).|Không giới hạn, truyền qua hạ tầng Layer 3.|
|Hạ tầng yêu cầu|Switch / Cáp mạng vật lý.|Switch hỗ trợ chuẩn IEEE 802.1Q.|Hạ tầng IP thông suốt L3 (Routable IP Network).|
|Kích thước| Overhead0 Byte.|4 Bytes (VLAN Header).|50 Bytes (Outer ETH + IP + UDP + VXLAN Header).|
|Mục đích chính|Kết nối thiết bị văn phòng/nhà ở.|Phân chia phòng ban, cô lập mạng SMB.|Multi-tenancy cho Data Center, Cloud, KVM/SDN.|

## 1. LAN (Local Area Network - Mạng cục bộ vật lý)
Cơ chế: Kết nối các máy tính vật lý trong cùng một khu vực thông qua Switch và dây cáp Ethernet.

Đặc điểm: Toàn bộ thiết bị nằm chung một Broadcast Domain. Khi một máy gửi gói tin Broadcast (như ARP Request), tất cả các máy còn lại trong LAN đều phải tiếp nhận và xử lý.

Hạn chế: Không thể phân chia bảo mật giữa các phòng ban nếu cắm chung Switch; bão Broadcast (Broadcast Storm) dễ ảnh hưởng toàn hệ thống nếu mạng mở rộng.
## 2. VLAN (Virtual Local Area Network - Mạng LAN ảo L2)
Cơ chế: Chia một Switch vật lý thành nhiều Switch ảo độc lập về mặt logic bằng cách chèn thêm 12-bit VLAN Tag vào Ethernet Frame chuẩn (theo chuẩn IEEE 802.1Q).

Đặc điểm:
- Cô lập hoàn toàn Broadcast Domain giữa các VLAN (ví dụ: VLAN 10 đại diện cho IT, VLAN 20 đại diện cho Kế toán).
- Muốn dữ liệu truyền giữa các VLAN với nhau bắt buộc phải đi qua một thiết bị Layer 3 (Router hoặc Switch Layer 3).

Hạn chế:
- Giới hạn $4,094$ VLAN không đủ cung cấp cho các trung tâm dữ liệu Cloud lớn có hàng chục nghìn khách hàng (Tenants).
- Đòi hỏi toàn bộ các Switch vật lý trên đường đi phải được cấu hình Trunking Layer 2 đồng bộ.

## 3. VXLAN (Virtual Extensible LAN - Mạng ảo đè Overlay)
Cơ chế: Đóng gói (Encapsulate) toàn bộ Ethernet Frame Layer 2 của máy ảo vào bên trong gói tin UDP (Port 4789) ở Layer 4, sau đó gửi qua hạ tầng mạng IP (Layer 3) thông thường.

Đặc điểm:
- Kiến trúc Overlay / Underlay: Mạng máy ảo (Overlay) hoàn toàn độc lập với cấu trúc mạng vật lý bên dưới (Underlay).
- VNI 24-bit: Mở rộng không gian định danh lên đến $16.7$ triệu mạng ảo, xóa bỏ điểm nghẽn $4,094$ của VLAN.
- Xóa bỏ rào cản địa lý: Hai máy ảo chạy trên hai KVM Host đặt ở hai Data Center khác nhau (kết nối qua mạng IP L3) vẫn giao tiếp Layer 2 trực tiếp như đang cắm chung một Switch.

Hạn chế: Thêm 50 Bytes header khiến MTU gói tin tăng lên, yêu cầu hạ tầng mạng vật lý cần bật Jumbo Frames (MTU $\ge 1550$) để tránh tình trạng phân đoạn gói tin.

## Sử dụng
Văn phòng / Doanh nghiệp nhỏ: Sử dụng kết hợp LAN và VLAN trên Switch phần cứng để chia mạng nội bộ.

Trung tâm dữ liệu / Hạ tầng Cloud (KVM, OpenStack, Kubernetes): Sử dụng VXLAN kết hợp với Open vSwitch (OVS) hoặc Linux Bridge để tự động hóa việc cấp phát mạng ảo cô lập cho từng khách hàng mà không cần can thiệp vào Switch vật lý bên ngoài