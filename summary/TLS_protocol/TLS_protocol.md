# TLS 1.3 Certificates — The Core Ideas (RFC 8446)

This is not a list of every rule in the RFC. It keeps only the parts that matter for understanding how certificates work in TLS 1.3, and explains each one properly.

---

## 1. The big picture: what problem certificates solve in TLS

The TLS handshake does two separate jobs, and it is important not to mix them up:

1. **Key exchange** creates a shared secret. In TLS 1.3 this is always an ephemeral Diffie-Hellman exchange (`key_share` in ClientHello/ServerHello). By itself, this gives you an encrypted channel — but you have no idea *who* is on the other end. An attacker sitting in the middle could have done the same exchange with you.
2. **Authentication** proves who the other end is. This is the job of certificates.

So the certificate is not there to encrypt anything. Its only job is identity: the server says *"I am example.com, and here is a chain of signatures from a CA you trust that vouches for me."*

The handshake looks like this:

```text
Client                                          Server
ClientHello
 + key_share
 + signature_algorithms        -------->
                                          ServerHello + key_share
                                          {EncryptedExtensions}
                                          {CertificateRequest*}     <- only for mutual TLS
                                          {Certificate}             <- "this is who I am"
                                          {CertificateVerify}       <- "and I can prove it"
                                          {Finished}                <- "and nothing was tampered with"
{Certificate*}                 <--------
{CertificateVerify*}
{Finished}                     -------->
[Application Data]             <------->  [Application Data]
```

Everything in `{}` is already encrypted, because the Diffie-Hellman exchange finished with the ServerHello. This is a real difference from TLS 1.2, where the certificate was sent in plaintext and anyone watching the network could see which certificate (which identity) a server presented.

One more thing to keep in mind: when a session is **resumed with a PSK** (pre-shared key), certificates are not used at all. Authentication in that case comes from the fact that both sides already hold the same secret from a previous connection.

## 2. The three authentication messages — and why all three are needed

Authentication in TLS 1.3 is always the same trio of messages, in a fixed order. Each answers a question the previous one cannot:

### Certificate — "this is who I claim to be"

The endpoint sends its **certificate chain**: its own certificate first, then the intermediate CA certificates, up toward a root that the peer already trusts (the root itself is usually omitted — the peer has it locally). Each certificate is a public key plus an identity, signed by the next one in the chain.

But notice the weakness: a certificate is **public information**. Anyone can download example.com's certificate and send it to you. So this message alone proves nothing.

### CertificateVerify — "and I actually hold the private key"

This closes the gap. The sender takes a **hash of the entire handshake transcript so far** (every handshake message, including the certificate itself) and **signs it with the private key** matching the certificate.

Two things make this powerful:

- Only the real owner of the private key can produce this signature — so a stolen/copied certificate is useless without the key.
- Because the signature covers *this specific handshake* (including both random nonces), it cannot be replayed in another connection. An attacker who records the signature can't reuse it — a new handshake has a different transcript, so the old signature won't verify.

If the signature fails to verify, the connection is aborted (`decrypt_error`).

### Finished — "and nothing in the handshake was tampered with"

The final message is an **HMAC over the whole handshake transcript**, keyed with a secret derived from the Diffie-Hellman result. It confirms two things at once:

- Both sides derived the same keys (key confirmation).
- No attacker modified any handshake message in flight — for example, downgrading the offered algorithms. If anything was altered, the transcripts differ, the MACs differ, and the handshake fails.

Only after Finished is verified on both sides does application data flow.

**In one sentence:** *Certificate* gives the identity, *CertificateVerify* proves possession of the key behind that identity, and *Finished* seals the whole conversation against tampering.

## 3. Mutual TLS: authenticating the client too

By default only the server proves its identity (this is what happens when you browse the web). If the server also wants to know who the client is — common in IoT, microservices, enterprise APIs — it sends a **CertificateRequest** message right after EncryptedExtensions.

The request tells the client what would be acceptable: which **signature algorithms** the server can verify (mandatory), and optionally which **CAs** it trusts (`certificate_authorities`) or which certificate properties it requires (`oid_filters`, e.g. a specific Extended Key Usage).

The client then answers with its own Certificate + CertificateVerify + Finished — the exact same trio, same rules. Two details worth knowing:

- If the client has no suitable certificate, it doesn't abort. It sends an **empty** Certificate message, and the *server* decides: continue with an unauthenticated client, or abort with `certificate_required`.
- The server proves its identity **first**, before the client sends anything. So a client never reveals its identity to an unauthenticated server — the opposite of TLS 1.2, where the client certificate went out in plaintext before server verification completed.

## 4. Signature algorithms: how both sides agree on the crypto

The client's `signature_algorithms` extension in ClientHello lists what signatures it can verify. This drives everything: the server must pick a certificate whose key matches one of these algorithms, and it must use one of them for CertificateVerify.

The practical set in TLS 1.3 is small:

- **ECDSA** with the NIST curves (P-256/P-384/P-521) — the most common today.
- **RSA-PSS** — if RSA is used, handshake signatures MUST be PSS. The old PKCS#1 v1.5 padding is allowed only *inside* certificates (because CAs still issue them), never in CertificateVerify.
- **EdDSA** (Ed25519 / Ed448) — modern and compact.

Removed outright: MD5, SHA-224, DSA. SHA-1 survives only as a legacy option for old certificates and MUST NOT appear in handshake signatures.

There is a second extension, `signature_algorithms_cert`, for the rare case where what you can verify in *certificates* differs from what you can verify in the *handshake*. If it's absent, `signature_algorithms` covers both — which is the normal case.

## 5. What changed from TLS 1.2 — the exam-answer version

If you need to explain "what did TLS 1.3 improve about certificates/authentication," these are the points:

1. **Certificates are encrypted in transit.** In TLS 1.2 they were plaintext; now a network observer learns nothing about the presented identity.
2. **The certificate key is only ever used for signing.** TLS 1.2 allowed static-RSA key exchange (client encrypts the session secret with the server's certificate key). That meant a leaked server key could decrypt *all past recorded traffic*. TLS 1.3 removed it: key exchange is always ephemeral DH, so every session has **forward secrecy**, and the certificate key only signs CertificateVerify.
3. **The server now sends CertificateVerify too.** In TLS 1.2 the server's key possession was proven implicitly through the key exchange; with static RSA gone, an explicit transcript signature is required — and it covers the *whole* handshake, which is stronger.
4. **Weak algorithms are gone** (MD5, SHA-1 in signatures, PKCS#1 v1.5 in handshake, DSA), and the negotiation is cleaner: one `SignatureScheme` code point instead of separate hash/signature pairs.

---

*Deliberately left out (details you can look up if ever needed): exact struct layouts, OCSP/SCT stapling mechanics, post-handshake client authentication, raw public keys, and the full alert table. None of them change the mental model above.*
