# Một số trường hợp lỗi gặp phải và cách khắc phục
## Xóa nhầm file ổ đĩa của máy ảo đang chạy
Trong quá trình lab, sau khi chuyển vm1 từ Host 1 sang Host 2, vô tình xóa nhầm ổ đĩa của vm1 trên Host 2 trong khi vm1 đang chạy trên Host 2.

Vậy lúc này có còn cứu được dữ liệu hay không? 

Có thể cứu tuy nhiên lưu ý: Nếu bạn tắt máy ảo (virsh destroy), khởi động lại Host 2, hoặc tiến trình QEMU dừng lại, file descriptor bị đóng, hệ điều hành Linux sẽ xóa vĩnh viễn toàn bộ dữ liệu của vm1

Thực hiện lần lượt các lệnh sau trên Host 2:

### Tạm dừng máy ảo để đóng đóng băng dữ liệu (Tránh ghi đĩa khi copy)
```Bash
virsh suspend vm1
```
### Tìm ID tiến trình (PID) của vm1
```Bash
PID=$(pgrep -f "guest=vm1")
```
### Tìm File Descriptor (FD) mà QEMU đang mở file bị xóa
```Bash
ls -l /proc/$PID/fd | grep deleted
```
Kết quả mẫu xuất ra màn hình sẽ có dạng:
```
lrwx------ 1 root root 64 Oct 30 16:20 11 -> /var/lib/libvirt/images/vm1.qcow2 (deleted)
```
Trong ví dụ trên, con số 11 (trước dấu ->) chính là số hiệu File Descriptor.

### Khôi phục lại file đĩa từ bộ nhớ /proc
Chạy lệnh cp trỏ đúng vào số File Descriptor tìm được ở Bước 3 (thay 11 bằng số thực tế của bạn):

```Bash
cp /proc/$PID/fd/11 /var/lib/libvirt/images/vm1.qcow2
```
### Phân lại quyền chuẩn cho Libvirt
```Bash
chown libvirt-qemu:kvm /var/lib/libvirt/images/vm1.qcow2
```
### Kích hoạt lại máy ảo
```Bash
virsh resume vm1
Kiểm tra sau khi khôi phục
```
Chạy lại lệnh kiểm tra trên Host 2:

```Bash
ls -lh /var/lib/libvirt/images/vm1.qcow2
```

## Trường hợp khởi tạo/ Reboot Vm trên HOST xong nhưng chạy lệnh List thì không có IP nào
Ví dụ khi tạo khởi tạo VM, Reboot VM, mặc dù bạn đã biết rằng mạng mặc định Linux Bridge (virbr0) đã được tạo, các máy ảo đã kết nối tới nhưng không máy ảo nào có IP.

Đã kết nối tới mạng default
```
root@manh-lab-01:~# bridge link show
15: vnet4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master virbr0 state forwarding priority 32 cost 2
17: vnet6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master virbr0 state forwarding priority 32 cost 2
18: vnet7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master virbr0 state forwarding priority 32 cost 2
```
Không có IP
```
root@manh-lab-02:~# virsh net-dhcp-leases default
 Expiry Time   MAC address   Protocol   IP address   Hostname   Client ID or DUID
-----------------------------------------------------------------------------------

```
Trường hợp này xảy ra do hệ thống mạng bên trong các máy ảo chưa được bật

Để giải quyết, chúng ta tiến hành truy cập console vào các máy ảo nhỏ để thực hiện bật mạng và dịch vụ dhcp xin cấp phát địa chỉ IP cho máy ảo

Đối với hệ điều hành alpine, mặc định không có mật khẩu root. Bạn có thể dễ dàng truy cập vào console

Đối với Ubuntu Cloud Image, bạn có thể cài đặt mật khẩu root qua câu lệnh sau:
- Cài đặt mật khâu root: `123456`
```
virt-customize -a /path/to/ubuntu-cloud-image.qcow2 --root-password password:123456
```
- Cho phép SSH bằng Password
```
virt-customize -a /path/to/ubuntu-cloud-image.qcow2 --run-command 'sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config'
```
Bây giờ chúng ta tiến hành bật mạng
- Đối với alpine
```
ip link set eth0 up
udhcpc -i eth0
```
- Đối với Ubuntu Cloud Image
```
# Bật systemd-networkd
systemctl enable --now systemd-networkd

# Tạo cấu hình dhcp
cat > /etc/netplan/01-netcfg.yaml <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: true
EOF

# Áp dụng cấu hình
netplan generate
netplan apply
```

Kiểm tra lại sau khi bật mạng cho các máy ảo
```
root@manh-lab-01:~# virsh net-dhcp-leases default
 Expiry Time           MAC address         Protocol   IP address           Hostname   Client ID or DUID
------------------------------------------------------------------------------------------------------------------------------------------------
 2026-11-04 09:22:02   52:54:00:7d:aa:08   ipv4       192.168.122.192/24   -          01:52:54:00:7d:aa:08
 2026-11-04 09:20:44   52:54:00:9a:e6:72   ipv4       192.168.122.46/24    -          01:52:54:00:9a:e6:72
 2026-11-04 09:36:14   52:54:00:b6:d1:c9   ipv4       192.168.122.78/24    ubuntu     ff:56:50:4d:98:00:02:00:00:ab:11:25:5d:4b:4b:1f:92:51:4a
```


