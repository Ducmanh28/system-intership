# Ôn tập kiến thức đã học

---

## 1. VLAN / VxLAN

**VLAN là gì? Để làm gì?**
- Chia một switch vật lý thành nhiều mạng L2 riêng (mỗi VLAN là 1 broadcast domain).
- Lợi ích: giảm broadcast, cô lập bảo mật, quản lý linh hoạt.
- Khác VLAN muốn nói chuyện phải qua thiết bị L3 (router/L3 switch).

**VLAN hoạt động thế nào?**
- Chuẩn 802.1Q: chèn thêm **tag 4 byte** vào frame, trong đó **VLAN ID 12 bit** → tối đa **4094 VLAN**.
- **Access port**: thuộc 1 VLAN, không gắn tag, nối với máy tính/VM.
- **Trunk port**: mang nhiều VLAN (có tag), nối switch–switch hoặc switch–server.
- **Native VLAN**: VLAN đi qua trunk mà không gắn tag.

**Hạn chế của VLAN?**
- Chỉ có 4094 VLAN, không đủ cho cloud nhiều tenant.
- Phụ thuộc L2 + STP (dễ loop, hội tụ chậm), khó kéo dài L2 giữa các DC.

**VxLAN là gì?**
- Công nghệ **overlay**: đóng gói frame L2 vào gói **UDP (port 4789)** để chạy qua mạng L3.
- Dùng **VNI 24 bit** → khoảng 16 triệu mạng, đủ cho cloud lớn.

**Các thành phần chính của VxLAN?**
- **VTEP**: điểm đóng gói/gỡ gói (trên switch hoặc trên host ảo hóa).
- **VNI**: ID của mạng ảo (giống VLAN ID).
- **Underlay**: mạng IP vật lý bên dưới. **Overlay**: mạng ảo chạy phía trên.
- Overhead khoảng **50 byte** → cần tăng MTU underlay (≥ 1550) hoặc giảm MTU VM.

**Gói tin đi thế nào?**
VM A → VTEP 1 đóng gói (gắn VNI, IP đích là VTEP 2) → đi qua mạng L3 → VTEP 2 gỡ gói → VM B.

**Làm sao biết MAC nằm ở VTEP nào?**
- **Flood-and-learn**: gửi broadcast (multicast hoặc nhân bản unicast) rồi tự học MAC.
- **BGP EVPN**: các VTEP trao đổi thông tin MAC/IP qua BGP, ít flood, là cách chuẩn hiện nay.

**So sánh nhanh**

| | VLAN | VxLAN |
|---|---|---|
| Số mạng | 4094 | ~16 triệu |
| Cách làm | Gắn tag L2 | Đóng gói trong UDP (overlay) |
| Chạy trên | Mạng L2 | Mạng L3 |
| Dùng cho | Mạng nhỏ/vừa | Cloud, DC lớn |

---

## 2. NAT, Bridge, Host-Only

**Virtual switch là gì?**
- Switch L2 bằng phần mềm trong hypervisor, nối card mạng ảo (vNIC) của VM với nhau và với card mạng thật (uplink).
- Trong KVM thường là **Linux Bridge**; vNIC của VM hiện trên host dưới dạng thiết bị **tap (vnetX)**.

**3 chế độ mạng khác nhau thế nào?**

| Chế độ | VM ra Internet | Bên ngoài vào VM | IP của VM |
|---|---|---|---|
| **NAT** | Có | Không (trừ khi port forwarding) | Dải riêng, do hypervisor cấp |
| **Bridge** | Có | Có | Cùng dải với LAN thật |
| **Host-Only** | Không | Không | Dải nội bộ, cô lập |

**NAT là gì?**
- Đổi địa chỉ IP/port khi đi qua router để nhiều máy private dùng chung 1 IP.
- **SNAT/Masquerade**: đổi IP nguồn (đi ra). **DNAT/Port forwarding**: đổi IP đích (đi vào).

**Đường đi gói tin – NAT**
```
VM → tap (vnetX) → virbr0 (gateway của VM) → định tuyến + NAT trên host → card mạng thật → Internet
```
- virbr0 **không chứa card mạng thật**; gói đi ra qua tầng routing của host, bị đổi IP nguồn thành IP host.

