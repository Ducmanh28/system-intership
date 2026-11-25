#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OpenStack All-in-One Prerequisites & Infrastructure Installer (Ubuntu 24.04)
# Target Host : controller (172.16.66.60/24, ens160)
# Specs       : 6 vCPU, 8 GB RAM, 80 GB Disk
# Scope       : OS prep, Swap, MariaDB (+ databases), RabbitMQ, Memcached, Etcd
#               (Does NOT install Keystone, Glance, Placement, Nova, Neutron)
# ==============================================================================

CONTROLLER_IP="172.16.66.60"
CONTROLLER_HOST="controller"
DB_ROOT_PASS="28072003"
DB_SVC_PASS="28072003"
RABBIT_PASS="28072003"
SWAP_SIZE="4G"
SWAPPINESS="10"

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Vui lòng chạy script với quyền root (sudo -i hoặc sudo bash $0)." >&2
  exit 1
fi

log_step() {
  echo ""
  echo "======================================================================"
  echo "[INFO] $1"
  echo "======================================================================"
}

# 1. Kiểm tra ảo hóa lồng nhau (Nested Virtualization)
log_step "1/6 - Kiểm tra hỗ trợ ảo hóa phần cứng (KVM/Nested Virtualization)"
VIRT_CORES=$(egrep -c '(vmx|svm)' /proc/cpuinfo || true)
echo "Số lõi CPU hỗ trợ vmx/svm: ${VIRT_CORES}"
if [[ "${VIRT_CORES}" -eq 0 ]]; then
  echo "[WARN] Không phát hiện cờ vmx/svm. Nếu chạy KVM lồng nhau trên vCenter, hãy bật 'Expose hardware assisted virtualization to the guest OS'."
fi

# 2. Cấu hình Swap 4GB và vm.swappiness=10
log_step "2/6 - Cấu hình Swap ${SWAP_SIZE} và vm.swappiness=${SWAPPINESS}"
if ! swapon --show | grep -q '/swapfile'; then
  if [[ ! -f /swapfile ]]; then
    fallocate -l "${SWAP_SIZE}" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
  fi
  swapon /swapfile
fi

if ! grep -q '^/swapfile ' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

sysctl -w "vm.swappiness=${SWAPPINESS}" >/dev/null
cat <<EOF > /etc/sysctl.d/99-openstack-swappiness.conf
vm.swappiness=${SWAPPINESS}
EOF
free -h

# 3. Đặt Hostname và /etc/hosts
log_step "3/6 - Thiết lập hostname '${CONTROLLER_HOST}' và /etc/hosts"
hostnamectl set-hostname "${CONTROLLER_HOST}"

python3 - <<PY
ip = "${CONTROLLER_IP}"
host = "${CONTROLLER_HOST}"
hosts_path = "/etc/hosts"

with open(hosts_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

filtered = [
    line for line in lines
    if not (line.strip().startswith(ip + " ") or line.strip().endswith(" " + host) or f"\t{host}" in line)
]
if not any("127.0.0.1" in l and "localhost" in l for l in filtered):
    filtered.insert(0, "127.0.0.1\tlocalhost\n")
filtered.append(f"{ip}\t{host}\n")

with open(hosts_path, "w", encoding="utf-8") as f:
    f.writelines(filtered)
PY

ping -c 2 "${CONTROLLER_HOST}" >/dev/null && echo "Phân giải ${CONTROLLER_HOST} -> ${CONTROLLER_IP} thành công."

# 4. Cập nhật gói, đồng bộ thời gian (chrony) và cài công cụ CLI/config
log_step "4/6 - Cập nhật hệ thống, cài chrony, python3-openstackclient và crudini"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y chrony python3-openstackclient crudini curl

systemctl enable --now chrony
chronyc tracking | head -n 6 || true

# 5. Cài đặt, tối ưu RAM và khởi tạo Database trên MariaDB
log_step "5/6 - Cài đặt MariaDB và tạo sẵn Database cho các dịch vụ OpenStack"
apt-get install -y mariadb-server python3-pymysql

cat <<EOF > /etc/mysql/mariadb.conf.d/99-openstack.cnf
[mysqld]
bind-address = ${CONTROLLER_IP}
default-storage-engine = innodb
innodb_file_per_table = on
innodb_buffer_pool_size = 512M
max_connections = 512
collation-server = utf8_general_ci
character-set-server = utf8
EOF

systemctl restart mariadb
systemctl enable mariadb

# Đặt mật khẩu root MariaDB an toàn (hỗ trợ cả trường hợp root đang dùng unix_socket hoặc đã có pass)
mysql -u root <<EOF 2>/dev/null || mysql -u root -p"${DB_ROOT_PASS}" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_ROOT_PASS}');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

