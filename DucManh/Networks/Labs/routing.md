# Sử dụng Cisco Packet Tracer để cấu hình Static Routing

## 1. Mô tả hệ thống và quy hoạch mạng

### 1.1. Tổng quan kiến trúc
Mô phỏng kết nối liên mạng giữa 2 chi nhánh thông qua hạ tầng định tuyến gồm 4 Router xếp theo mô hình hình thoi, tạo thành 2 tuyến đường vật lý song song:
- **Thiết bị đầu cuối:** 01 máy tính để bàn (`PC0`) tạia mạng LAN trái và 01 máy tính xách tay (`Laptop0`) tại mạng LAN phải.
- **Thiết bị chuyển mạch:** 02 Switch Cisco 2960-24TT (`Switch0`, `Switch1`) kết nối các thiết bị đầu cuối vào cổng LAN của Router biên.
- **Thiết bị định tuyến:** 04 Router Cisco 2911 (`Router1`, `Router0`, `Router2`, `Router3`), mỗi thiết bị có sẵn 3 cổng GigabitEthernet (`Gi0/0`, `Gi0/1`, `Gi0/2`).
- **Phân chia dải mạng:**

| Mạng | Mô tả | Thiết bị kết nối |
| :--- | :--- | :--- |
| `192.168.1.0/24` | Mạng LAN trái | PC0 - Switch0 - Router1 |
| `192.168.2.0/24` | Mạng LAN phải | Router3 - Switch1 - Laptop0 |
| `10.0.1.0/30` | Liên kết điểm-điểm nhánh trên trái | Router1 - Router0 |
| `10.0.2.0/30` | Liên kết điểm-điểm nhánh trên phải | Router0 - Router3 |
| `10.0.3.0/30` | Liên kết điểm-điểm nhánh dưới phải | Router2 - Router3 |
| `10.0.4.0/30` | Liên kết điểm-điểm nhánh dưới trái | Router1 - Router2 |

### 1.2. Bảng quy hoạch đấu nối và địa chỉ IP chi tiết

> **Lưu ý đấu nối cáp vật lý:** Dùng **cáp thẳng (Copper Straight-Through)** nối từ PC/Laptop vào Switch và từ Switch lên Router; dùng **cáp chéo (Copper Cross-Over)** nối trực tiếp giữa các cổng GigabitEthernet của Router với nhau.

| Thiết bị | Interface | Địa chỉ IP | Subnet Mask | Default Gateway | Đấu nối tới |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PC0** | `FastEthernet0` | `192.168.1.10` | `255.255.255.0` | `192.168.1.1` | `Switch0 (Fa0/1)` |
| **Switch0** | `Fa0/1`, `Fa0/24` | *(Không gán IP)* | *(Layer 2)* | *(Không có)* | `PC0`, `Router1 (Gi0/0)` |
| **Router1** | `Gi0/0` | `192.168.1.1` | `255.255.255.0` | *(Không có)* | `Switch0 (Fa0/24)` |
| **Router1** | `Gi0/1` | `10.0.1.1` | `255.255.255.252` | *(Không có)* | `Router0 (Gi0/0)` |
| **Router1** | `Gi0/2` | `10.0.4.2` | `255.255.255.252` | *(Không có)* | `Router2 (Gi0/0)` |
| **Router0** | `Gi0/0` | `10.0.1.2` | `255.255.255.252` | *(Không có)* | `Router1 (Gi0/1)` |
| **Router0** | `Gi0/1` | `10.0.2.1` | `255.255.255.252` | *(Không có)* | `Router3 (Gi0/0)` |
| **Router2** | `Gi0/0` | `10.0.4.1` | `255.255.255.252` | *(Không có)* | `Router1 (Gi0/2)` |
| **Router2** | `Gi0/1` | `10.0.3.2` | `255.255.255.252` | *(Không có)* | `Router3 (Gi0/1)` |
| **Router3** | `Gi0/0` | `10.0.2.2` | `255.255.255.252` | *(Không có)* | `Router0 (Gi0/1)` |
| **Router3** | `Gi0/1` | `10.0.3.1` | `255.255.255.252` | *(Không có)* | `Router2 (Gi0/1)` |
| **Router3** | `Gi0/2` | `192.168.2.1` | `255.255.255.0` | *(Không có)* | `Switch1 (Fa0/24)` |
| **Switch1** | `Fa0/1`, `Fa0/24` | *(Không gán IP)* | *(Layer 2)* | *(Không có)* | `Laptop0`, `Router3 (Gi0/2)` |
| **Laptop0** | `FastEthernet0` | `192.168.2.10` | `255.255.255.0` | `192.168.2.1` | `Switch1 (Fa0/1)` |