**Đường đi gói tin – Bridge**
```
VM → tap (vnetX) → br0 ── (cùng L2) ── card mạng thật → switch vật lý → LAN/Internet
```
- Bridge chỉ chuyển frame theo MAC, **không NAT, không routing**.
- 2 VM cùng bridge trên cùng host nói chuyện trực tiếp trong bridge, không ra ngoài.
- IP của host được gán lên bridge; DHCP do mạng LAN thật cấp.

**Đường đi gói tin – Host-Only**
```
VM → tap (vnetX) → bridge ảo (không có card thật, không NAT) → VM khác / host
```

**Không tạo bridge, VM có ra ngoài được không? Ai cấp IP?**
- **Có.** libvirt có sẵn network `default` ở chế độ NAT, tự tạo **virbr0** và rule NAT.
- **dnsmasq** (do libvirt chạy) cấp DHCP và DNS cho VM.

**Switch ảo và card mạng thật liên quan thế nào?**
- **Bridge**: card thật là 1 port của bridge (uplink) → cùng một mạng L2.
- **NAT**: không nối L2, chỉ liên hệ qua routing + NAT của host.
- **Host-Only**: không liên quan.

**Khi nào dùng chế độ nào?**
- NAT: VM chỉ cần ra Internet (lab, test).
- Bridge: VM cần như một máy thật trong LAN (chạy dịch vụ cho người khác truy cập).
- Host-Only: cần mạng cô lập.

---

## 3. DNS

**DNS là gì?**
- Hệ thống phân giải **tên miền ↔ địa chỉ IP**, dạng phân tán và phân cấp.

**Cấu trúc của DNS?**
- Cây phân cấp: **Root (.) → TLD (.vn, .com) → domain (vnpt.vn) → subdomain**.
- **Zone**: phần tên miền do một nơi quản lý.
- **FQDN**: tên đầy đủ từ máy tới root.

**Có những loại DNS server nào?**
- **Authoritative**: giữ dữ liệu gốc của zone.
- **Recursive resolver**: nhận câu hỏi từ client, đi tìm đáp án và cache lại.
- **Forwarder**: chuyển tiếp câu hỏi sang resolver khác.

**Quy trình phân giải?**
Client → resolver → root → TLD → authoritative → trả kết quả về client (resolver cache theo **TTL**).
- **Recursive**: resolver tự làm hết rồi trả đáp án cuối.
- **Iterative**: server chỉ gợi ý server tiếp theo để hỏi.

**Các loại record thường gặp?**

| Record | Ý nghĩa |
|---|---|
| A / AAAA | Tên → IPv4 / IPv6 |
| CNAME | Bí danh trỏ sang tên khác |
| NS | Name server của zone |
| SOA | Thông tin quản lý zone (serial, refresh, …) |
| MX | Mail server |
| PTR | IP → tên (reverse lookup) |
| TXT | Văn bản: SPF, DKIM, xác minh domain |
| SRV | Vị trí dịch vụ (host + port) |

**TTL là gì?**
- Thời gian một record được phép cache. TTL ngắn → cập nhật nhanh nhưng tốn tải; TTL dài thì ngược lại.

**Forward và Reverse lookup?**
- Forward: tên → IP. Reverse: IP → tên (dùng record PTR, zone `in-addr.arpa`).

**Zone transfer là gì?**
- Đồng bộ dữ liệu zone từ server chính (Primary) sang server phụ (Secondary). **AXFR** là chép toàn bộ, **IXFR** chỉ chép phần thay đổi. Cần giới hạn người được phép.

**DNS dùng port nào?**
- **UDP/53** cho truy vấn thường; **TCP/53** cho zone transfer và gói lớn.
- **DoT/DoH**: DNS mã hóa. **DNSSEC**: chống giả mạo dữ liệu (chữ ký số, không mã hóa).

**Một số khái niệm khác**
- **Split-horizon**: cùng một tên, trả IP khác nhau cho mạng trong và ngoài.
- **DNS Round Robin**: một tên có nhiều IP, xoay vòng → cân bằng tải đơn giản, không kiểm tra server sống/chết.