CREATE DATABASE IF NOT EXISTS keystone;
CREATE DATABASE IF NOT EXISTS glance;
CREATE DATABASE IF NOT EXISTS placement;
CREATE DATABASE IF NOT EXISTS nova_api;
CREATE DATABASE IF NOT EXISTS nova;
CREATE DATABASE IF NOT EXISTS nova_cell0;
CREATE DATABASE IF NOT EXISTS neutron;

CREATE USER IF NOT EXISTS 'keystone'@'localhost' IDENTIFIED BY '${DB_SVC_PASS}';
CREATE USER IF NOT EXISTS 'keystone'@'%' IDENTIFIED BY '${DB_SVC_PASS}';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%';

CREATE USER IF NOT EXISTS 'glance'@'localhost' IDENTIFIED BY '${DB_SVC_PASS}';
CREATE USER IF NOT EXISTS 'glance'@'%' IDENTIFIED BY '${DB_SVC_PASS}';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%';

CREATE USER IF NOT EXISTS 'placement'@'localhost' IDENTIFIED BY '${DB_SVC_PASS}';
CREATE USER IF NOT EXISTS 'placement'@'%' IDENTIFIED BY '${DB_SVC_PASS}';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%';

CREATE USER IF NOT EXISTS 'nova'@'localhost' IDENTIFIED BY '${DB_SVC_PASS}';
CREATE USER IF NOT EXISTS 'nova'@'%' IDENTIFIED BY '${DB_SVC_PASS}';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%';

CREATE USER IF NOT EXISTS 'neutron'@'localhost' IDENTIFIED BY '${DB_SVC_PASS}';
CREATE USER IF NOT EXISTS 'neutron'@'%' IDENTIFIED BY '${DB_SVC_PASS}';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%';

FLUSH PRIVILEGES;
EOF

# 6. Cài đặt RabbitMQ, Memcached và Etcd
log_step "6/6 - Cài đặt RabbitMQ, Memcached và Etcd"
apt-get install -y rabbitmq-server
systemctl enable --now rabbitmq-server

if rabbitmqctl list_users | awk '{print $1}' | grep -qx "openstack"; then
  rabbitmqctl change_password openstack "${RABBIT_PASS}"
else
  rabbitmqctl add_user openstack "${RABBIT_PASS}"
fi
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

apt-get install -y memcached python3-memcache
sed -i "s/^-l .*/-l ${CONTROLLER_IP}/" /etc/memcached.conf
sed -i "s/^-m .*/-m 128/" /etc/memcached.conf
systemctl restart memcached
systemctl enable memcached

apt-get install -y etcd-server
cat <<EOF > /etc/default/etcd
ETCD_NAME="${CONTROLLER_HOST}"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER="${CONTROLLER_HOST}=http://${CONTROLLER_IP}:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${CONTROLLER_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://${CONTROLLER_IP}:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://${CONTROLLER_IP}:2379"
EOF
systemctl restart etcd
systemctl enable etcd

echo ""
echo "======================================================================"
echo "[DONE] Hoàn tất cài đặt hạ tầng nền tảng trên ${CONTROLLER_HOST} (${CONTROLLER_IP})."
echo "Chưa cài đặt các dịch vụ OpenStack (Keystone, Glance, Placement, Nova, Neutron)."
echo "======================================================================"