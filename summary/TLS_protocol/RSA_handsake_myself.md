# Quy trình handsake RSA (TLS 1.2 trở về trước)

1. Client Hello
Client mở đầu phiên kết nối TLS, gửi phiên bản TLS, danh sách cipher suite, và client random.

2. Server Hello
Server đáp lại, gửi public key, certificate, cipher suite đã chọn, server random.

3. Authentication
Client kiểm tra certificate với CA đã cấp nó: chữ ký CA có hợp lệ không, còn hạn không, đúng tên miền không.

4. Premaster secret
Client sinh thêm một chuỗi ngẫu nhiên nữa: premaster secret. Nó mã hóa chuỗi này bằng public key lấy từ certificate rồi gửi cho server.

5. Server dùng private key
Server giải mã premaster secret bằng private key.

6. Tạo session key
Cả hai bên cùng nấu session key từ 3 nguyên liệu: client random + server random + premaster secret. Công thức giống nhau → ra kết quả giống nhau, dù không bên nào gửi thẳng khóa cho bên kia.

7. Client ready
Client gửi thông điệp Finished, đã mã hóa bằng session key → "phía tôi xong, khóa dùng được".

8. Server ready
Server gửi Finished của nó, cũng mã hóa bằng session key.

9. Mã hóa đối xứng bắt đầu
