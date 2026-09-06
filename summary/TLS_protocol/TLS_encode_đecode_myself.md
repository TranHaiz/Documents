# Ví dụ về mã hóa/giải mã dữ liệu bằng TLS RSA

1. Chọn 2 số nguyên tố p, q

ví dụ p=61, q=53.
Tính n = p*q = 61*53 = 3233. Tính φ(n) = (p-1)(q-1) = 60*52 = 3120.

2. Chọn e và tính d

Chọn e = 17 (1 < e < φ(n) và gcd(e, φ(n)) = 1). Tính d sao cho d*e ≡ 1 (mod φ(n)). Ta có d = 2753.

3. Mã hóa

Giả sử muốn mã hóa thông điệp m = 65.
Công thức mã hóa: c = m^e mod n
=> c = 65^17 mod 3233 = 2790

4. Giải mã

Công thức giải mã: m = c^d mod n
=> m = 2790^2753 mod 3233 = 65

# Giả sử bên tấn công thực hiện giải mã

Kẻ tấn công có trong tay (toàn đồ công khai + nghe lén được):

- n = 3233, e = 17 (lấy từ certificate)
- c = 2790 (bắt được trên đường truyền)

Mục tiêu: tìm m. Muốn vậy phải có d → phải có φ(n) → phải tách n ra p, q.

1. Tách n ra thừa số

Chia thử n cho các số nguyên tố từ nhỏ đến √3233 ≈ 56.9:

```text
3233 / 2  → không chia hết
3233 / 3  → không chia hết
3233 / 5, 7, 11, 13, ... → không chia hết
3233 / 53 → 61  ✅ TRÚNG
```

=> p = 53, q = 61. (Chỉ mất ~15 phép thử vì n quá bé — đây chính là lý do RSA thật phải dùng n dài 2048 bit trở lên.)

2. Tính φ(n)

φ(n) = (53-1)(61-1) = 52 × 60 = 3120

3. Tính d (làm y hệt bước tạo khóa của chính chủ)

Giải 17 × d ≡ 1 (mod 3120) bằng thuật toán Euclid mở rộng => d = 2753.

Kiểm tra: 17 × 2753 = 46801 = 15 × 3120 + 1 ✓

4. Giải mã trộm

m = c^d mod n = 2790^2753 mod 3233 = 65 💥

Kẻ tấn công đọc được đúng thông điệp gốc, không cần trộm bất cứ thứ gì từ server.

## Nhận xét

- Từng bước 2, 3, 4 đều là phép tính NHANH. Bức tường duy nhất là bước 1 (tách thừa số).
- Với n = 3233: bước 1 mất 1 giây. Với n = 2048 bit (617 chữ số): thuật toán tốt nhất hiện nay (GNFS) tốn ~2^112 phép tính → coi như bất khả thi. Toàn bộ độ an toàn của RSA nằm ở đúng chỗ này.
- Kẻ tấn công không cần phá ngay: hắn có thể LƯU c hôm nay, chờ ngày private key bị lộ (server bị hack) hoặc máy tính đủ mạnh, rồi giải mã quá khứ. RSA key exchange không có forward secrecy — đây là lý do TLS 1.3 loại bỏ nó, chỉ giữ Diffie-Hellman ephemeral.