---

## 4. DHCP

**DHCP là gì?**
- Tự động cấp **IP, subnet mask, gateway, DNS** cho máy khách.
- Chạy trên UDP: server port **67**, client port **68**.

**Quy trình DORA?**
1. **Discover**: client broadcast tìm DHCP server.
2. **Offer**: server đề nghị 1 IP.
3. **Request**: client chọn và xin IP đó.
4. **Acknowledge**: server xác nhận, IP được cấp theo **lease** (thời hạn thuê).

**Lease, Renew, Rebind?**
- **Lease**: thời gian thuê IP.
- **Renew** (ở 50% lease): client xin gia hạn từ server cũ.
- **Rebind** (ở 87.5% lease): nếu chưa được, client hỏi bất kỳ server nào.
- Hết hạn mà không gia hạn → phải xin IP lại.

**Các option hay gặp?**
- 1: subnet mask · 3: gateway · 6: DNS · 15: domain name · 51: lease time · 66/67: TFTP/boot file (PXE).

**Một số khái niệm cấu hình**
- **Scope/Pool**: dải IP được cấp. **Exclusion**: IP loại trừ. **Reservation**: gán IP cố định theo MAC.

**DHCP Relay là gì?**
- DHCP dùng broadcast nên chỉ chạy trong 1 subnet. **Relay** (thường là router) chuyển yêu cầu tới DHCP server ở subnet khác, để 1 server phục vụ nhiều VLAN.

**Rủi ro và cách phòng?**
- **Rogue DHCP server** (server giả cấp sai gateway/DNS), **DHCP starvation** (làm cạn pool).
- Phòng bằng **DHCP Snooping** (chỉ cho cổng tin cậy trả lời DHCP), Port Security, DAI.

**Lưu ý thêm**
- **APIPA (169.254.x.x)**: IP tự gán khi không tìm thấy DHCP server.
- Trong KVM NAT, DHCP do **dnsmasq** cấp.

---

## 5. SSH

**SSH là gì? Khác Telnet?**
- Giao thức điều khiển máy từ xa an toàn, dùng TCP **port 22**.
- Telnet gửi dữ liệu **không mã hóa**; SSH **mã hóa toàn bộ**, xác thực hai chiều, đảm bảo toàn vẹn.

**Quy trình kết nối?**
1. Thiết lập TCP, thống nhất thuật toán.
2. Trao đổi khóa (Diffie–Hellman/ECDH) để tạo **session key** chung.
3. Server chứng minh danh tính bằng **host key**.
4. Client đăng nhập (password hoặc key).
5. Dữ liệu được mã hóa đối xứng trong suốt phiên.

**SSH dùng những loại mã hóa nào?**
- **Bất đối xứng** (RSA, Ed25519): xác thực và ký.
- **Trao đổi khóa** (ECDH): tạo khóa chung.
- **Đối xứng** (AES, ChaCha20): mã hóa dữ liệu (nhanh).
- **HMAC/AEAD**: kiểm tra dữ liệu không bị sửa.

**Host key và known_hosts để làm gì?**
- Lần đầu kết nối, client lưu **fingerprint** của server vào `known_hosts`. Lần sau nếu host key đổi → cảnh báo (có thể bị tấn công giữa đường – MITM).

**Các cách xác thực?**
- **Password**: dễ dùng nhưng dễ bị dò mật khẩu.
- **Public key**: client giữ private key, server giữ public key; server thử thách, client ký chứng minh. An toàn hơn, phù hợp tự động hóa.
- Ngoài ra: MFA, Kerberos, chứng chỉ SSH.

**Port forwarding (SSH tunnel)?**
- **Local**: mở port ở máy mình, chuyển qua SSH tới dịch vụ phía server.
- **Remote**: mở port ở server, chuyển ngược về máy mình.
- **Dynamic**: tạo proxy SOCKS, đẩy mọi kết nối qua server.

**Jump host (Bastion) là gì?**
- Máy trung gian ở biên mạng; muốn vào máy nội bộ phải đi qua nó → dễ kiểm soát, ghi log.

