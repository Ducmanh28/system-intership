# Keystone – File Cấu Hình (`keystone.conf`)

> **File chính:** `/etc/keystone/keystone.conf`  
> **Định dạng:** INI — chia theo `[section]`, mỗi dòng là `key = value`  
> **File mẫu trên server:** `/usr/share/keystone/keystone.conf.sample`  
> **Docs chính thức:** [Config Options](https://docs.openstack.org/keystone/latest/configuration/config-options.html)

Tệp cấu hình `keystone.conf` trong môi trường DevStack thường chỉ khai báo các tham số được tùy chỉnh hoặc ghi đè so với giá trị mặc định của hệ thống; các cấu hình không xuất hiện trong tệp không đồng nghĩa với việc chúng không tồn tại, mà thường được Keystone tự động sử dụng từ bộ giá trị mặc định được định nghĩa sẵn trong mã nguồn.

## 1. Cấu trúc file INI

```ini
[section]
key = value
```

### Các kiểu giá trị

| Kiểu           | Ví dụ                                   | Ghi chú                          |
|----------------|-----------------------------------------|----------------------------------|
| `boolean`      | `true` / `false`                        | Không phân biệt hoa/thường       |
| `integer`      | `64`, `3600`                            |                                  |
| `float`        | `0.25`                                  |                                  |
| `string`       | `fernet`, `'co khoang trang'`           | Dùng dấu nháy nếu có dấu cách   |
| `list`         | `password,token,application_credential` | Phân cách bằng dấu phẩy          |
| `multi-valued` | Nhiều dòng cùng key                     | Thường gặp ở `[oslo_messaging]` |

### Biến tham chiếu (Variable Substitution)

```ini
rabbit_host = controller
transport_url = rabbit://$rabbit_host:5672/

# Dùng $$ để viết ký tự $ thật
ldap_dns_password = $$xkj432
```

### Lưu ý vận hành

- Keystone load `keystone.conf` tự động; dùng file khác: `--config-file /path/to/file`
- Sau mỗi lần chỉnh sửa phải **restart service:**

```bash
# Nếu dùng Apache (phổ biến nhất)
systemctl restart httpd        # RHEL/CentOS
systemctl restart apache2      # Ubuntu/Debian

# Nếu chạy trực tiếp
systemctl restart keystone
```

---

## 2. Cấu hình tối thiểu để chạy

> Đây là những gì **bắt buộc phải có** trước khi Keystone hoạt động được.

```ini
[DEFAULT]
log_dir = /var/log/keystone

[database]
connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@controller/keystone

[token]
provider = fernet

[cache]
enabled = True
backend = dogpile.cache.memcached
backend_argument = url:127.0.0.1:11211

[fernet_tokens]
key_repository = /etc/keystone/fernet-keys
max_active_keys = 3
```

**Sau đó chạy các lệnh khởi tạo:**

```bash
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage db_sync
keystone-manage bootstrap \
  --bootstrap-password ADMIN_PASS \
  --bootstrap-admin-url http://controller:5000/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
```

---

## 3. Section `[DEFAULT]` – Cài đặt chung

```ini
[DEFAULT]
debug = false
log_dir = /var/log/keystone
list_limit = 500
```

| Option                      | Mặc định | Giá trị khuyến nghị | Mô tả                                                              |
|-----------------------------|----------|---------------------|--------------------------------------------------------------------|
| `debug`                     | `False`  | `False` (prod)      | Bật log chi tiết. **Tắt trên production vì lộ thông tin nội bộ**  |
| `insecure_debug`            | `False`  | `False` (prod)      | Trả về lý do lỗi trong HTTP response. **Tuyệt đối không bật production** |
| `admin_token`               | –        | **Không dùng**      | Deprecated. Dùng `keystone-manage bootstrap` thay thế             |
| `public_endpoint`           | –        | Để trống            | URL base của Keystone — chỉ set nếu Keystone không tự phát hiện được |
| `list_limit`                | `None`   | `500`               | Giới hạn số item trả về khi list. `None` = không giới hạn (nguy hiểm với hệ thống lớn) |
| `max_project_tree_depth`    | `5`      | `5`                 | Độ sâu cây project lồng nhau. Giá trị cao làm query DB chậm      |
| `max_db_limit`              | `1000`   | `1000`              | Giới hạn số bản ghi tối đa một query DB trả về                    |
| `max_param_size`            | `64`     | `64`                | Giới hạn độ dài ID/name (bytes)                                   |
| `max_token_size`            | `255`    | `255`               | 255 là đủ cho Fernet; JWS cần giá trị lớn hơn                    |
| `strict_password_check`     | `False`  | `True` (prod)       | `True` = từ chối password quá dài; `False` = tự động cắt bớt     |
| `notification_format`       | `cadf`   | `cadf`              | Định dạng audit event. `cadf` là chuẩn OpenStack                  |
| `executor_thread_pool_size` | `64`     | `64`                | Số thread xử lý request đồng thời                                 |

> **Tip:** Khi debug trên môi trường test, bật `debug = true` + `insecure_debug = true` để xem lỗi đầy đủ. Nhớ tắt trước khi lên production.

---

## 4. Section `[database]` – Kết nối Cơ sở dữ liệu

```ini
[database]
connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@controller/keystone
max_pool_size = 10
max_overflow = 20
pool_timeout = 30
pool_recycle = 3600
```

| Option           | Mặc định | Mô tả                                                               |
|------------------|----------|---------------------------------------------------------------------|
| `connection`     | **Bắt buộc** | Connection string. Hỗ trợ MySQL, PostgreSQL, SQLite               |
| `max_pool_size`  | `5`      | Số kết nối DB duy trì trong pool                                    |
| `max_overflow`   | `10`     | Số kết nối dự phòng được phép vượt `max_pool_size`                  |
| `pool_timeout`   | `30`     | Giây chờ lấy kết nối từ pool trước khi báo lỗi                     |
| `pool_recycle`   | `3600`   | Tái tạo kết nối sau N giây (tránh lỗi "MySQL server has gone away") |

**Ví dụ connection string:**

```ini
# MySQL (phổ biến nhất)
connection = mysql+pymysql://keystone:pass@10.0.0.11/keystone

# PostgreSQL
connection = postgresql+psycopg2://keystone:pass@10.0.0.11/keystone

# SQLite (chỉ dùng cho dev/test)
connection = sqlite:////var/lib/keystone/keystone.db
```

---

## 5. Section `[token]` – Cấu hình Token

```ini
[token]
provider = fernet
expiration = 3600
caching = True
```

| Option                 | Mặc định  | Mô tả                                                           |
|------------------------|-----------|-----------------------------------------------------------------|
| `provider`             | `fernet`  | Loại token: `fernet` (khuyến nghị) hoặc `jws`                  |
| `expiration`           | `3600`    | Thời gian sống của token (giây). 3600 = 1 giờ                  |
| `allow_expired_window` | `172800`  | Cho phép dùng token đã hết hạn trong N giây (dùng để revoke)   |
| `caching`              | `True`    | Bật cache kết quả validate token                                |
| `cache_time`           | –         | Thời gian cache token (nên nhỏ hơn hoặc bằng `expiration`)     |

### So sánh Fernet vs JWS

| Tiêu chí         | Fernet                        | JWS                              |
|------------------|-------------------------------|----------------------------------|
| Chuẩn            | Tự Keystone định nghĩa        | RFC 7515 (JSON Web Signature)    |
| Kích thước token | Nhỏ (~250 bytes)              | Lớn hơn                          |
| Xác thực         | Cần quản lý `fernet_rotate`   | Dùng public/private key pair     |
| Phù hợp          | **Đa số deployment**          | Khi cần tích hợp chuẩn JWT       |
| Có từ phiên bản  | Ocata                         | Stein                            |

> **Khuyến nghị:** Dùng `fernet` cho hầu hết trường hợp. Chỉ dùng `jws` khi có yêu cầu đặc biệt về chuẩn JWT.

---

## 6. Section `[fernet_tokens]` – Quản lý khóa Fernet

```ini
[fernet_tokens]
key_repository = /etc/keystone/fernet-keys
max_active_keys = 3
```

| Option             | Mặc định                    | Mô tả                                                         |
|--------------------|-----------------------------|---------------------------------------------------------------|
| `key_repository`   | `/etc/keystone/fernet-keys` | Thư mục chứa các khóa Fernet. Phải thuộc user `keystone`     |
| `max_active_keys`  | `3`                         | Số khóa được phép tồn tại. Khi rotate: key cũ nhất bị xóa    |

### Vòng đời khóa Fernet

```
[staged] --(rotate)--> [primary] --(rotate)--> [secondary] --(rotate)--> [xóa]
```

- **Primary key (0):** Dùng để ký token mới
- **Secondary keys (1, 2, ...):** Chỉ dùng để xác thực token cũ còn hiệu lực
- **Staged key:** Key chuẩn bị trở thành primary sau lần rotate tiếp theo

### Các lệnh quản lý

```bash
# Khởi tạo lần đầu
keystone-manage fernet_setup \
  --keystone-user keystone \
  --keystone-group keystone

# Rotate định kỳ (nên đặt cron job)
keystone-manage fernet_rotate \
  --keystone-user keystone \
  --keystone-group keystone

# Ví dụ cron job rotate mỗi 6 giờ:
# 0 */6 * * * keystone-manage fernet_rotate --keystone-user keystone --keystone-group keystone
```

> **Lưu ý multi-node:** Phải đồng bộ thư mục `fernet-keys` giữa các Keystone node (dùng rsync hoặc shared storage). Nếu không đồng bộ, một số node sẽ không validate được token do node khác ký.

---

## 7. Section `[credential]` – Mã hóa Credential

> Thường bị bỏ qua nhưng quan trọng! Keystone lưu application credential và EC2 credential trong DB — section này cấu hình mã hóa chúng.

```ini
[credential]
driver = sql
provider = fernet
key_repository = /etc/keystone/credential-keys
```

| Option           | Mặc định                        | Mô tả                                                        |
|------------------|---------------------------------|--------------------------------------------------------------|
| `driver`         | `sql`                           | Backend lưu credential                                       |
| `provider`       | `fernet`                        | Phương thức mã hóa credential                                |
| `key_repository` | `/etc/keystone/credential-keys` | Thư mục chứa khóa mã hóa (tách biệt với fernet-keys)        |

```bash
# Khởi tạo credential keys
keystone-manage credential_setup \
  --keystone-user keystone \
  --keystone-group keystone

# Rotate định kỳ
keystone-manage credential_rotate \
  --keystone-user keystone \
  --keystone-group keystone
```

---

## 8. Section `[auth]` – Phương thức xác thực

```ini
[auth]
methods = external,password,token,oauth1,mapped,application_credential,totp
```

| Option                   | Mô tả                                                         |
|--------------------------|---------------------------------------------------------------|
| `methods`                | Danh sách phương thức xác thực được bật (phân cách bằng dấu phẩy) |
| `password`               | Entry point cho module xác thực mật khẩu                     |
| `token`                  | Entry point cho module xác thực bằng token                   |
| `external`               | Xác thực qua Web Server (REMOTE_USER header)                  |
| `oauth1`                 | Entry point cho OAuth 1.0                                     |
| `mapped`                 | Xác thực federation (SAML, OpenID Connect)                    |
| `application_credential` | Xác thực bằng Application Credential                         |
| `totp`                   | Xác thực 2 yếu tố (Time-based One-Time Password)             |

> **Lưu ý:** Chỉ thêm phương thức vào `methods` khi thực sự dùng. Bật `totp` cần cấu hình thêm `[totp]` section.

---

## 9. Section `[cache]` – Caching toàn cục

```ini
[cache]
enabled = True
backend = dogpile.cache.memcached
backend_argument = url:127.0.0.1:11211
expiration_time = 600

[token]
caching = True
cache_time = 3600

[role]
caching = True

[resource]
caching = True
cache_time = 3600
```

| Option                 | Mặc định               | Mô tả                                               |
|------------------------|------------------------|-----------------------------------------------------|
| `enabled`              | `True`                 | Bật/tắt toàn bộ hệ thống cache                     |
| `backend`              | `dogpile.cache.memory` | Backend: `memcached`, `redis`, `memory` (chỉ dev)   |
| `backend_argument`     | –                      | Tham số kết nối đến backend (có thể lặp lại nhiều lần) |
| `expiration_time`      | `600`                  | Thời gian hết hạn cache mặc định (giây)             |
| `debug_cache_backend`  | `False`                | Log chi tiết cache hit/miss — chỉ dùng khi debug   |

**Ví dụ với Redis:**

```ini
[cache]
enabled = True
backend = dogpile.cache.redis
backend_argument = host:127.0.0.1
backend_argument = port:6379
backend_argument = db:0
```

> **Tại sao cache quan trọng?** Fernet token validation không cần DB, nhưng kiểm tra role/project assignment của token thì cần. Cache giúp tránh query DB liên tục khi có nhiều request đồng thời.

---

## 10. Section `[catalog]` – Service Catalog

```ini
[catalog]
driver = sql
caching = True
cache_time = 3600
```

| Option       | Mặc định | Mô tả                                                          |
|--------------|----------|----------------------------------------------------------------|
| `driver`     | `sql`    | `sql` (khuyến nghị) hoặc `template` (file, không cần DB)      |
| `caching`    | `True`   | Cache danh sách endpoint. Quan trọng vì catalog ít thay đổi   |
| `cache_time` | –        | Thời gian cache catalog. Mặc định dùng `[cache] expiration_time` |
| `list_limit` | –        | Giới hạn số endpoint trả về                                    |

---

## 11. Section `[identity]` – Backend Identity

```ini
[identity]
driver = sql
default_domain_id = default
```

| Option                                  | Mặc định                | Mô tả                                                     |
|-----------------------------------------|-------------------------|-----------------------------------------------------------|
| `driver`                                | `sql`                   | Backend lưu user/group: `sql` hoặc `ldap`                |
| `default_domain_id`                     | `default`               | Domain mặc định khi không chỉ định domain                 |
| `domain_specific_drivers_enabled`       | `False`                 | Bật để cho phép mỗi domain dùng backend riêng            |
| `domain_config_dir`                     | `/etc/keystone/domains` | Thư mục chứa config per-domain                            |
| `domain_configurations_from_database`   | `False`                 | Lưu domain config trong DB thay vì file                   |
| `max_password_length`                   | `4096`                  | Giới hạn độ dài password trước khi hash                   |

---

## 12. Section `[assignment]`, `[resource]`, `[application_credential]`

```ini
[assignment]
driver = sql
prohibited_implied_role = admin

[resource]
driver = sql
domain_name_url_safe = strict
project_name_url_safe = strict

[application_credential]
driver = sql
user_limit = -1
```

| Section                    | Option                     | Giá trị khuyến nghị | Mô tả                                               |
|----------------------------|----------------------------|---------------------|-----------------------------------------------------|
| `[assignment]`             | `driver`                   | `sql`               | Backend lưu role assignment                         |
| `[assignment]`             | `prohibited_implied_role`  | `admin`             | Role bị cấm làm implied role (bảo mật leo thang quyền) |
| `[resource]`               | `domain_name_url_safe`     | `strict`            | `strict` = cấm ký tự đặc biệt trong tên domain     |
| `[resource]`               | `project_name_url_safe`    | `strict`            | Tương tự cho tên project                            |
| `[resource]`               | `bootstrap_project_name`   | `admin`             | Tên project được tạo khi bootstrap                  |
| `[application_credential]` | `driver`                   | `sql`               | Backend lưu application credential                  |
| `[application_credential]` | `user_limit`               | `-1`                | Số app credential tối đa mỗi user. `-1` = không giới hạn |

---

## 13. Section `[security_compliance]` – PCI-DSS

> Các tùy chọn này chỉ áp dụng cho **SQL backend**, **không áp dụng cho LDAP**.

```ini
[security_compliance]
lockout_failure_attempts = 6
lockout_duration = 1800
password_expires_days = 90
change_password_upon_first_use = True
unique_last_password_count = 5
disable_user_account_days_inactive = 90
```

| Tùy chọn                              | Mô tả                                                          |
|---------------------------------------|----------------------------------------------------------------|
| `lockout_failure_attempts`            | Khóa tài khoản sau N lần nhập sai password                     |
| `lockout_duration`                    | Thời gian khóa (giây). `-1` = khóa vĩnh viễn đến khi admin mở |
| `disable_user_account_days_inactive`  | Tự disable user không login trong X ngày                       |
| `change_password_upon_first_use`      | Buộc đổi password lần đầu đăng nhập                           |
| `password_expires_days`               | Password hết hạn sau X ngày                                    |
| `password_regex`                      | Regex kiểm tra độ mạnh password                                |
| `password_regex_description`          | Thông báo hiển thị khi password không đạt yêu cầu              |
| `unique_last_password_count`          | Không cho dùng lại N password gần nhất                         |
| `minimum_password_age`                | Không cho đổi password trong vòng X ngày sau lần đổi trước    |

---

## 14. Tích hợp LDAP / Active Directory

Keystone hỗ trợ LDAP làm backend **chỉ đọc (read-only)** — dùng LDAP để **xác thực và lấy thông tin user/group**, nhưng **không ghi vào LDAP**.

```ini
# File: /etc/keystone/domains/keystone.DOMAIN_NAME.conf
[identity]
driver = ldap

[ldap]
url = ldap://ldap-server.example.com
user = cn=admin,dc=example,dc=com
password = secret
suffix = dc=example,dc=com
query_scope = sub
page_size = 0

# User mapping
user_tree_dn = ou=Users,dc=example,dc=com
user_objectclass = inetOrgPerson
user_id_attribute = uid
user_name_attribute = uid
user_mail_attribute = mail
user_pass_attribute = userPassword

# Group mapping
group_tree_dn = ou=Groups,dc=example,dc=com
group_objectclass = groupOfNames
group_id_attribute = cn
group_name_attribute = cn
group_member_attribute = member
```

### Bảo mật LDAP (LDAPS / StartTLS)

```ini
[ldap]
# Dùng LDAPS (port 636)
url = ldaps://ldap-server.example.com

# Hoặc StartTLS (port 389)
use_tls = True
tls_cacertfile = /etc/ssl/certs/ca-bundle.crt
tls_req_cert = demand      # demand = bắt buộc xác thực cert; never = không xác thực (chỉ dev)
```

### Tối ưu hiệu suất LDAP

```ini
[ldap]
use_pool = True
pool_size = 10
pool_max_lifetime = 600
pool_connection_timeout = 10
use_auth_pool = True
auth_pool_size = 100
auth_pool_connection_lifetime = 60
```

**Các nhóm tùy chọn quan trọng:**

| Nhóm              | Tùy chọn chính                                           |
|-------------------|---------------------------------------------------------|
| Kết nối           | `url`, `user`, `password`, `suffix`                     |
| Hiệu suất         | `use_pool`, `pool_size`, `use_auth_pool`                 |
| Bảo mật           | `use_tls`, `tls_cacertfile`, `tls_req_cert = demand`    |
| Attribute mapping | `user_id_attribute`, `user_name_attribute`, `user_mail_attribute` |

> **RHEL/CentOS với SELinux:**
> ```bash
> setsebool -P authlogin_nsswitch_use_ldap on
> ```

### Identity Mapping

Khi dùng LDAP, Keystone tạo bảng ánh xạ (mapping) để đảm bảo User/Group ID duy nhất trong toàn hệ thống.

```bash
# Xóa mapping cũ (dùng khi thay đổi cấu hình LDAP)
keystone-manage mapping_purge --domain-name DOMAIN_NAME

# Populate mapping trước để tránh timeout khi list user lần đầu
keystone-manage mapping_populate --domain DOMAIN_NAME
```

---

## 15. Domain-Specific Configuration

Cho phép mỗi **domain** dùng backend identity riêng (thường là LDAP).

### Cách 1 – File config riêng cho từng domain

```ini
# Trong keystone.conf
[identity]
domain_specific_drivers_enabled = True
domain_config_dir = /etc/keystone/domains
```

- Keystone tìm file tên `keystone.<TEN_DOMAIN>.conf` trong thư mục đó
- Domain không có file riêng sẽ dùng config từ `keystone.conf`

```
/etc/keystone/domains/
├── keystone.corp.conf      # Config cho domain "corp" (LDAP công ty)
└── keystone.external.conf  # Config cho domain "external" (LDAP đối tác)
```

### Cách 2 – Lưu config vào SQL Database (qua API)

```ini
[identity]
domain_specific_drivers_enabled = True
domain_configurations_from_database = True
```

| Ưu điểm                                  | Nhược điểm                                           |
|------------------------------------------|------------------------------------------------------|
| Không cần restart khi thay đổi           | Có cache, thay đổi có thể không áp dụng ngay lập tức |
| Quản lý qua REST API (v3/domains)        | Khó xem/audit hơn file                              |
| Phù hợp multi-node (không cần sync file) | –                                                    |

```bash
# Migrate từ file sang database
keystone-manage domain_config_upload --all

# Hoặc upload từng domain
keystone-manage domain_config_upload --domain-name DOMAIN_NAME
```

---

## 16. Performance & Scaling

Keystone scale ngang dễ dàng: thêm process và đặt load balancer phía trước.

| Kỹ thuật tối ưu                           | Cách thực hiện                                            |
|-------------------------------------------|-----------------------------------------------------------|
| Bật Memcached cache                       | `[cache] enabled = True`, `backend = dogpile.cache.memcached` |
| Dùng Fernet token                         | Không cần DB lookup khi validate, nhanh hơn nhiều         |
| Cache token validation                    | `[token] caching = True`, `cache_time` phù hợp            |
| Tối ưu DB connection pool                 | `[database] max_pool_size`, `max_overflow`                |
| Giảm `list_limit`                         | Tránh query trả về quá nhiều bản ghi                      |
| Bật LDAP pool                             | `[ldap] use_pool = True`, `use_auth_pool = True`          |
| Cấu hình keystonemiddleware               | `memcached_servers`, `include_service_catalog = False`    |

**Cấu hình keystonemiddleware (trong paste.ini của các service khác như Nova, Neutron):**

```ini
[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
token_cache_time = 300
include_service_catalog = False   # Giảm kích thước token đáng kể
```

---

## 17. So sánh Dev vs Production

| Tùy chọn                            | Development              | Production                          |
|-------------------------------------|--------------------------|-------------------------------------|
| `[DEFAULT] debug`                   | `True`                   | `False`                             |
| `[DEFAULT] insecure_debug`          | `True`                   | `False`                             |
| `[database] connection`             | SQLite                   | MySQL/PostgreSQL + connection pool  |
| `[token] provider`                  | `fernet`                 | `fernet`                            |
| `[token] expiration`                | `86400` (1 ngày)         | `3600` (1 giờ)                      |
| `[cache] backend`                   | `dogpile.cache.memory`   | `dogpile.cache.memcached`           |
| `[fernet_tokens] max_active_keys`   | `3`                      | `5` (cho phép rotate thường hơn)    |
| `[security_compliance]`             | Không cần                | Bật đầy đủ                          |
| `[DEFAULT] strict_password_check`   | `False`                  | `True`                              |
| HTTPS/TLS                           | Không bắt buộc           | **Bắt buộc**                        |

---

