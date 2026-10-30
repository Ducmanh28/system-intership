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