**SCP, SFTP, rsync?**
- **SCP**: chép file đơn giản. **SFTP**: truyền file đầy đủ tính năng. **rsync**: chỉ chép phần thay đổi.

**Cách bảo mật SSH?**
- Tắt login root và password, chỉ dùng key.
- Giới hạn user/nguồn được phép, giới hạn số lần đăng nhập sai.
- Dùng fail2ban, MFA, cập nhật thường xuyên.
- Cẩn thận với agent forwarding.

---

## 6. Load Balancer

**Load Balancer là gì? Để làm gì?**
- Chia traffic cho nhiều server phía sau qua **một địa chỉ chung (VIP)**.
- Mục đích: chịu tải lớn, tăng tính sẵn sàng (server lỗi thì bỏ qua), bảo trì không gián đoạn.

**Các thành phần chính?**
- **VIP/Listener**: địa chỉ nhận traffic · **Backend pool**: nhóm server thật · **Health check** · **Thuật toán** · **Persistence** · **SSL termination**.

**L4 và L7 khác nhau thế nào?**

| | L4 | L7 |
|---|---|---|
| Dựa vào | IP, port | Nội dung (URL, header, cookie) |
| Tốc độ | Nhanh | Chậm hơn |
| Tính năng | Chia tải cơ bản | Điều hướng theo URL/host, SSL, WAF, cache |
| Ví dụ | LVS, HAProxy (TCP) | Nginx, HAProxy (HTTP) |

**Các thuật toán chia tải?**
- **Round Robin**: lần lượt. **Weighted RR**: theo trọng số.
- **Least Connections**: chọn server ít kết nối nhất.
- **Source IP Hash**: cùng IP client → cùng server.
- **Consistent Hash**: ít xáo trộn khi thêm/bớt server.

**Health check là gì?**
- Kiểm tra server còn sống không để ngừng gửi traffic vào server lỗi.
- **Active**: LB chủ động thăm dò (ping, TCP, HTTP). **Passive**: dựa trên lỗi của traffic thật.

**Session persistence (sticky session)?**
- Giữ các request của cùng một client vào cùng một server (qua IP hoặc cookie).
- Nhược điểm: tải không đều, server chết thì mất session.

**SSL termination, passthrough, bridging?**
- **Termination**: LB giải mã TLS, gửi HTTP thường tới backend (giảm tải cho backend).
- **Passthrough**: LB chuyển nguyên TLS, không đọc được nội dung.
- **Bridging**: giải mã rồi mã hóa lại khi gửi tới backend.

**Các mô hình đường đi gói tin?**
- **Proxy/Full-NAT**: LB đổi cả IP nguồn và đích; backend chỉ thấy IP của LB (dùng header `X-Forwarded-For` để biết IP client).
- **DSR (Direct Server Return)**: LB chỉ xử lý chiều đi, server trả lời thẳng cho client → nhanh, nhưng yêu cầu cùng mạng L2.

**LB bị hỏng thì sao?**
- Dùng 2 LB **Active–Passive** với **VRRP (keepalived)** và VIP dùng chung; node dự phòng tiếp quản khi node chính lỗi.

**Khái niệm thêm**
- **Reverse proxy**: đứng trước server nhận request thay; LB là reverse proxy có chia tải.
- **Connection draining**: gỡ server nhưng chờ kết nối đang chạy xong.
- **GSLB**: chia tải giữa nhiều site/DC bằng DNS.

---

## 7. KVM

### 7.1 Ảo hóa là gì? Có những loại nào?
- **Ảo hóa**: chạy nhiều máy ảo (VM) độc lập trên cùng một phần cứng → tận dụng tài nguyên, cô lập, linh hoạt.
- **Theo đối tượng**: ảo hóa server, mạng, lưu trữ, desktop, ứng dụng.
- **Theo kỹ thuật (ảo hóa server)**:

