# Báo cáo khảo sát ứng dụng Stan's Robot Shop

Oct 30, 2026 · @MAI VINH

## 1. Thông tin chung

Báo cáo này khảo sát ứng dụng Stan's Robot Shop ở trạng thái nguyên bản, trước khi thực hiện bất kỳ thay đổi hay triển khai nào. Mục đích là nắm rõ kiến trúc, luồng dữ liệu, cách đóng gói và các rủi ro của mã nguồn gốc.

| Mục | Thông tin |
| --- | --- |
| Ứng dụng | Stan's Robot Shop, do Instana (nay thuộc IBM) phát triển |
| Repo gốc | [instana/robot-shop](https://github.com/instana/robot-shop) |
| Repo khảo sát | [DucThinhIsMeX/robot-shop](https://github.com/DucThinhIsMeX/robot-shop), fork từ repo gốc |
| Commit tham chiếu | `55292e2199f2fb00a165b1f7d3045fe7f8922038`, ngày 6-3-2023 (commit cuối của repo gốc) |
| Giấy phép | Apache-2.0 |
| Trạng thái repo gốc | Không còn cập nhật kể từ tháng 3-2023 |

Phương pháp khảo sát: đọc trực tiếp mã nguồn từng service, Dockerfile, file Docker Compose và Helm chart trong repo. Mọi nhận định trong báo cáo đều kèm vị trí file để đối chiếu. Bản fork đã được so sánh với repo gốc và không có khác biệt nào.

## 2. Tổng quan nghiệp vụ

Robot Shop mô phỏng một cửa hàng trực tuyến bán robot và trí tuệ nhân tạo theo phong cách khoa học viễn tưởng. Ứng dụng được thiết kế làm môi trường thử nghiệm cho điều phối container và giám sát, không phải cửa hàng kinh doanh thật.

Người dùng thực hiện được các chức năng sau:

1. Xem danh mục, lọc theo loại, tìm kiếm và xem chi tiết sản phẩm.
2. Xem và gửi đánh giá sản phẩm.
3. Thêm, sửa số lượng sản phẩm trong giỏ hàng; khách chưa đăng nhập được cấp mã định danh tạm `anonymous-<số>`.
4. Chọn quốc gia, thành phố nhận hàng và xem cước vận chuyển.
5. Thanh toán (mô phỏng, không trừ tiền thật).
6. Đăng ký, đăng nhập và xem lịch sử đơn hàng.

Dữ liệu mẫu được nạp sẵn từ [`mongo/catalogue.js`](https://github.com/DucThinhIsMeX/robot-shop/blob/master/mongo/catalogue.js) gồm 11 sản phẩm: 8 thuộc loại Robot, 2 thuộc loại Artificial Intelligence, 1 thuộc cả hai.

| SKU | Tên sản phẩm | Giá (USD) | Tồn kho |
| --- | --- | --- | --- |
| UHJ | Ultimate Harvesting Juggernaut | 5.000 | 10 |
| Watson | Watson | 2.001 | 2 |
| HPTD | High-Powered Travel Droid | 1.200 | 12 |
| EMM | Exceptional Medical Machine | 1.024 | 1 |
| CNA | Cybernated Neutralization Android | 1.000 | 0 |
| EPE | Extreme Probe Emulator | 953 | 1 |
| RED | Responsive Enforcer Droid | 700 | 5 |
| SHCE | Strategic Human Control Emulator | 300 | 12 |
| Ewooid | Ewooid | 200 | 0 |
| STAN-1 | Stan | 67 | 1.000 |
| RMC | Robotic Mining Cyborg | 42 | 48 |

Ngoài ra [`mongo/users.js`](https://github.com/DucThinhIsMeX/robot-shop/blob/master/mongo/users.js) tạo sẵn 3 tài khoản mẫu (`user`, `stan`, `partner-57`), và MySQL nạp sẵn dữ liệu địa lý các thành phố trên thế giới để tính cước.

## 3. Kiến trúc tổng thể

Trình duyệt chỉ nói chuyện với `web`. Service này vừa phục vụ giao diện AngularJS vừa đóng vai gateway, chuyển `/api/<service>/*` tới 6 service HTTP phía sau. Chỉ có `dispatch` không nhận request, nó lấy việc từ RabbitMQ.

&#91;embedded content: kiến trúc Robot Shop · 8 service, 4 kho dữ liệu\]

Sơ đồ chỉ vẽ quan hệ với kho dữ liệu. Các service còn gọi trực tiếp lẫn nhau qua HTTP: `cart` và `ratings` gọi `catalogue`, `shipping` gọi `cart`, `payment` gọi `user` và `cart`.

| Đường dẫn trên `web` | Chuyển tới |
| --- | --- |
| `/` | Giao diện tĩnh của `web` |
| `/api/catalogue/` | `catalogue:8080` |
| `/api/user/` | `user:8080` |
| `/api/cart/` | `cart:8080` |
| `/api/shipping/` | `shipping:8080` |
| `/api/payment/` | `payment:8080` |
| `/api/ratings/` | `ratings:80` |
| `/nginx_status` | Trang trạng thái của Nginx |

## 4. Danh mục service

Ứng dụng gồm 8 service nghiệp vụ viết bằng 5 ngôn ngữ, cộng 1 công cụ sinh tải. Các service gọi nhau qua HTTP; riêng `payment` và `dispatch` trao đổi qua RabbitMQ.

| Service | Ngôn ngữ, framework | Cổng | Gọi tới | Chức năng |
| --- | --- | --- | --- | --- |
| `web` | Nginx, AngularJS 1.6.7 | 8080 | 6 service HTTP còn lại | Phục vụ giao diện và chuyển tiếp `/api/*` |
| `catalogue` | Node.js, Express | 8080 | MongoDB | Danh mục, loại, tìm kiếm, chi tiết sản phẩm |
| `cart` | Node.js, Express | 8080 | Redis, `catalogue` | Giỏ hàng; lấy giá từ `catalogue` khi thêm sản phẩm |
| `user` | Node.js, Express | 8080 | MongoDB, Redis | Đăng ký, đăng nhập, lịch sử đơn, mã khách vãng lai |
| `shipping` | Java, Spring Boot | 8080 | MySQL, `cart` | Tra cứu thành phố, tính cước, gắn cước vào giỏ |
| `ratings` | PHP 7.4, Apache | 80 | MySQL, `catalogue` | Lưu và trả điểm đánh giá sản phẩm |
| `payment` | Python, Flask | 8080 | `user`, `cart`, RabbitMQ, cổng thanh toán ngoài | Xử lý thanh toán mô phỏng, đẩy đơn vào hàng đợi |
| `dispatch` | Go | Không mở cổng | RabbitMQ | Worker nhận đơn từ hàng đợi, mô phỏng xử lý giao hàng |

`load-gen` (Python, Locust) không phải service nghiệp vụ. Nó giả lập người dùng xem hàng, thêm giỏ, tính cước và thanh toán, chạy bằng file `docker-compose-load.yaml` hoặc `K8s/load-deployment.yaml`.

Ngoài 8 service, Docker Compose còn build 2 image dữ liệu riêng: `rs-mongodb` (nạp sẵn sản phẩm và tài khoản mẫu) và `rs-mysql-db` (nạp sẵn dữ liệu thành phố và bảng đánh giá).

## 5. Dữ liệu và hàng đợi

Mỗi loại dữ liệu nằm ở một kho phù hợp với tính chất của nó: tài liệu linh hoạt ở MongoDB, dữ liệu quan hệ ở MySQL, dữ liệu tạm ở Redis, thông điệp ở RabbitMQ.

| Kho | Service sử dụng | Dữ liệu | Vị trí trong mã nguồn |
| --- | --- | --- | --- |
| MongoDB | `catalogue`, `user` | Database `catalogue` (collection `products`); database `users` (collection `users`, `orders`) | `mongo/catalogue.js`, `mongo/users.js` |
| MySQL | `shipping`, `ratings` | Database `cities` (quốc gia, thành phố, tọa độ); database `ratings` (điểm đánh giá theo SKU) | `mysql/scripts/10-dump.sql.gz`, `mysql/scripts/20-ratings.sql` |
| Redis | `cart`, `user` | Giỏ hàng theo cart id; bộ đếm `anonymous-counter` | `cart/server.js`, `user/server.js` |
| RabbitMQ | `payment`, `dispatch` | Thông điệp đơn hàng đã thanh toán | `payment/rabbitmq.py`, `dispatch/main.go` |

Ba chi tiết cần lưu ý khi vận hành:

- **Giỏ hàng tự hết hạn.** `cart` lưu giỏ bằng `setex(id, 3600, ...)`: khóa chính là cart id, thời gian sống 3.600 giây và được đặt lại mỗi lần giỏ thay đổi. Giỏ không hoạt động 1 giờ sẽ mất.
- **Redis của `user` không giữ phiên đăng nhập.** Nó chỉ tăng bộ đếm `anonymous-counter` để cấp mã `anonymous-<số>` cho khách chưa đăng nhập. Ứng dụng không dùng JWT hay session phía máy chủ.
- **Tên hàng đợi là `orders`.** `payment` publish vào exchange kiểu `direct` tên `robot-shop` với routing key `orders`. `dispatch` khai báo queue bền vững tên `orders`, bind vào exchange đó cùng routing key rồi consume. Không có queue nào khác.

## 6. Luồng nghiệp vụ chính

Luồng đặt hàng chạm tới 6 thành phần. Phần tính cước và thanh toán chạy đồng bộ, người dùng nhận `orderid` ngay; phần xử lý đơn chạy bất đồng bộ qua RabbitMQ.

&#91;embedded content: luồng tính cước và thanh toán · 12 bước\]

### Tính cước vận chuyển

`shipping` tính khoảng cách từ kho hàng cố định tại Solingen, Đức (vĩ độ 51,164896, kinh độ 7,068792) tới tọa độ thành phố nhận hàng lấy từ MySQL, theo công thức Haversine (`Calculator.java`). Cước chỉ phụ thuộc khoảng cách, không phụ thuộc khối lượng hay số lượng hàng (`Controller.java`):

```latex
\text{cước (USD)} = \frac{\operatorname{round}(\text{khoảng cách (km)} \times 5)}{100}
```

Khi người dùng xác nhận, `shipping` gọi `cart` để thêm cước vào giỏ như một dòng hàng riêng.

### Thanh toán

`payment` xử lý theo thứ tự trong `payment.py`:

1. Nhận giỏ hàng do trình duyệt gửi lên; từ chối nếu tổng tiền bằng 0 hoặc giỏ chưa có cước.
2. Gọi `user` kiểm tra người dùng có tài khoản hay không; không có thì coi là khách vãng lai, vẫn cho thanh toán.
3. Gửi request tới cổng thanh toán ngoài (mặc định `https://paypal.com/`), chỉ kiểm tra kết nối, không trừ tiền.
4. Tạo `orderid` dạng UUID, publish đơn vào exchange `robot-shop` với routing key `orders`.
5. Nếu bước 2 xác nhận có tài khoản, gọi `user` lưu đơn vào lịch sử.
6. Gọi `cart` xóa giỏ, trả `orderid` cho trình duyệt.

### Xử lý đơn

`dispatch` nhận thông điệp từ queue `orders` và chỉ mô phỏng: chờ ngẫu nhiên 42-84 mili giây cho mỗi bước, ghi trace span, và đánh dấu lỗi theo tỷ lệ `DISPATCH_ERROR_PERCENT`. Không có dữ liệu nào được ghi lại.

## 7. Cấu hình và đóng gói có sẵn

Repo có sẵn Dockerfile cho mọi thành phần, một file Docker Compose chạy đủ bộ và một Helm chart. Các service chỉ đọc từ biến môi trường địa chỉ của service khác và vài tham số vận hành; thông tin đăng nhập cơ sở dữ liệu phần lớn ghi cứng trong mã (xem mục 8).

### Biến môi trường đọc được

| Service | Biến môi trường |
| --- | --- |
| `web` | `CATALOGUE_HOST`, `USER_HOST`, `CART_HOST`, `SHIPPING_HOST`, `PAYMENT_HOST`, `RATINGS_HOST`, `INSTANA_EUM_KEY`, `INSTANA_EUM_REPORTING_URL` |
| `catalogue` | `MONGO_URL`, `CATALOGUE_SERVER_PORT`, `GO_SLOW` |
| `user` | `MONGO_URL`, `REDIS_HOST`, `USER_SERVER_PORT` |
| `cart` | `REDIS_HOST`, `CATALOGUE_HOST`, `CART_SERVER_PORT` |
| `shipping` | `DB_HOST`, `CART_ENDPOINT` |
| `ratings` | `PDO_URL`, `CATALOGUE_URL`, `APP_ENV` |
| `payment` | `CART_HOST`, `USER_HOST`, `AMQP_HOST`, `PAYMENT_GATEWAY`, `PAYMENT_DELAY_MS` |
| `dispatch` | `AMQP_HOST`, `DISPATCH_ERROR_PERCENT` |

### Docker Compose

File `docker-compose.yaml` dựng 12 container: 4 kho dữ liệu và 8 service. Image mặc định là `robotshop/rs-<tên>:2.1.0` trên Docker Hub, lấy từ file `.env`. Chỉ cổng 8080 của `web` được mở ra máy chủ. File `docker-compose-load.yaml` bật thêm `load-gen`.

### Helm chart

Chart nằm ở `K8s/helm`, gồm Deployment và Service cho từng thành phần, riêng Redis là StatefulSet. `values.yaml` cho phép đổi registry, tag image, StorageClass của Redis, cổng thanh toán và bật chế độ NodePort hoặc OpenShift. Repo còn có cấu hình cho OpenShift, DC/OS và Istio, không thuộc phạm vi khảo sát này.

### Công tắc gây sự cố có sẵn

Ứng dụng có 3 biến môi trường để chủ động tạo sự cố, phục vụ thử nghiệm giám sát và khả năng chịu lỗi:

| Biến | Service | Tác dụng |
| --- | --- | --- |
| `GO_SLOW` | `catalogue` | Thêm độ trễ (mili giây) trước khi trả chi tiết sản phẩm `GET /product/:sku` |
| `PAYMENT_DELAY_MS` | `payment` | Thêm độ trễ (mili giây) trước khi đẩy đơn vào RabbitMQ |
| `DISPATCH_ERROR_PERCENT` | `dispatch` | Tỷ lệ phần trăm đơn bị đánh dấu lỗi "Failed to dispatch to SOP" |

## 8. Hiện trạng và rủi ro của mã nguồn gốc

Khảo sát phát hiện 18 vấn đề, trong đó 7 vấn đề mức Cao. Nghiêm trọng nhất là API `/api/user/users` trả về toàn bộ người dùng kèm mật khẩu dạng văn bản thô cho bất kỳ ai truy cập. Vị trí ghi theo đường dẫn trong repo và số dòng.

| Nhóm | Vấn đề | Vị trí | Mức độ |
| --- | --- | --- | --- |
| Bảo mật ứng dụng | `GET /users` trả toàn bộ người dùng kèm mật khẩu, truy cập công khai qua gateway tại `/api/user/users` | `user/server.js` dòng 104; `web/default.conf.template` dòng 64-65 | Cao |
| Bảo mật ứng dụng | Mật khẩu người dùng lưu dạng văn bản thô, so sánh trực tiếp `user.password == req.body.password`; tài khoản mẫu có mật khẩu công khai | `user/server.js` dòng 129; `mongo/users.js` | Cao |
| Bảo mật ứng dụng | Đăng nhập và đăng ký ghi nguyên nội dung request, gồm cả mật khẩu, ra log | `user/server.js` dòng 119 và 149 | Cao |
| Bảo mật ứng dụng | Lịch sử đơn hàng xem được chỉ bằng tên người dùng, không cần xác thực | `user/server.js` dòng 237 | Trung bình |
| Bảo mật ứng dụng | `payment` nhận giỏ hàng và tổng tiền từ trình duyệt gửi lên, không đối chiếu lại với `cart` | `payment/payment.py` dòng 57 | Trung bình |
| Bảo mật ứng dụng | Thêm và sửa giỏ hàng bằng phương thức GET | `cart/server.js` dòng 139 và 213 | Thấp |
| Bảo mật ứng dụng | Trang trạng thái `/nginx_status` mở công khai | `web/default.conf.template` dòng 84 | Thấp |
| Thông tin xác thực | MongoDB không bật xác thực, chuỗi kết nối không có tài khoản | `catalogue/server.js` dòng 157; `user/server.js` dòng 272 | Cao |
| Thông tin xác thực | RabbitMQ dùng `guest/guest` ghi cứng ở cả hai phía, không đọc từ biến môi trường | `payment/rabbitmq.py` dòng 17; `dispatch/main.go` dòng 183 | Cao |
| Thông tin xác thực | MySQL cho phép root không mật khẩu; tài khoản `shipping/secret` ghi cứng trong Dockerfile và mã Java; tài khoản `ratings/iloveit` ghi cứng trong mã PHP | `mysql/Dockerfile` dòng 5-8; `shipping/.../JpaConfig.java` dòng 24-25; `ratings/html/src/Kernel.php` dòng 78-79 | Cao |
| Thông tin xác thực | Framework secret của `ratings` ghi cứng là `S0ME_SECRET` | `ratings/html/src/Kernel.php` dòng 62 | Trung bình |
| Phụ thuộc bên ngoài | Mỗi giao dịch, `payment` gửi HTTP GET tới `https://paypal.com/`; mất kết nối Internet thì thanh toán lỗi | `payment/payment.py` dòng 26 và 84 | Trung bình |
| Phụ thuộc bên ngoài | Giao diện tải AngularJS 1.6.7 từ CDN của Google; AngularJS hết hỗ trợ ngày 31-12-2021 | `web/static/index.html` dòng 66-67 | Trung bình |
| Đóng gói | MongoDB, MySQL, RabbitMQ chạy dạng Deployment không có volume; pod khởi động lại là mất dữ liệu phát sinh | `K8s/helm/templates/*-deployment.yaml` | Cao |
| Đóng gói | Redis dùng image `redis:4.0.6`; PVC dùng StorageClass `standard`, chỉ có sẵn trên một số môi trường như minikube | `K8s/helm/templates/redis-statefulset.yaml` dòng 23 và 56 | Trung bình |
| Đóng gói | Tag image mặc định là `latest` | `K8s/helm/values.yaml` dòng 5 | Trung bình |
| Đóng gói | Chỉ `ratings` và `shipping` có health probe; 6 service còn lại không có | `K8s/helm/templates/*-deployment.yaml` | Trung bình |
| Đóng gói | Không có HorizontalPodAutoscaler, chỉ có script `autoscale.sh` (tối đa 2 replica); còn template PodSecurityPolicy, API đã bị gỡ từ Kubernetes 1.25 | `K8s/autoscale.sh`; `K8s/helm/templates/podsecuritypolicy.yaml` | Thấp |

### Base image đã hết hỗ trợ

| Thành phần | Base image | Thời điểm hết hỗ trợ |
| --- | --- | --- |
| `cart`, `catalogue`, `user` | `node:14` | 4-2023 |
| `dispatch` | `golang:1.17` | 8-2022 |
| `ratings` | `php:7.4-apache` | 11-2022 |
| `shipping` | `debian:10` (build), `openjdk:8-jdk` (chạy) | Debian 10: 6-2024; image `openjdk` đã ngừng cập nhật |
| `payment`, `load-gen` | `python:3.9` | 10-2025 |
| `mysql` | `mysql:5.7` | 10-2023 |
| `mongo` | `mongo:5` | 10-2024 |
| `web` | `alpine` (build), `nginx:1.21.6` (chạy) | Bản nginx phát hành đầu 2022, đã lỗi thời |

Image RabbitMQ cũng đã hết hỗ trợ và không thống nhất giữa hai cách triển khai: Docker Compose dùng `rabbitmq:3.8-management-alpine`, Helm chart dùng `rabbitmq:3.7-management-alpine`. Redis cũng vậy: Compose dùng `redis:6.2-alpine`, Helm chart dùng `redis:4.0.6`.

## 9. Đặc điểm vận hành

Bảy service HTTP không giữ trạng thái, có thể chạy nhiều bản song song. Toàn bộ trạng thái dồn về bốn kho dữ liệu, và mỗi kho chỉ chạy một bản.

| Nhóm | Thành phần | Đặc điểm |
| --- | --- | --- |
| HTTP không trạng thái | `web`, `catalogue`, `cart`, `user`, `shipping`, `ratings`, `payment` | Trạng thái nằm ở kho dữ liệu, nhân bản được; tải tỷ lệ với lượng request |
| Worker theo hàng đợi | `dispatch` | Không nhận request; khối lượng việc tỷ lệ với số thông điệp chờ trong queue `orders` |
| Kho dữ liệu | MongoDB, MySQL, Redis, RabbitMQ | Mỗi kho một bản, không replica; là điểm lỗi đơn của các service phụ thuộc |

Ảnh hưởng khi một kho dữ liệu ngừng: MongoDB ngừng thì mất danh mục, đăng nhập và lịch sử đơn. Redis ngừng thì mất giỏ hàng. MySQL ngừng thì không tính được cước, không xem được đánh giá. RabbitMQ ngừng thì thanh toán không đẩy được đơn sang `dispatch`.

### Khả năng quan sát có sẵn

- **Kiểm tra sức khỏe**: `catalogue`, `user`, `cart`, `shipping`, `payment` có endpoint `/health`.
- **Metric Prometheus**: `cart` có `/metrics` với bộ đếm sản phẩm được thêm vào giỏ. `payment` có `/metrics` với `sold_count` (số sản phẩm đã bán), `units_sold` và `cart_value` (phân bố số lượng và giá trị đơn). Các service khác không xuất metric nghiệp vụ.
- **Tracing**: mã nguồn tích hợp thư viện của Instana (`@instana/collector` cho Node.js, sensor cho Go, Python và module tracer cho Nginx). Các sensor này gửi dữ liệu tới Instana Agent, phần mềm thương mại. Không có agent thì không có trace nào được thu thập.
- **Log**: các service ghi log ra stdout của container. Lưu ý `user` ghi cả mật khẩu vào log khi đăng nhập và đăng ký (mục 8).

## 10. Kết luận

Robot Shop là một hệ thống microservice đầy đủ các thành phần điển hình: 8 service trên 5 ngôn ngữ, 3 loại cơ sở dữ liệu, một hàng đợi thông điệp và một gateway. Ứng dụng chạy được ngay bằng Docker Compose và có sẵn công tắc gây sự cố để thử nghiệm giám sát.

Mã nguồn gốc chưa sẵn sàng cho môi trường vận hành thật. Ba nhóm vấn đề lớn nhất là: dữ liệu người dùng bị lộ qua API công khai và qua log; thông tin đăng nhập cơ sở dữ liệu ghi cứng trong mã của 4 service (`shipping`, `ratings`, `payment`, `dispatch`), nên không đổi được nếu không sửa mã; và Helm chart không giữ dữ liệu của 3 trong 4 kho khi pod khởi động lại. Toàn bộ base image đều đã hết hỗ trợ.

Các vấn đề trên đều có vị trí cụ thể trong mã nguồn và được liệt kê đầy đủ tại mục 8.
