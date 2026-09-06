# TLS Handshake — giải thích từng bước (theo bài của Cloudflare)

Nguồn: [What happens in a TLS handshake? — Cloudflare](https://www.cloudflare.com/learning/ssl/what-happens-in-a-tls-handshake/)

Handshake là chuỗi thông điệp client và server trao đổi để: chọn thuật toán, xác thực server, và tạo ra **session key** (khóa phiên) dùng mã hóa dữ liệu về sau. Các bước cụ thể **thay đổi tùy thuật toán trao đổi khóa**. Bài Cloudflare mô tả 3 kiểu, từ cũ đến mới:

1. RSA handshake (TLS ≤ 1.2, nay coi là **không an toàn**)
2. Ephemeral Diffie-Hellman handshake (TLS 1.2)
3. TLS 1.3 handshake

---

## A. RSA handshake (TLS 1.2 trở về trước — kiểu cũ)

Ý tưởng cốt lõi: client tự bịa ra bí mật phiên, rồi **dùng public key của server để khóa nó lại** và gửi đi. Chỉ ai có private key mới mở được → mở được tức là server thật.

### Bước 1 — Client Hello

Client mở màn: *"Chào, tôi muốn kết nối TLS."* Kèm theo 3 thứ:

- **Phiên bản TLS** client hỗ trợ (1.0/1.1/1.2...)
- **Danh sách cipher suite** — các "combo" thuật toán mã hóa mà client biết dùng
- **Client random** — một chuỗi byte ngẫu nhiên

> Vì sao cần random? Để mỗi phiên mỗi khác. Không có nó, hai phiên giống hệt nhau sẽ tạo ra khóa giống nhau → kẻ gian phát lại (replay) dữ liệu cũ được.

### Bước 2 — Server Hello

Server đáp lại, gửi 3 thứ:

- **SSL certificate** của server (chứa public key + danh tính, do CA ký)
- **Cipher suite server đã chọn** từ danh sách client đưa
- **Server random** — chuỗi ngẫu nhiên do server sinh

### Bước 3 — Authentication (xác thực certificate)

Client kiểm tra certificate với CA đã cấp nó: chữ ký CA có hợp lệ không, còn hạn không, đúng tên miền không.

> Bước này trả lời: *"certificate này có phải đồ thật, do nơi uy tín cấp không?"* — nhưng **chưa** chứng minh người gửi là chủ nhân của nó. Việc đó nằm ở bước 4–5.

### Bước 4 — Premaster secret

Client sinh thêm một chuỗi ngẫu nhiên nữa: **premaster secret**. Nó **mã hóa chuỗi này bằng public key lấy từ certificate** rồi gửi cho server.

> Giống bỏ thư vào hòm khóa sẵn: ai cũng bỏ vào được (public key công khai), nhưng chỉ người giữ chìa (private key) mở ra đọc được.

### Bước 5 — Server dùng private key

Server giải mã premaster secret bằng private key.

> Đây chính là lúc server "vô tình" chứng minh danh tính: giải mã được = có private key = đúng là chủ certificate. Xác thực kiểu **ngầm**, không có chữ ký tường minh.

### Bước 6 — Tạo session key

Cả hai bên cùng nấu **session key** từ 3 nguyên liệu: client random + server random + premaster secret. Công thức giống nhau → ra kết quả giống nhau, dù không bên nào gửi thẳng khóa cho bên kia.

### Bước 7 — Client ready

Client gửi thông điệp **Finished**, đã mã hóa bằng session key → "phía tôi xong, khóa dùng được".

### Bước 8 — Server ready

Server gửi **Finished** của nó, cũng mã hóa bằng session key.

### Bước 9 — Mã hóa đối xứng bắt đầu

Handshake kết thúc. Từ giờ mọi dữ liệu đi bằng mã hóa đối xứng với session key (nhanh hơn nhiều so với mã hóa bất đối xứng).

⚠️ **Điểm chết của RSA handshake:** premaster secret nằm gọn trong gói tin, chỉ được bảo vệ bằng private key của server. Kẻ gian cứ **ghi âm toàn bộ traffic hôm nay**, vài năm sau trộm được private key → giải mã sạch mọi thứ đã ghi. Không có **forward secrecy**. Đây là lý do TLS 1.3 khai tử nó.

---

## B. Ephemeral Diffie-Hellman handshake (TLS 1.2 — kiểu tốt hơn)

Khác biệt cốt lõi: **không ai gửi bí mật đi cả**. Hai bên trao đổi "nguyên liệu" DH công khai, rồi mỗi bên **tự tính ra** cùng một bí mật. Private key của server đổi vai: không dùng để giải mã nữa, mà dùng để **ký**.

### Bước 1 — Client Hello (như kiểu RSA)

Phiên bản TLS + danh sách cipher suite + **client random**.

### Bước 2 — Server Hello (kèm tham số DH)

Server gửi certificate, cipher suite đã chọn, **server random** — và kèm thêm thứ RSA handshake không có: **tham số DH của server** (bước 3 dưới đây đi cùng gói này).

### Bước 3 — Chữ ký số của server

Server **ký** (bằng private key) lên hash của các thông điệp trao đổi tới thời điểm này (bao gồm cả tham số DH).

> Vì DH không dùng private key để giải mã gì, server phải chứng minh danh tính theo cách **tường minh**: ký tươi. Chữ ký cũng "đóng đinh" tham số DH vào certificate — kẻ gian không thể tráo tham số DH của hắn vào.

### Bước 4 — Client xác minh chữ ký

Client dùng public key trong certificate kiểm tra chữ ký (và kiểm tra certificate với CA như thường lệ). Khớp → server đúng là chính chủ.

### Bước 5 — Client gửi tham số DH

Client gửi phần tham số DH của mình cho server. Tham số này đi **công khai** — DH được thiết kế để lộ tham số cũng không sao.

### Bước 6 — Hai bên tự tính premaster secret

Đây là phép màu của Diffie-Hellman: mỗi bên lấy tham số công khai của đối phương + bí mật riêng của mình, tính ra **cùng một premaster secret** — mà không hề gửi nó qua mạng.

> Kẻ nghe lén thấy cả hai tham số công khai nhưng không tính ngược ra bí mật được (bài toán logarit rời rạc). "Ephemeral" = tham số **dùng một lần rồi vứt**, mỗi phiên bộ mới → lộ private key của server cũng không giải mã được các phiên cũ = **forward secrecy**.

### Bước 7 — Tạo session key

Y như RSA handshake: session key = f(client random, server random, premaster secret).

### Bước 8 — Client ready → Bước 9 — Server ready → Bước 10 — Mã hóa đối xứng

Ba bước cuối giống hệt RSA handshake: hai bên trao Finished mã hóa bằng session key, rồi dữ liệu chạy.

---

## C. TLS 1.3 handshake — gọn hơn và nhanh hơn

TLS 1.3 chỉ giữ lại kiểu DH ephemeral (RSA handshake bị loại hẳn) và **gộp các bước lại còn 1 vòng khứ hồi (1-RTT)** thay vì 2:

### Bước 1 — Client Hello (kèm luôn tham số DH)

Client gửi hello như cũ **nhưng đính kèm luôn key_share (tham số DH) của mình**, khỏi chờ hỏi. Đây là mẹo giúp tiết kiệm nguyên một vòng khứ hồi.

### Bước 2 — Server trả lời tất cả trong một lượt

Server sinh premaster secret ngay (vì đã có tham số DH của client + của nó), rồi gửi **một mạch**: ServerHello + key_share, certificate, chữ ký (CertificateVerify), và Finished.

> Từ sau ServerHello, hai bên đã có bí mật chung → certificate và chữ ký được gửi **dưới dạng mã hóa** — TLS 1.2 gửi trần.

### Bước 3 — Client kết thúc

Client xác minh certificate + chữ ký, gửi Finished của mình → xong. Dữ liệu chạy.

### Bonus — 0-RTT khi kết nối lại

Nếu hai bên từng nói chuyện, họ còn giữ bí mật chung cũ (**PSK**), client có thể gửi dữ liệu **ngay trong gói đầu tiên** — không cần vòng bắt tay nào. Đổi lại chấp nhận rủi ro replay nhất định.

---

## So sánh nhanh 3 kiểu

| | RSA (≤1.2) | DH ephemeral (1.2) | TLS 1.3 |
| --- | --- | --- | --- |
| Ai tạo premaster secret? | Client tạo, gửi đi (mã hóa bằng public key) | Hai bên tự tính, không gửi | Hai bên tự tính, không gửi |
| Private key server dùng để | Giải mã premaster secret | Ký chữ ký số | Ký chữ ký số (CertificateVerify) |
| Xác thực server | Ngầm (giải mã được là thật) | Tường minh (chữ ký) | Tường minh (chữ ký) |
| Forward secrecy | ❌ Không | ✅ Có | ✅ Luôn luôn |
| Số vòng khứ hồi | 2-RTT | 2-RTT | **1-RTT** (0-RTT khi resume) |
| Certificate trên đường truyền | Bản rõ | Bản rõ | **Đã mã hóa** |

**Mạch tiến hóa để nhớ:** RSA handshake dùng private key sai việc (giải mã) → mất forward secrecy → DH ephemeral sửa bằng cách chuyển private key sang việc ký → TLS 1.3 giữ nguyên ý tưởng đó, cắt kiểu cũ, dồn bước để nhanh hơn và giấu luôn certificate.