| Loại | Đặc điểm |
|---|---|
| **Full virtualization** | Guest OS chạy nguyên bản, không biết mình bị ảo hóa; tương thích cao |
| **Paravirtualization** | Guest OS/driver được sửa để gọi trực tiếp hypervisor → I/O nhanh hơn (Xen PV, virtio) |
| **Hardware-assisted** | CPU hỗ trợ ảo hóa (Intel VT-x, AMD-V) → gần như native; KVM, ESXi, Hyper-V dùng cách này |
| **Container (mức OS)** | Dùng chung kernel host, nhẹ và nhanh nhưng cô lập kém hơn VM |

- **Hypervisor**: **Type 1** chạy trực tiếp trên phần cứng (ESXi, Xen, Hyper-V, KVM); **Type 2** chạy như ứng dụng trên OS (VirtualBox, VMware Workstation).

### 7.2 KVM là gì? Thuộc loại nào? So sánh với hypervisor khác?
- **KVM (Kernel-based Virtual Machine)**: module trong nhân Linux, biến Linux thành hypervisor, dùng ảo hóa có hỗ trợ phần cứng. Mã nguồn mở.
- Dùng để tạo, chạy VM trên server; là nền tảng của OpenStack, oVirt, Proxmox, nhiều cloud công cộng.
- **Phân loại**: thường xếp **Type 1** (nhân Linux làm hypervisor, chạy trực tiếp trên phần cứng). Một số tài liệu coi là giữa Type 1 và Type 2 vì cài trên OS Linux đầy đủ.

| | KVM | VMware ESXi | Xen | Hyper-V | VirtualBox |
|---|---|---|---|---|---|
| Loại | Type 1 | Type 1 | Type 1 | Type 1 | Type 2 |
| Giấy phép | Mã nguồn mở | Thương mại | Mã nguồn mở | Thương mại | Mở / thương mại |
| Quản lý | libvirt, virsh | vCenter | xl, XenCenter | Hyper-V Manager | GUI |
| Điểm mạnh | Tận dụng Linux, linh hoạt | Hệ sinh thái đầy đủ | Cô lập tốt | Tích hợp Windows | Dễ dùng, cho lab |

### 7.3 Thành phần của KVM và cách hoạt động?
- **KVM module**: ảo hóa CPU và RAM, giao tiếp qua `/dev/kvm`.
- **QEMU**: tiến trình user-space giả lập thiết bị (disk, NIC, BIOS…). Mỗi VM là **1 tiến trình QEMU**, mỗi **vCPU là 1 thread**.
- **libvirt**: lớp quản lý chung cho VM, network, storage (dùng bởi `virsh`, `virt-manager`).
- **virtio**: driver ảo hóa giúp disk/mạng nhanh gần như thật.
- **Cách hoạt động**: CPU có 2 chế độ (host và guest). Guest chạy trực tiếp trên CPU thật; khi cần thao tác đặc quyền (I/O…), CPU **VM Exit** về host xử lý rồi **VM Entry** quay lại guest. Bộ nhớ được dịch địa chỉ 2 tầng bằng phần cứng (**EPT/NPT**).
- **Quan hệ với OS**: KVM dùng luôn thành phần của Linux: scheduler (xếp lịch vCPU như thread), quản lý RAM, driver, cgroups (giới hạn tài nguyên), SELinux/AppArmor (cô lập).

### 7.4 Các chế độ card mạng trong KVM?
- **NAT**: VM nằm sau virbr0, dnsmasq cấp DHCP/DNS.
- **Bridge**: VM nối vào bridge chứa card mạng thật, như máy thật trong LAN.
- **Isolated (Host-only)**: chỉ VM–VM và VM–host.
- **Routed**: định tuyến tới LAN thật, không NAT.
- **macvtap**: nối thẳng VM lên card thật, không cần bridge (VM không nói chuyện trực tiếp với host qua cùng card).
- **PCI passthrough / SR-IOV**: gán thẳng card thật cho VM → nhanh nhất nhưng kém linh hoạt.
- **Model vNIC**: `virtio` (nhanh, nên dùng), `e1000` (tương thích rộng), `rtl8139` (cũ).

### 7.5 Raw, qcow2, ISO? Thin và Thick provisioning?

