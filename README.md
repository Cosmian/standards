# Standards Reference Library

Local copy of all standards, RFCs, and cryptographic specifications referenced
by or applicable to the Cosmian KMS. Fetched to avoid hallucinations on spec details.

## Directory Layout

```text
standards/
├── rfc/                 # All IETF RFCs (text format, rfc*.txt)
├── nist/
│   ├── fips/            # FIPS publications (PDF)
│   └── sp800/           # NIST SP 800-series (PDF)
├── oasis/
│   ├── kmip/            # KMIP specifications (HTML)
│   └── pkcs11/          # PKCS#11 specifications (HTML)
├── bsi/                 # BSI TR-02102 technical guidelines (PDF)
├── anssi/               # ANSSI recommendations (PDF)
├── secg/                # SEC/SECG elliptic curve standards (PDF)
├── ansi/                # ANSI X9 standards (PDF)
├── owasp/               # OWASP Top 10, ASVS, cheat sheets (HTML/PDF)
└── ietf-drafts/         # Relevant IETF drafts
```

## How to Refresh

```bash
bash standards/fetch-all.sh
```

## Key References

| Standard | Local Path | Notes |
| -------- | ---------- | ----- |
| RFC 5649 (AES Key Wrap) | rfc/rfc5649.txt | |
| RFC 3394 (AES Key Wrap) | rfc/rfc3394.txt | |
| FIPS 140-3 | nist/fips/NIST.FIPS.140-3.pdf | |
| FIPS 203 (ML-KEM) | nist/fips/NIST.FIPS.203.pdf | |
| FIPS 204 (ML-DSA) | nist/fips/NIST.FIPS.204.pdf | |
| FIPS 205 (SLH-DSA) | nist/fips/NIST.FIPS.205.pdf | |
| KMIP 2.1 | oasis/kmip/kmip-spec-v2.1-os.html | Primary KMIP spec |
| PKCS#11 v3.1 | oasis/pkcs11/pkcs11-spec-v3.1.html | |
| BSI TR-02102-1 | bsi/BSI-TR-02102-1.pdf | |
| SEC 1 v2.0 | secg/sec1-v2.pdf | |
