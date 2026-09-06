# Chứng chỉ trong TLS 1.3 — giải thích đơn giản (RFC 8446)

Bản này viết lại bằng ngôn ngữ đời thường, dùng ví dụ so sánh. Thuật ngữ tiếng Anh vẫn giữ nguyên (vì đọc RFC hay code sẽ gặp đúng chữ đó), nhưng mỗi từ đều được giải thích ngay bên cạnh.

---

## 1. Certificate để làm gì?

Khi bạn kết nối tới một server, TLS phải giải quyết **2 chuyện khác nhau**:

**Chuyện 1 — tạo kênh bí mật.** Hai bên trao đổi khóa (Diffie-Hellman) để có chung một mật mã, từ đó mã hóa mọi dữ liệu. Xong bước này thì không ai nghe lén được nữa.

**Chuyện 2 — biết mình đang nói chuyện với ai.** Đây mới là vấn đề. Kênh bí mật thì có rồi, nhưng bí mật... với ai? Nếu kẻ gian chặn giữa đường và tự trao đổi khóa với bạn, bạn vẫn có "kênh bí mật" — nhưng là bí mật giữa bạn và **kẻ gian**.

👉 **Certificate sinh ra để giải quyết chuyện 2.** Nó không mã hóa gì cả. Nó chỉ là **giấy tờ tùy thân của server**.

Hãy hình dung: certificate giống như **CCCD của server**, do một cơ quan uy tín (CA — Certificate Authority) cấp. Máy bạn có sẵn danh sách các "cơ quan" đáng tin. Server chìa CCCD ra, bạn kiểm tra con dấu của cơ quan cấp → biết server đúng là example.com.

Trình tự bắt tay (handshake) như sau:

```text
Client                                     Server
ClientHello  ------------------------->
             <-------------------------    ServerHello
             (tu day tro di, moi thu da duoc ma hoa)
             <-------------------------    Certificate        "CCCD cua toi day"
             <-------------------------    CertificateVerify  "chu ky song de chung minh"
             <-------------------------    Finished           "chot so, khong ai sua gi"
Finished     ------------------------->
[Du lieu that su bat dau chay 2 chieu]
```

Điểm hay so với TLS 1.2: ở bản cũ, certificate gửi **trần trụi** trên mạng, ai rình cũng biết bạn đang nói chuyện với server nào. TLS 1.3 mã hóa nó luôn.

Lưu ý nhỏ: nếu kết nối lại phiên cũ bằng **PSK** (hai bên còn giữ bí mật từ lần trước), thì **khỏi cần certificate** — quen mặt nhau rồi thì khỏi trình CCCD.

## 2. Vì sao cần tới 3 thông điệp để xác thực?

Server phải gửi liên tiếp 3 thứ: **Certificate → CertificateVerify → Finished**. Mỗi thứ vá một lỗ hổng của thứ trước. Đọc theo mạch này sẽ thấy tự nhiên:

### Bước 1: Certificate — "CCCD của tôi đây"

Server gửi certificate của nó, kèm chuỗi chứng nhận dẫn về CA gốc mà máy bạn tin sẵn.

**Nhưng khoan** — certificate là thứ **công khai**. Ai cũng tải được certificate của example.com về. Kẻ gian hoàn toàn có thể lấy CCCD của người khác chìa ra. Vậy riêng bước này **chưa chứng minh được gì**.

### Bước 2: CertificateVerify — "và đây là chữ ký sống"

Certificate chứa một **khóa công khai** (public key). Đi kèm với nó là một **khóa riêng** (private key) mà chỉ chủ thật sự mới có — giống như CCCD ai cũng xem được, nhưng chữ ký tươi thì chỉ chính chủ ký ra được.

Server lấy **toàn bộ nội dung cuộc bắt tay từ đầu đến giờ**, băm (hash) lại, rồi **ký lên bằng private key**. Bạn dùng public key trong certificate để kiểm tra chữ ký.

- Chữ ký khớp → server **thật sự nắm private key** → nó đúng là chủ nhân của certificate. Kẻ trộm CCCD bị loại ở đây.
- Vì chữ ký ký lên **chính cuộc bắt tay này** (mỗi lần bắt tay nội dung mỗi khác, do có số ngẫu nhiên), kẻ gian không thể **ghi âm chữ ký cũ đem xài lại** — sang cuộc mới là chữ ký cũ hết khớp.

### Bước 3: Finished — "chốt sổ"