| | RAW | QCOW2 | ISO |
|---|---|---|---|
| Là gì | Ảnh đĩa thô | Ảnh đĩa có metadata (copy-on-write) | Ảnh đĩa CD/DVD, chỉ đọc |
| Dùng để | Đĩa VM | Đĩa VM | Cài OS |
| Snapshot | Không | Có | Không |
| Thin provisioning | Nhờ sparse file | Có sẵn | Không áp dụng |
| Backing file (clone liên kết) | Không | Có | Không |
| Nén / mã hóa | Không | Có | Không |
| Hiệu năng | Nhanh nhất | Chậm hơn một chút | Không áp dụng |

- **Khi nào dùng**: RAW cho workload I/O nặng (DB); QCOW2 cho lab, template, cần snapshot/clone; ISO chỉ để cài đặt.
- **Hiệu năng**: RAW nhanh hơn vì không phải tra metadata; chênh lệch giảm nếu QCOW2 được preallocation và chạy trên SSD.
- **Thin provisioning**: cấp dung lượng *ảo* lớn, chỉ dùng dung lượng thật khi có dữ liệu → tiết kiệm, nhưng có rủi ro hết ổ thật.
- **Thick provisioning**: cấp đủ dung lượng thật ngay từ đầu → ổn định, ít phân mảnh nhưng tốn dung lượng.

### 7.6 Công cụ thao tác KVM và các thao tác chính?
- **CLI**: `virsh` (quản lý chính), `virt-install` (tạo VM), `virt-clone` (clone), `qemu-img` (thao tác ảnh đĩa), `virt-viewer` (xem console), `virt-sysprep` (dọn VM trước khi clone).
- **GUI/Web**: `virt-manager`, Cockpit, WebVirtCloud.
- **Vòng đời VM**: define → start → suspend/resume → shutdown (tắt êm) / destroy (cắt nguồn) → undefine (xóa định nghĩa). Ngoài ra: autostart, console, edit, attach/detach thiết bị, snapshot, migrate.

### 7.7 Các option khi tạo VM?
- **CPU**: số vCPU, topology (socket/core/thread); chế độ CPU: `host-passthrough` (nhanh nhất, khó migrate), `host-model`, `custom` (dễ migrate); CPU pinning, NUMA.
- **RAM**: dung lượng tối đa/hiện tại (ballooning), hugepages.
- **Disk**: định dạng (raw/qcow2); bus (`virtio` nhanh nhất, scsi, sata, ide); **cache mode** (`none` phổ biến và an toàn, `writeback` nhanh nhưng rủi ro mất điện, `writethrough` an toàn nhưng chậm); discard/TRIM; thứ tự boot.
- **NIC**: nguồn (network/bridge/macvtap), model (virtio/e1000), MAC, multiqueue.
- **Khác**: firmware BIOS/UEFI, machine type (i440fx/q35), đồ họa (VNC/SPICE).

### 7.8 Tính năng đối với VM: tạo, xóa, sửa, backup, clone, snapshot?
- **Tạo**: từ ISO, từ image/template, từ XML, hoặc clone.
- **Xóa**: `undefine` (xóa định nghĩa, có thể xóa cả disk). **Sửa**: chỉnh XML hoặc thay đổi nóng một số thiết bị.
- **Backup**: backup **disk + file XML**. Cold backup (tắt VM rồi chép) đơn giản nhất; live backup dùng snapshot ngoài + blockcommit; bản mới hỗ trợ incremental.
- **Clone**:
  - **Full clone**: chép toàn bộ disk, độc lập.
  - **Linked clone**: dùng backing file, chỉ lưu phần khác biệt → nhanh, tiết kiệm nhưng phụ thuộc disk gốc.
  - Sau clone phải đổi: MAC, hostname, machine-id, SSH host key, IP.
- **Snapshot**: lưu trạng thái VM để quay lại khi cần.
  - **Internal**: lưu ngay trong file qcow2 (chỉ qcow2).
  - **External**: tạo file overlay mới, file gốc thành chỉ đọc (dùng được với raw, hợp backup live).
  - Cơ chế qcow2: khi ghi, cấp cluster mới và cập nhật bảng ánh xạ; quay về snapshot = quay về bảng ánh xạ cũ.
  - Snapshot **không thay thế backup** vì cùng nằm trên một storage.