---

## 2. Mô tả Bài Lab & Mục tiêu

### 2.1. Mô tả bài lab
Thực hành kỹ thuật định tuyến tĩnh (**Static Routing**) trên hệ điều hành Cisco IOS. Vì các Router chỉ tự động biết các mạng cắm trực tiếp vào cổng của nó (*Directly Connected*), cần cấu hình thủ công các tuyến đường tĩnh trên từng Router để thông suốt lưu lượng 2 chiều giữa `PC0` và `Laptop0`, đồng thời khai thác cấu trúc mạch vòng hình thoi để triển khai dự phòng và cân bằng tải.

### 2.2. Mục tiêu
- Cấu hình thành công địa chỉ IP và kích hoạt trạng thái vật lý (`up/up`) cho toàn bộ cổng mạng trên 4 Router và 2 thiết bị đầu cuối.
- **Trường hợp 1 (Static Routing cơ bản):** Thông mạng 2 chiều giữa `PC0` và `Laptop0` đi qua nhánh chính phía trên (`Router1 <-> Router0 <-> Router3`).
- **Trường hợp 2 (Floating Static Route):** Cấu hình tuyến dự phòng qua nhánh dưới (`Router2`) bằng tham số Administrative Distance (AD). Khi giả lập đứt cáp trên nhánh chính, lưu lượng tự động chuyển hướng xuống nhánh dưới mà không làm gián đoạn kết nối.
- **Trường hợp 3 (Static ECMP Load Balancing):** Cấu hình đồng mức ưu tiên cho cả 2 nhánh trên và dưới để chia tải song song cùng lúc.

---

## 3. Thực hành

### 3.1. Cấu hình hạ tầng cơ bản

#### Bước 1: Cấu hình trên thiết bị đầu cuối
- **Trên PC0** (Vào **Desktop $\rightarrow$ IP Configuration $\rightarrow$ Static**):
  - **IPv4 Address:** `192.168.1.10`
  - **Subnet Mask:** `255.255.255.0`
  - **Default Gateway:** `192.168.1.1`
- **Trên Laptop0** (Vào **Desktop $\rightarrow$ IP Configuration $\rightarrow$ Static**):
  - **IPv4 Address:** `192.168.2.10`
  - **Subnet Mask:** `255.255.255.0`
  - **Default Gateway:** `192.168.2.1`

#### Bước 2: Cấu hình IP trên 4 Router (Tab CLI)

- **Trên Router1:**
```ios
enable
configure terminal
hostname Router1
!
interface GigabitEthernet0/0
 description LAN_TRAI
 ip address 192.168.1.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/1
 description TO_ROUTER0
 ip address 10.0.1.1 255.255.255.252
 no shutdown
!
interface GigabitEthernet0/2
 description TO_Router2
 ip address 10.0.4.2 255.255.255.252
 no shutdown
end
```

- **Trên Router0:**
```ios
enable
configure terminal
hostname Router0
!
interface GigabitEthernet0/0
 description TO_Router1
 ip address 10.0.1.2 255.255.255.252
 no shutdown
!
interface GigabitEthernet0/1
 description TO_Router3
 ip address 10.0.2.1 255.255.255.252
 no shutdown
end
```

- **Trên Router2:**
```ios
enable
configure terminal
hostname Router2
!
interface GigabitEthernet0/0
 description TO_Router1
 ip address 10.0.4.1 255.255.255.252
 no shutdown
!
interface GigabitEthernet0/1
 description TO_Router3
 ip address 10.0.3.2 255.255.255.252
 no shutdown
end
```