Cuối cùng, mỗi bên gửi một **mã kiểm tra (HMAC) tính trên toàn bộ cuộc bắt tay**, dùng chính khóa bí mật vừa tạo. Giống như hai bên cùng đọc lại biên bản cuộc họp rồi ký xác nhận "đúng là nãy giờ mình nói những câu này".

Nếu kẻ gian đã lén sửa bất kỳ thông điệp nào giữa đường (ví dụ tráo danh sách thuật toán để ép hai bên dùng loại yếu), biên bản hai bên sẽ lệch nhau → mã kiểm tra không khớp → hủy kết nối.

**Tóm lại một câu:**

| Thông điệp | Trả lời câu hỏi |
| --- | --- |
| Certificate | "Anh là ai?" |
| CertificateVerify | "Lấy gì chứng minh?" |
| Finished | "Nãy giờ có ai xen vào sửa gì không?" |

## 3. Mutual TLS — khi server cũng muốn kiểm tra ngược lại client

Bình thường (lướt web) chỉ server phải trình giấy tờ, còn bạn thì ẩn danh. Nhưng trong IoT, API nội bộ, hệ thống doanh nghiệp... server cũng cần biết **client là ai**. Khi đó:

1. Server gửi thêm thông điệp **CertificateRequest**: "cho xem giấy tờ của anh, tôi chấp nhận loại chữ ký này, do các CA này cấp".
2. Client đáp lại bằng đúng bộ ba của mình: Certificate + CertificateVerify + Finished. Luật y hệt.

Hai điểm đáng nhớ:

- Client **không có** certificate phù hợp? Không sao, nó gửi Certificate **rỗng**. Quyền quyết định thuộc về server: cho qua (coi như khách vãng lai) hoặc cắt kết nối (alert `certificate_required`).
- **Server phải trình giấy trước, client trình sau.** Nhờ vậy client không bao giờ lộ danh tính cho một server chưa được kiểm chứng. (TLS 1.2 làm ngược đời: certificate của client đi trần trên mạng.)

## 4. Hai bên thống nhất thuật toán chữ ký thế nào?

Ngay trong ClientHello, client gửi danh sách `signature_algorithms` — "tôi kiểm tra được các loại chữ ký này". Server bắt buộc phải chiều theo: chọn certificate và ký CertificateVerify bằng một loại trong danh sách đó.

Trên thực tế chỉ còn 3 họ thuật toán:

- **ECDSA** (đường cong P-256, P-384, P-521) — phổ biến nhất hiện nay.
- **RSA-PSS** — nếu xài RSA thì chữ ký trong handshake **bắt buộc** kiểu PSS. Kiểu cũ (PKCS#1 v1.5) chỉ được tồn tại *bên trong* certificate do CA cấp, cấm dùng để ký CertificateVerify.
- **EdDSA** (Ed25519, Ed448) — đời mới, gọn nhẹ.

Đồ cổ bị khai tử hẳn: MD5, SHA-224, DSA. SHA-1 chỉ còn được du di cho certificate cũ, cấm xuất hiện trong chữ ký handshake.

## 5. TLS 1.3 hơn TLS 1.2 chỗ nào? (4 ý để trả lời thi)

1. **Certificate được mã hóa khi gửi.** Bản 1.2 gửi trần, ai rình mạng cũng biết bạn kết nối tới đâu.
2. **Private key của server giờ chỉ dùng để ký, không dùng để mã hóa dữ liệu phiên nữa.** Bản 1.2 cho phép client mã hóa bí mật phiên bằng khóa của server (static RSA) — hậu quả: khóa server mà lộ một lần là **toàn bộ dữ liệu ghi âm từ trước tới nay bị giải mã sạch**. Bản 1.3 bắt buộc Diffie-Hellman tạm thời, mỗi phiên một khóa riêng, lộ khóa server cũng không giải mã được quá khứ — tính chất này gọi là **forward secrecy**.
3. **Server giờ cũng phải gửi CertificateVerify** (trước kia chỉ client gửi). Tức là server phải ký tươi lên toàn bộ cuộc bắt tay — bằng chứng trực tiếp và mạnh hơn kiểu chứng minh gián tiếp cũ.
4. **Dọn rác thuật toán yếu:** MD5, SHA-1, DSA, PKCS#1 v1.5 (trong handshake) đều bị loại.

---

*Đã lược bỏ có chủ đích: format struct chi tiết, OCSP/SCT stapling, post-handshake authentication, raw public key, bảng alert đầy đủ. Cần thì tra RFC sau — không món nào làm thay đổi cách hiểu ở trên.*