### 7.9 Đường đi gói tin với 3 chế độ card mạng
```
NAT:      VM → tap → virbr0 → [routing + NAT của host] → card thật → LAN/Internet
Bridge:   VM → tap → br0 ── (cùng L2) ── card thật → switch vật lý → LAN/Internet
Isolated: VM → tap → bridge ảo (không card thật, không NAT) → VM khác / host
```

### 7.10 Linux Bridge là gì?
- **Switch L2 ảo trong nhân Linux**: các thiết bị mạng (card thật, tap, veth) được gắn vào làm port.
- Hoạt động: học **MAC → port** vào bảng **FDB**, chuyển frame theo MAC đích; MAC lạ hoặc broadcast thì gửi ra mọi port (flood).
- Hỗ trợ STP, VLAN filtering, IGMP snooping. Bridge có thể mang IP riêng.
- Khi gắn card thật vào bridge: card chuyển sang chế độ **promiscuous** và IP chuyển lên bridge.
- **tap**: card ảo nối VM với host. **veth**: cặp card ảo nối hai namespace/bridge.

### 7.11 Switch ảo và card thật liên quan thế nào? NAT không cần bridge vẫn ra được Internet?
- Xem mục **2** (các câu về NAT và về quan hệ switch ảo – card thật).
- Tóm tắt: libvirt có sẵn virbr0 + NAT + dnsmasq nên VM ra Internet được mà không cần bridge vật lý.

### 7.12 VM được lưu ở đâu? Các file là gì?
KVM **không có một thư mục chứa mọi thứ của VM**; disk và cấu hình lưu riêng:

| Thành phần | Vị trí mặc định | Ý nghĩa |
|---|---|---|
| Disk (qcow2/raw) | `/var/lib/libvirt/images/` | Dữ liệu đĩa của VM |
| XML của VM | `/etc/libvirt/qemu/<vm>.xml` | Cấu hình VM (CPU, RAM, disk, NIC) |
| Autostart | `/etc/libvirt/qemu/autostart/` | Link tới XML của VM tự bật |
| XML của network | `/etc/libvirt/qemu/networks/` | Cấu hình virtual network |
| XML storage pool | `/etc/libvirt/storage/` | Cấu hình storage pool |
| Trạng thái chạy | `/var/lib/libvirt/qemu/` | Metadata snapshot, file save, NVRAM (UEFI) |
| Lease DHCP | `/var/lib/libvirt/dnsmasq/` | Cấu hình/lease của dnsmasq |
| Log VM | `/var/log/libvirt/qemu/<vm>.log` | Log tiến trình QEMU |

- **Overlay**: file chứa phần thay đổi sau snapshot ngoài. **Backing file**: file nền chỉ đọc.
- Nên sửa XML bằng `virsh edit` để được kiểm tra cú pháp.

### 7.13 File XML của VM và network
- **XML của VM** (`<domain type='kvm'>`) mô tả:
  - `<name>`, `<uuid>`: tên và định danh.
  - `<memory>`, `<vcpu>`: RAM và số vCPU.
  - `<os>`: machine type, firmware, thứ tự boot. `<cpu>`: chế độ CPU.
  - `<devices>`: `<disk>` (file, bus, cache), `<interface>` (loại, nguồn, model, MAC), `<graphics>`, `<console>`, `<controller>`…
- **XML của network** (`<network>`):
  - `<name>`, `<uuid>`; `<forward mode='nat|route|bridge'>` (không có forward = isolated).
  - `<bridge name=...>`; `<ip>` kèm `<dhcp>` (dải IP cấp, reservation theo MAC); `<dns>`.
- **Tạo VM/network từ XML**: viết XML → **define** (lưu lâu dài) → **start**. Network dùng `net-define` → `net-start` → `net-autostart`. Dùng **create** thì chỉ chạy tạm (mất khi tắt).
- **Sửa cấu hình**: sửa XML bằng `virsh edit`, có hiệu lực sau khi tắt/bật lại VM. Một số thay đổi áp dụng nóng bằng `--live` (đang chạy), `--config` (lưu lâu dài).

