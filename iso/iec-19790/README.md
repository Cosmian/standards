# ISO/IEC 19790:2012 — Security Requirements for Cryptographic Modules

## Standard

**ISO/IEC 19790:2012**, *Information technology — Security techniques — Security requirements
for cryptographic modules*, International Organization for Standardization / International
Electrotechnical Commission, 2012.

- ISO catalogue entry: <https://www.iso.org/standard/52906.html>
- Purchase from ISO: <https://www.iso.org/standard/52906.html>

> **Note**: ISO/IEC 19790:2012 is a paid standard and cannot be distributed freely.
> The United States adopted it as **FIPS 140-3** (see below), which is freely available.

---

## US equivalent — FIPS 140-3 (free)

The United States National Institute of Standards and Technology (NIST) adopted ISO/IEC 19790:2012
as **FIPS 140-3** (*Security Requirements for Cryptographic Modules*), published May 2019.

FIPS 140-3 is substantively identical to ISO/IEC 19790:2012 for the purpose of the requirements
it imposes on cryptographic modules. It is freely available:

- PDF: [`../../../nist/fips/NIST.FIPS.140-3.pdf`](../../../nist/fips/NIST.FIPS.140-3.pdf)
- NIST page: <https://csrc.nist.gov/pubs/fips/140-3/final>

The FIPS 140-3 Implementation Guidance (FAQ) document is also available:

- PDF: [`../../../nist/fips/NIST.FIPS.140-3-ImplementationGuidance.pdf`](../../../nist/fips/NIST.FIPS.140-3-ImplementationGuidance.pdf)

---

## Scope of ISO/IEC 19790:2012

The standard specifies security requirements for cryptographic modules used in security systems
that protect sensitive information. It defines:

- **Four security levels** (1–4) for cryptographic modules, covering a wide spectrum from
  administrative data to life-protecting data.
- **Eleven requirement areas**, each with four security levels:
  1. Cryptographic module specification
  2. Cryptographic module interfaces
  3. Roles, services, and authentication ← *relevant to Cosmian KMS role model*
  4. Finite state model
  5. Physical security
  6. Operational environment
  7. Cryptographic key management
  8. Electromagnetic interference / electromagnetic compatibility (EMI/EMC)
  9. Self-tests
  10. Design assurance
  11. Mitigation of other attacks

---

## Relevance to Cosmian KMS

Cosmian KMS draws on ISO/IEC 19790:2012 (via FIPS 140-3) for the **Roles, services, and
authentication** requirement area (area 3):

| ISO/IEC 19790 requirement | Cosmian KMS implementation |
|---|---|
| Mandatory **Crypto Officer** role — responsible for cryptographic module initialisation, configuration, and key management | **CryptoOfficer** role: Create, Import, Certify, Activate, Revoke, Destroy, ReKey, Get/Export (lifecycle + key output + ownership bypass) |
| Mandatory **User** role — responsible for general operation | **Operator** role (default): Encrypt, Decrypt, Sign, MAC, Hash (crypto use only) |
| Separation between key management and key use | CryptoOfficer cannot Encrypt/Decrypt/Sign; Operator cannot Create/Destroy/Get key material |
| Optional Maintenance role | Not implemented |