- **Trên Router3:**
```ios
enable
configure terminal
hostname Router3
!
interface GigabitEthernet0/0
 description TO_ROUTER0
 ip address 10.0.2.2 255.255.255.252
 no shutdown
!
interface GigabitEthernet0/1
 description TO_Router2
 ip address 10.0.3.1 255.255.255.252
 no shutdown
!
interface GigabitEthernet0/2
 description LAN_PHAI
 ip address 192.168.2.1 255.255.255.0
 no shutdown
end
```

---

### 3.2. Trường hợp 1: Static Routing cơ bản (Tuyến đơn)

#### Cấu hình trên các Router
- **Trên Router1:**
```ios
configure terminal
ip route 192.168.2.0 255.255.255.0 10.0.1.2
end
```

- **Trên Router0:**
```ios
configure terminal
ip route 192.168.2.0 255.255.255.0 10.0.2.2
ip route 192.168.1.0 255.255.255.0 10.0.1.1
end
```

- **Trên Router3:**
```ios
configure terminal
ip route 192.168.1.0 255.255.255.0 10.0.2.1
end
```

#### Kiểm tra kết quả
Mở **Command Prompt** trên `PC0` và chạy:
```cmd
ping 192.168.2.10
tracert 192.168.2.10
```
Kết quả `tracert` đi qua nhánh trên theo thứ tự: `192.168.1.1` $\rightarrow$ `10.0.1.2` $\rightarrow$ `10.0.2.2` $\rightarrow$ `192.168.2.10`.

---

### 3.3. Trường hợp 2: Floating Static Route (Dự phòng tự động)

#### Cấu hình bổ sung tuyến dự phòng (AD = 5)
- **Trên Router2:**
```ios
configure terminal
ip route 192.168.2.0 255.255.255.0 10.0.3.1
ip route 192.168.1.0 255.255.255.0 10.0.4.2
end
```

- **Trên Router1:**
```ios
configure terminal
ip route 192.168.2.0 255.255.255.0 10.0.4.1 5
end
```

- **Trên Router3:**
```ios
configure terminal
ip route 192.168.1.0 255.255.255.0 10.0.3.2 5
end
```

#### Kiểm tra chuyển đổi dự phòng (Failover Test)
1. Tắt cổng `Gi0/0` trên **Router0** để giả lập đứt cáp nhánh trên:
```ios
configure terminal
interface GigabitEthernet0/0
 shutdown
end
```
2. Kiểm tra bảng định tuyến trên `Router1` bằng lệnh `show ip route` (xuất hiện tuyến `S 192.168.2.0/24 [5/0] via 10.0.4.1`) và chạy lại `tracert 192.168.2.10` trên `PC0` để xác nhận gói tin đi qua nhánh dưới (`10.0.4.1` $\rightarrow$ `10.0.3.1`).
3. Bật lại cổng `Gi0/0` trên **Router0** trước khi sang Trường hợp 3:
```ios
configure terminal
interface GigabitEthernet0/0
 no shutdown
end
```

---

### 3.4. Trường hợp 3: Static ECMP Load Balancing (Cân bằng tải 2 nhánh)

#### Cấu hình đồng mức ưu tiên (AD = 1)
- **Trên Router1:**
```ios
configure terminal
no ip route 192.168.2.0 255.255.255.0 10.0.4.1 5
ip route 192.168.2.0 255.255.255.0 10.0.4.1
end
```

- **Trên Router3:**
```ios
configure terminal
no ip route 192.168.1.0 255.255.255.0 10.0.3.2 5
ip route 192.168.1.0 255.255.255.0 10.0.3.2
end
```

#### Kiểm tra cân bằng tải
1. Chạy `show ip route` trên `Router1` và `Router3` để xác nhận 2 Next-hop hiển thị song song với cùng chỉ số `[1/0]`.
2. Chuyển sang chế độ **Simulation**, gửi liên tiếp 2 gói tin ICMP từ `PC0` sang `Laptop0` để quan sát lưu lượng chia đều qua cả `Router0` và `Router2`.

---

## 4. Lưu cấu hình hệ thống

Chạy lệnh sau trên cả 4 Router ở chế độ Privileged EXEC (`#`) để lưu cấu hình vào bộ nhớ NVRAM:

```ios
write memory
```