# OpenSSL Quick Reference — Chapter 3: PKI

Common OpenSSL commands for certificate inspection, validation, and PKI operations.
Cross-platform: Linux, macOS, Windows (with OpenSSL installed).

---

## 1. Generate a Private Key
```bash
# RSA 4096-bit (general use)
openssl genrsa -out private.key 4096

# ECDSA P-256 (preferred for new deployments — smaller, faster)
openssl ecparam -name prime256v1 -genkey -noout -out ec-private.key
```

## 2. Generate a Certificate Signing Request (CSR)
```bash
openssl req -new -key private.key -out request.csr \
  -subj "/C=US/ST=Texas/L=Austin/O=Acme Corp/CN=server.acme.com"

# With SANs (required for modern browsers)
openssl req -new -key private.key -out request.csr -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = server.acme.com
[v3_req]
subjectAltName = DNS:server.acme.com,DNS:www.acme.com
EOF
)
```

## 3. Inspect a Certificate
```bash
# View full certificate details
openssl x509 -in cert.pem -noout -text

# View just subject, issuer, expiry
openssl x509 -in cert.pem -noout -subject -issuer -dates

# View SANs only
openssl x509 -in cert.pem -noout -ext subjectAltName
```

## 4. Verify Certificate Chain
```bash
# Verify cert against CA bundle
openssl verify -CAfile ca-chain.pem cert.pem

# Verify with intermediate
openssl verify -CAfile root-ca.pem -untrusted intermediate.pem server-cert.pem
```

## 5. Test Remote Server Certificate
```bash
# View certificate from live server
openssl s_client -connect server.acme.com:443 -showcerts </dev/null 2>/dev/null | \
  openssl x509 -noout -text

# Show full chain
openssl s_client -connect server.acme.com:443 -showcerts 2>/dev/null
```

## 6. Test OCSP Stapling
```bash
# Check if server staples OCSP response
openssl s_client -connect server.acme.com:443 -status </dev/null 2>/dev/null | \
  grep -A 20 "OCSP Response"

# Manual OCSP query (get OCSP URL from cert first)
OCSP_URL=$(openssl x509 -in cert.pem -noout -text | grep "OCSP - URI" | awk '{print $NF}')
openssl ocsp -issuer intermediate.pem -cert cert.pem -url $OCSP_URL -text
```

## 7. Convert Certificate Formats
```bash
# PEM → DER
openssl x509 -in cert.pem -outform DER -out cert.der

# DER → PEM
openssl x509 -in cert.der -inform DER -outform PEM -out cert.pem

# PEM → PKCS12 (PFX)
openssl pkcs12 -export -out cert.pfx -inkey private.key -in cert.pem -certfile ca-chain.pem

# PKCS12 → PEM
openssl pkcs12 -in cert.pfx -out cert-and-key.pem -nodes
```

## 8. Check CRL (Certificate Revocation List)
```bash
# Download and inspect CRL
CRL_URL=$(openssl x509 -in cert.pem -noout -text | grep "CRL Distribution" -A 1 | grep "http")
curl -s "$CRL_URL" | openssl crl -inform DER -text -noout | head -50
```

## 9. Check Certificate Fingerprint
```bash
# SHA256 fingerprint (use for pinning verification)
openssl x509 -in cert.pem -noout -fingerprint -sha256
```

## 10. Generate Self-Signed Certificate (lab only)
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/CN=lab.internal" \
  -addext "subjectAltName=DNS:lab.internal,DNS:*.lab.internal"
```

## 11. Test TLS Cipher Suites
```bash
# What ciphers does the server support?
openssl s_client -connect server.acme.com:443 -cipher "TLS_AES_256_GCM_SHA384" </dev/null
nmap --script ssl-enum-ciphers -p 443 server.acme.com  # More comprehensive
```

## 12. Create CA (Lab / Test PKI)
```bash
# Root CA
openssl genrsa -aes256 -out root-ca.key 4096
openssl req -x509 -new -nodes -key root-ca.key -sha256 -days 3650 -out root-ca.pem \
  -subj "/CN=Lab Root CA"

# Issuing CA signed by Root
openssl genrsa -out issuing-ca.key 4096
openssl req -new -key issuing-ca.key -out issuing-ca.csr -subj "/CN=Lab Issuing CA"
openssl x509 -req -in issuing-ca.csr -CA root-ca.pem -CAkey root-ca.key \
  -CAcreateserial -out issuing-ca.pem -days 1825 -sha256 \
  -extfile <(echo "basicConstraints=critical,CA:true,pathlen:0")
```

## 13. Parse JWT (quick decode — NOT verification)
```bash
# Decode header and payload (base64url decode)
JWT="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature"
echo "${JWT%%.*}" | base64 -d 2>/dev/null | python3 -m json.tool        # Header
echo "${JWT}" | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool  # Payload
```

## 14. Check Certificate Transparency Logs
```bash
# Query crt.sh for all certificates for a domain
curl -s "https://crt.sh/?q=%.acme.com&output=json" | python3 -m json.tool | grep "name_value"
```

## 15. ESC8 Test (ADCS HTTP exposure)
```bash
# Check if certsrv is accessible over HTTP (see Script 3-5)
curl -v -I http://ca-server.corp.com/certsrv 2>&1 | grep -E "< HTTP|< WWW-Authenticate|< Location"
# Look for: WWW-Authenticate: NTLM → ESC8 vulnerable
```

---
*All commands tested with OpenSSL 3.x. Some flags differ slightly in OpenSSL 1.x.*