### 7.14 virsh và các option thông dụng
- `virsh` là CLI của libvirt, kết nối tới hypervisor qua URI: `qemu:///system` (máy local), `qemu+ssh://host/system` (từ xa qua SSH).

| Nhóm | Lệnh tiêu biểu |
|---|---|
| VM | `list --all`, `start`, `shutdown`, `destroy`, `reboot`, `suspend`, `resume`, `autostart`, `define`, `undefine`, `edit`, `dumpxml`, `dominfo`, `console` |
| Thiết bị | `attach-disk`, `detach-disk`, `attach-interface`, `domblklist`, `domiflist` |
| Network | `net-list`, `net-define`, `net-start`, `net-autostart`, `net-edit`, `net-dhcp-leases` |
| Storage | `pool-list`, `pool-define`, `pool-start`, `vol-list`, `vol-clone` |
| Snapshot | `snapshot-create-as`, `snapshot-list`, `snapshot-revert`, `snapshot-delete` |
| Di chuyển / lưu | `migrate`, `save`, `restore`, `managedsave` |

- Phân biệt: `shutdown` tắt êm (gửi tín hiệu ACPI); `destroy` cắt nguồn đột ngột (**không xóa VM**); `undefine` mới xóa định nghĩa.

### 7.15 Migrate VM và khôi phục VM bị chết
- **Các kiểu migrate**:
  - **Offline (cold)**: tắt VM, chuyển disk + XML sang host mới → có downtime.
  - **Live**: VM đang chạy được chuyển sang host khác, gián đoạn rất ngắn.
  - **Shared storage**: disk nằm trên storage dùng chung (NFS, Ceph…) → chỉ chuyển RAM và trạng thái.
  - **Block migration**: chuyển cả disk, không cần shared storage nhưng lâu.
- **Cơ chế pre-copy**: (1) chép RAM sang host đích khi VM vẫn chạy → (2) chép lặp lại các trang RAM bị thay đổi (dirty page) → (3) khi còn ít thì tạm dừng VM, chép nốt phần còn lại → (4) bật VM ở host đích.
- **Post-copy**: chuyển VM sang đích trước, trang RAM thiếu mới lấy dần. Chắc chắn hoàn tất nhưng rủi ro nếu mất kết nối.
- **Điều kiện live migration**: CPU tương thích, QEMU/libvirt tương thích, có shared storage (hoặc block migration), mạng ở host đích tương ứng, hai host kết nối được với nhau (SSH).
- **Khôi phục VM bị chết**:

| Tình huống | Cách khôi phục |
|---|---|
| VM treo, host còn sống | Xem log, tắt cưỡng bức rồi bật lại; nếu hỏng disk thì quay lại snapshot hoặc restore từ backup |
| Host chết, disk trên shared storage | Dùng XML backup để define VM trên host khác rồi start (có thể tự động bằng HA như Pacemaker, cần fencing để tránh 2 host cùng ghi 1 disk) |
| Host chết, disk cục bộ | Restore disk + XML từ backup |
| Lỡ `undefine` VM | Define lại từ XML backup (disk vẫn còn) |

- Nguyên tắc: **backup định kỳ cả disk và XML**, snapshot không thay thế backup.

### 7.16 Clone disk
- **Mục đích**: nhân bản VM, tạo VM từ template, đổi định dạng ảnh đĩa.
- **Các cách**:
  - **Sao chép đầy đủ**: bản độc lập, tốn dung lượng.
  - **`qemu-img convert`**: đổi định dạng (raw ↔ qcow2), có thể nén, bỏ vùng trống.
  - **Linked clone (backing file)**: chỉ lưu phần khác biệt, phụ thuộc disk gốc (không được sửa file gốc).
  - **`virt-clone`**: clone cả VM (copy disk + tạo XML mới với UUID/MAC mới).
- **Sau khi clone**: đổi hostname, machine-id, SSH host key, MAC, IP (dùng `virt-sysprep` hoặc cloud-init).
- **Lưu ý**: nên tắt VM hoặc tạo snapshot trước khi clone để dữ liệu nhất quán.