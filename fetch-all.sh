#!/usr/bin/env bash
# fetch-all.sh — Download all standards, RFCs, and cryptographic specification documents
# for the Cosmian KMS reference library.
#
# Usage: bash standards/fetch-all.sh [section]
#   section: rfc | nist | bsi | anssi | secg | ansi | ieee | etsi | owasp | drafts | all (default)
#
# Requirements: curl, rsync (for RFC bulk)
#
# NOTE: OASIS standards (KMIP, PKCS#11) are intentionally excluded here.
#       They live in the ./kmip submodule which is already checked out locally.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECTION="${1:-all}"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err() { echo -e "${RED}✗${NC} $*"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
fetch_pdf() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    ok "already present: $(basename "$dest")"
    return 0
  fi
  echo "  → fetching $(basename "$dest") …"
  if curl -sSL --retry 3 --retry-delay 2 -o "$dest" "$url"; then
    ok "$(basename "$dest")"
  else
    err "FAILED: $url"
    rm -f "$dest"
    return 1
  fi
}

fetch_html() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    ok "already present: $(basename "$dest")"
    return 0
  fi
  echo "  → fetching $(basename "$dest") …"
  if curl -sSL --retry 3 --retry-delay 2 -o "$dest" "$url"; then
    ok "$(basename "$dest")"
  else
    err "FAILED: $url"
    rm -f "$dest"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Section: RFC — bulk download ALL RFCs via rsync
# ---------------------------------------------------------------------------
fetch_rfcs() {
  echo ""
  echo "================================================================="
  echo " RFC — Fetching ALL IETF RFCs via rsync (ftp.rfc-editor.org)"
  echo "================================================================="
  local rfc_dir="$SCRIPT_DIR/rfc"
  mkdir -p "$rfc_dir"

  if ! command -v rsync &>/dev/null; then
    warn "rsync not found — falling back to individual RFC downloads"
    fetch_rfcs_individual
    return
  fi

  echo "  Syncing RFC text corpus (this may take several minutes)…"
  # rsync from official RFC Editor mirror — text-only format (~200 MB compressed)
  if rsync -avz --no-motd --delete \
    ftp.rfc-editor.org::rfcs-text-only \
    "$rfc_dir/" 2>&1 | tail -5; then
    ok "RFC corpus synced to $rfc_dir"
  else
    warn "rsync from ftp.rfc-editor.org failed — trying HTTP fallback"
    fetch_rfcs_index_based
  fi
}

fetch_rfcs_index_based() {
  # Download RFC index and then fetch each RFC via HTTPS
  local rfc_dir="$SCRIPT_DIR/rfc"
  local index_file="$rfc_dir/rfc-index.txt"

  echo "  Downloading RFC index…"
  curl -sSL "https://www.rfc-editor.org/rfc/rfc-index.txt" -o "$index_file" || {
    err "Cannot download RFC index"
    return 1
  }

  # Parse RFC numbers from index
  local rfc_numbers
  rfc_numbers=$(grep -oE '^[0-9]{4}' "$index_file" | sort -n)
  local total
  total=$(echo "$rfc_numbers" | wc -l | tr -d ' ')
  echo "  Found $total RFCs in index"

  local count=0 failed=0
  for num in $rfc_numbers; do
    count=$((count + 1))
    local dest="$rfc_dir/rfc${num}.txt"
    if [[ -f "$dest" && -s "$dest" ]]; then
      continue # skip already downloaded
    fi
    if ! curl -sSL --retry 3 --retry-delay 1 \
      "https://www.rfc-editor.org/rfc/rfc${num}.txt" \
      -o "$dest" 2>/dev/null; then
      rm -f "$dest"
      failed=$((failed + 1))
    fi
    # Progress every 100
    if ((count % 100 == 0)); then
      echo "  Progress: $count/$total (failed: $failed)"
    fi
  done
  ok "RFC download complete: $count total, $failed failed"
}

fetch_rfcs_individual() {
  # Download the RFCs explicitly referenced in the codebase + closely related ones
  local rfc_dir="$SCRIPT_DIR/rfc"
  mkdir -p "$rfc_dir"

  local -a RFCS=(
    # Legacy message-digest algorithms (referenced in KMIP spec)
    1319 # MD2 Message-Digest Algorithm
    1320 # MD4 Message-Digest Algorithm
    1321 # MD5 Message-Digest Algorithm
    1421 # Privacy Enhancement for Internet Electronic Mail (PEM)
    1422 # PEM — Certificate-Based Key Management
    1423 # PEM — Algorithms, Modes, and Identifiers
    1424 # PEM — Key Certification and Related Services

    # Core HMAC / PRF
    1945 # HTTP/1.0
    2104 # HMAC: Keyed-Hashing for Message Authentication
    2202 # Test Cases for HMAC-MD5 and HMAC-SHA-1
    2253 # LDAP Distinguished Names
    2315 # PKCS#7 CMS v1.5
    2437 # PKCS#1 RSA Cryptography v2.0 (predecessor to 3447)
    2459 # X.509 PKI (predecessor to 5280)
    2560 # OCSP (predecessor to 6960)
    2630 # CMS v1 (predecessor to 3852)
    2631 # DH Key Agreement Method
    2797 # Certificate Management Messages over CMS
    2818 # HTTP over TLS
    2898 # PKCS#5 v2.0 Password-Based Cryptography
    2985 # PKCS#9 Selected Object Classes and Attribute Types
    2986 # PKCS#10 Certification Request Syntax v1.7
    3058 # Use of the IDEA Encryption Algorithm in CMS
    3161 # Internet X.509 PKI Timestamp Protocol (TSP)
    3217 # Triple-DES and RC2 Key Wrapping
    3218 # Preventing the Million Message Attack on CMS
    3274 # Compressed Data Content Type for CMS
    3278 # Use of ECC in CMS
    3279 # Algorithms and Identifiers for X.509 PKI
    3339 # Date and Time on the Internet: Timestamps (RFC 3339)
    3394 # AES Key Wrap Algorithm
    3447 # PKCS#1 RSA Cryptography Specifications v2.1
    3548 # Base16/32/64 Data Encodings
    3565 # Use of AES Encryption Algorithms in CMS
    3602 # AES-CBC Algorithm in IPsec ESP and AH
    3686 # AES CTR Mode in IPsec
    3713 # A Description of the Camellia Encryption Algorithm
    3766 # Determining Strengths For Public Keys
    3852 # CMS v3 (predecessor to 5652)
    4010 # Use of the SEED Encryption Algorithm in CMS
    4049 # BinarySigningTime Attribute for CMS
    4055 # Additional Algorithms for RSA in PKIX
    4056 # Use of RSA-OAEP Key Transport in CMS
    4086 # Randomness Requirements for Security
    4108 # Using CMS to Protect Firmware Packages
    4122 # UUID URN Namespace
    4231 # HMAC-SHA-2 Test Vectors
    4262 # X.509 Certificate Extension for S/MIME
    4346 # TLS 1.1 (predecessor to 5246)
    4347 # Datagram TLS (DTLS) 1.0
    4357 # Additional Cryptographic Algorithms for GOST
    4490 # Using GOST in CMS
    4491 # Using GOST in PKIX
    4492 # ECC Cipher Suites for TLS
    4493 # AES-CMAC Algorithm
    4494 # AES-CMAC-96 Algorithm
    4535 # GKMP Architecture
    4566 # SDP Session Description Protocol
    4630 # Update MIME Parameters for PKIX
    4648 # Base16/32/64 Data Encodings
    4659 # BGP-MPLS IP Virtual Private Networks
    4680 # TLS Handshake Message for Supplemental Data
    4754 # IKE and IKEv2 Authentication Using ECDSA
    4768 # Intended Status Values
    4880 # OpenPGP Message Format
    4945 # Internet PKI: An Inspection and Recommendations
    5083 # AES-GCM for CMS
    5084 # Using Camellia in CMS
    5116 # An Interface and Algorithms for AEAD
    5126 # CMS Advanced Electronic Signatures (CAdES)
    5246 # TLS 1.2
    5272 # Certificate Management over CMS (CMC)
    5280 # X.509 PKI Certificate and CRL Profile
    5288 # AES-GCM for TLS
    5480 # ECC Subject Public Key Information
    5652 # Cryptographic Message Syntax (CMS)
    5751 # S/MIME v3.2 — Message Specification
    5752 # Multiple Signatures in S/MIME
    5755 # X.509 Attribute Certificates
    5758 # Additional DSA/ECDSA Algorithms for PKIX
    5780 # NAT Behaviour Discovery
    5869 # HMAC-based Extract-and-Expand Key Derivation Function (HKDF)
    5916 # Device Owner Attribute (KMIP)
    5958 # Asymmetric Key Packages (OneAsymmetricKey / PKCS#8)
    6031 # PKCS#11 URI Scheme (predecessor to 7512)
    6090 # Fundamental ECC Algorithms
    6151 # Updated Security Considerations for MD5
    6194 # Updated Security Considerations for SHA-0 and SHA-1
    6234 # US Secure Hash Algorithms (SHA and HMAC-SHA)
    6268 # Additional New ASN.1 Modules
    6402 # Certificate Management over CMS Updates
    6507 # Elliptic Curve Based Password Authenticated Key Exchange
    6749 # OAuth 2.0 Authorization Framework
    6818 # Updates to X.509 Certificate Profile
    6960 # Online Certificate Status Protocol (OCSP)
    6962 # Certificate Transparency
    6979 # Deterministic Usage of ECDSA and DSA
    7191 # EAP Attributes for WiFi
    7159 # JSON (predecessor to 8259)
    7292 # PKCS#12 Personal Information Exchange Syntax v1.1
    7366 # Encrypt-then-MAC for TLS and DTLS
    7468 # Textual Encodings of PKIX/CMS/CMS Structures (PEM)
    7512 # PKCS#11 URI Scheme
    7515 # JSON Web Signature (JWS)
    7516 # JSON Web Encryption (JWE)
    7517 # JSON Web Key (JWK)
    7518 # JSON Web Algorithms (JWA)
    7519 # JSON Web Token (JWT)
    7520 # JWS/JWE Examples
    7525 # TLS Recommendations
    7539 # ChaCha20 and Poly1305 (predecessor to 8439)
    7636 # PKCE for OAuth 2.0
    7748 # Elliptic Curves for Security (X25519, X448)
    7778 # JSON Web Encryption AES-CBC + HMAC (informational)
    7905 # ChaCha20-Poly1305 for TLS
    8017 # PKCS#1 RSA Cryptography Specifications v2.2
    8018 # PKCS#5 Password-Based Cryptography v2.1
    8032 # EdDSA: Ed25519 and Ed448
    8037 # CFRG Elliptic Curves for JOSE
    8174 # Ambiguity of Uppercase vs Lowercase RFC 2119
    8259 # JSON Data Interchange Format
    8398 # Internationalized Email Addresses in X.509 Certificates
    8410 # Algorithm Identifiers for Ed25519/Ed448/X25519/X448
    8411 # IANA Registry for PKIX Action Types
    8418 # JWK Elliptic Curve Key Agreement Algorithms
    8439 # ChaCha20 and Poly1305 for IETF Protocols
    8446 # The Transport Layer Security (TLS) Protocol v1.3
    8452 # AES-GCM-SIV: Nonce Misuse-Resistant AEAD
    8463 # A New Cryptographic Signature Method for DKIM
    8551 # S/MIME v4.0
    8591 # ACME Protocol
    8603 # Commercial National Security Algorithm Suite for TLS
    8623 # Symmetric AES-CMAC for CMS
    8625 # TLS Extension for Encrypted Client Hello
    8693 # OAuth 2.0 Token Exchange
    8725 # JWT Best Current Practices
    8737 # ACME IP Identifier Validation Extension
    8812 # ECDSA Algorithms for JOSE and CASE
    8894 # SCEP Simple Certificate Enrollment Protocol
    8996 # Deprecating TLS 1.0 and 1.1
    9052 # CBOR Object Signing and Encryption (CASE)
    9053 # CASE Algorithms
    9058 # Multikey Encryption (KMIP context)
    9106 # Argon2 Memory-Hard Function for Password Hashing
    9155 # Deprecating MD5 and SHA-1 in TLS
    9162 # Certificate Transparency v2.0
    9180 # Hybrid Public Key Encryption (HPKE)
    9216 # RFC Formats and Versions
    9291 # NETCONF Access Control
    9325 # Security Review of TLS 1.3 Deployments
    9380 # Hashing to Elliptic Curves
    9420 # Messaging Layer Security (MLS)
    9528 # EDHOC: Ephemeral DH-Based Key Exchange
    9580 # OpenPGP — Revision of RFC 4880
    9608 # No Revocation Available X.509 Extension
    9629 # Using Key Encapsulation Mechanism (KEM) in HPKE
    9636 # Certificate Policies for Cryptographic Modules
    9696 # PKIX Certificate Transparency SCT
    9881 # AES-XCBC-MAC-96 Update (KMIP)
    9909 # X.509 Certificate Policies — Updates (KMIP)
    9935 # PKIX Key Usage for HSM (KMIP)
  )

  local total=${#RFCS[@]}
  local count=0 failed=0
  for num in "${RFCS[@]}"; do
    count=$((count + 1))
    local dest="$rfc_dir/rfc${num}.txt"
    if [[ -f "$dest" && -s "$dest" ]]; then
      ok "already present: rfc${num}.txt"
      continue
    fi
    echo "  [${count}/${total}] rfc${num}.txt …"
    if ! curl -sSL --retry 3 --retry-delay 2 \
      "https://www.rfc-editor.org/rfc/rfc${num}.txt" \
      -o "$dest" 2>/dev/null; then
      rm -f "$dest"
      failed=$((failed + 1))
      warn "FAILED: rfc${num}.txt"
    fi
  done
  ok "Individual RFC download: $count total, $failed failed"
}

# ---------------------------------------------------------------------------
# Section: NIST FIPS
# ---------------------------------------------------------------------------
fetch_nist_fips() {
  echo ""
  echo "================================================================="
  echo " NIST FIPS — Federal Information Processing Standards"
  echo "================================================================="
  local dir="$SCRIPT_DIR/nist/fips"
  mkdir -p "$dir"

  # Format: url, filename
  local -a FIPS=(
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.140-3.pdf" "NIST.FIPS.140-3.pdf"
    "https://csrc.nist.gov/CSRC/media/Projects/cryptographic-module-validation-program/documents/fips%20140-3/FIPS%20140-3%20IG.pdf" "NIST.FIPS.140-3-ImplementationGuidance.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf" "NIST.FIPS.180-4.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-5.pdf" "NIST.FIPS.186-5.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf" "NIST.FIPS.197-upd1.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.198-1.pdf" "NIST.FIPS.198-1.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.199.pdf" "NIST.FIPS.199.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.200.pdf" "NIST.FIPS.200.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.201-3.pdf" "NIST.FIPS.201-3.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf" "NIST.FIPS.202.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.203.pdf" "NIST.FIPS.203.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf" "NIST.FIPS.204.pdf"
    "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.205.pdf" "NIST.FIPS.205.pdf"
  )

  local i=0
  while [[ $i -lt ${#FIPS[@]} ]]; do
    local url="${FIPS[$i]}"
    local name="${FIPS[$((i + 1))]}"
    fetch_pdf "$url" "$dir/$name" || true
    i=$((i + 2))
  done
}

# ---------------------------------------------------------------------------
# Section: NIST SP 800-series
# ---------------------------------------------------------------------------
fetch_nist_sp800() {
  echo ""
  echo "================================================================="
  echo " NIST SP 800-series — Special Publications"
  echo "================================================================="
  local dir="$SCRIPT_DIR/nist/sp800"
  mkdir -p "$dir"

  # Format: url, filename
  local -a SP=(
    # Block cipher modes
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf" "NIST.SP.800-38A.pdf"
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38b.pdf" "NIST.SP.800-38B.pdf"
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38c.pdf" "NIST.SP.800-38C.pdf"
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf" "NIST.SP.800-38D.pdf"
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38e.pdf" "NIST.SP.800-38E.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38F.pdf" "NIST.SP.800-38F.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38G.pdf" "NIST.SP.800-38G.pdf"
    # Key establishment
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-56Ar3.pdf" "NIST.SP.800-56Ar3.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-56Br2.pdf" "NIST.SP.800-56Br2.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-56Cr2.pdf" "NIST.SP.800-56Cr2.pdf"
    # Key management
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-57pt1r5.pdf" "NIST.SP.800-57pt1r5.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-57pt2r1.pdf" "NIST.SP.800-57pt2r1.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-57pt3r1.pdf" "NIST.SP.800-57pt3r1.pdf"
    # RNG/DRBG
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90Ar1.pdf" "NIST.SP.800-90Ar1.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90B.pdf" "NIST.SP.800-90B.pdf"
    # KDF
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-108r1-upd1.pdf" "NIST.SP.800-108r1.pdf"
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-132.pdf" "NIST-SP-800-132.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-133r2.pdf" "NIST.SP.800-133r2.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-185.pdf" "NIST.SP.800-185.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-186.pdf" "NIST.SP.800-186.pdf"
    # Algorithm transitions
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-131Ar2.pdf" "NIST.SP.800-131Ar2.pdf"
    # Security guidelines
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf" "NIST.SP.800-190.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-204B.pdf" "NIST.SP.800-204B.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf" "NIST.SP.800-53r5.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63-3.pdf" "NIST.SP.800-63-3.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63B.pdf" "NIST.SP.800-63B.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207.pdf" "NIST.SP.800-207.pdf"
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-209.pdf" "NIST.SP.800-209.pdf"
    # Hash functions / PRF
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-107r1.pdf" "NIST.SP.800-107r1.pdf"
    # TDEA / Triple-DES
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-67r2.pdf" "NIST.SP.800-67r2.pdf"
    # Key storage / derivation
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-152.pdf" "NIST.SP.800-152.pdf"
    # Cryptographic testing
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-20.pdf" "NIST.SP.800-20.pdf"
    "https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-17.pdf" "NIST.SP.800-17.pdf"
    # SHA-3 derived functions (cSHAKE, KMAC, TupleHash, ParallelHash)
    "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-185.pdf" "NIST.SP.800-185.pdf"
  )

  local i=0
  while [[ $i -lt ${#SP[@]} ]]; do
    local url="${SP[$i]}"
    local name="${SP[$((i + 1))]}"
    fetch_pdf "$url" "$dir/$name" || true
    i=$((i + 2))
  done
}

# ---------------------------------------------------------------------------
# Section: BSI
# BSI website requires visiting the document's listing page first to establish
# a session cookie before downloading the PDF. The TR-02102 series is accessible
# this way. TR-03111, TR-03110, AIS20/31 are no longer publicly available on
# the BSI website as of 2024.
# ---------------------------------------------------------------------------
fetch_bsi() {
  echo ""
  echo "================================================================="
  echo " BSI — Bundesamt für Sicherheit in der Informationstechnik"
  echo "================================================================="
  local dir="$SCRIPT_DIR/bsi"
  mkdir -p "$dir"

  # BSI PDFs require a session cookie from the referrer page before download.
  bsi_dl() {
    local referer_page="$1"
    local pdf_url="$2"
    local dest="$3"
    local label="$4"

    if [[ -f "$dest" ]] && file "$dest" | grep -q "PDF"; then
      ok "already present: $label"
      return 0
    fi
    echo "  → $label"
    local ck
    ck=$(mktemp /tmp/bsi_ck_XXXXXX.txt)
    # Visit referer to get session cookie, then download PDF
    curl -sc "$ck" -sL -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
      "$referer_page" -o /dev/null 2>/dev/null
    curl -sL -b "$ck" -c "$ck" \
      -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
      -H "Referer: $referer_page" \
      "$pdf_url" -o "$dest" 2>/dev/null
    rm -f "$ck"
    if file "$dest" 2>/dev/null | grep -q "PDF"; then
      ok "$label"
    else
      err "FAILED: $label (BSI session cookie approach failed)"
      rm -f "$dest"
      return 1
    fi
  }

  local TR02102_REFERER="https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Standards-und-Zertifizierung/Technische-Richtlinien/TR-nach-Thema-sortiert/tr02102/tr02102_node.html"

  # TR-02102 parts 1-4 (Cryptographic Mechanisms: Recommendations and Key Lengths)
  bsi_dl "$TR02102_REFERER" \
    "https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/TechGuidelines/TG02102/BSI-TR-02102-1.pdf?__blob=publicationFile&v=14" \
    "$dir/BSI-TR-02102-1.pdf" "BSI TR-02102-1 (Cryptographic mechanisms)"

  bsi_dl "$TR02102_REFERER" \
    "https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/TechGuidelines/TG02102/BSI-TR-02102-2.pdf?__blob=publicationFile&v=11" \
    "$dir/BSI-TR-02102-2.pdf" "BSI TR-02102-2 (IPsec/VPN)"

  bsi_dl "$TR02102_REFERER" \
    "https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/TechGuidelines/TG02102/BSI-TR-02102-3.pdf?__blob=publicationFile&v=9" \
    "$dir/BSI-TR-02102-3.pdf" "BSI TR-02102-3 (SSH)"

  bsi_dl "$TR02102_REFERER" \
    "https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/TechGuidelines/TG02102/BSI-TR-02102-4.pdf?__blob=publicationFile&v=9" \
    "$dir/BSI-TR-02102-4.pdf" "BSI TR-02102-4 (TLS)"

  warn "BSI TR-03111 (ECC), TR-03110 (ePassport), AIS20/31 are no longer publicly downloadable."
  warn "BSI website requires JavaScript-gated downloads for these docs. Visit manually:"
  warn "  https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Standards-und-Zertifizierung/Technische-Richtlinien/"
}

# ---------------------------------------------------------------------------
# Section: ANSSI
# ANSSI moved all publications to https://messervices.cyber.gouv.fr/
# The API at /api/guides returns JSON with download URLs.
# ---------------------------------------------------------------------------
fetch_anssi() {
  echo ""
  echo "================================================================="
  echo " ANSSI — Agence nationale de la sécurité des systèmes d'information"
  echo "================================================================="
  local dir="$SCRIPT_DIR/anssi"
  mkdir -p "$dir"

  # All URLs from https://messervices.cyber.gouv.fr/api/guides (2025)
  local -a ANSSI=(
    # Crypto mechanisms v3.00 (FR)
    "https://messervices.cyber.gouv.fr/documents-guides/anssi-guide-mecanismes-crypto-3.00.pdf" "anssi-guide-mecanismes-crypto-3.00.pdf"
    # Algorithm selection guide v1.0 (FR)
    "https://messervices.cyber.gouv.fr/documents-guides/anssi-guide-selection_crypto-1.0.pdf" "anssi-guide-selection-crypto-1.0.pdf"
    # TLS security recommendations v1.1 (EN)
    "https://messervices.cyber.gouv.fr/documents-guides/security-recommendations-for-tls_v1.1.pdf" "anssi-guide-tls-en-v1.1.pdf"
    # TLS security recommendations v1.2 (FR)
    "https://messervices.cyber.gouv.fr/documents-guides/anssi-guide-recommandations_de_securite_relatives_a_tls-v1.2.pdf" "anssi-guide-tls-fr-v1.2.pdf"
    # IPsec EN
    "https://messervices.cyber.gouv.fr/documents-guides/NT_IPsec_EN.pdf" "anssi-guide-ipsec-en.pdf"
    # Rust programming rules EN v1.0
    "https://messervices.cyber.gouv.fr/documents-guides/anssi-guide-programming_rules_to_develop_secure_applications_with_rust-v1.0.pdf" "anssi-guide-rust-en-v1.0.pdf"
    # Rust programming rules FR v1.0
    "https://messervices.cyber.gouv.fr/documents-guides/anssi-guide-regles_de_programmation_pour_le_developpement_dapplications_securisees_en_rust-v1.0.pdf" "anssi-guide-rust-fr-v1.0.pdf"
    # PKI/IGC essentials FR v1.0
    "https://messervices.cyber.gouv.fr/documents-guides/anssi_essentiels_igc_1.0.pdf" "anssi-guide-igc-fr-v1.0.pdf"
    # PKI Back to Basics EN v1.0
    "https://messervices.cyber.gouv.fr/documents-guides/anssi_back%20to%20basics_pki_1.0.pdf" "anssi-guide-pki-en-v1.0.pdf"
    # PQC position paper EN (2022)
    "https://messervices.cyber.gouv.fr/documents-guides/EN_Position.pdf" "anssi-pqc-position-2022-en.pdf"
    # PQC follow-up EN (2023)
    "https://messervices.cyber.gouv.fr/documents-guides/follow_up_position_paper_on_post_quantum_cryptography.pdf" "anssi-pqc-followup-2023-en.pdf"
    # Post-Quantum TLS 1.3 transition (FR/EN, 2025)
    "https://messervices.cyber.gouv.fr/documents-guides/transition_post_quantique_tls_1_3.pdf" "anssi-pqc-tls-transition.pdf"
    # Post-Quantum IPsec transition (FR/EN, 2025)
    "https://messervices.cyber.gouv.fr/documents-guides/transition_post_quantique_ipsec.pdf" "anssi-pqc-ipsec-transition.pdf"
    # Docker security (FR)
    "https://messervices.cyber.gouv.fr/documents-guides/docker_fiche_technique.pdf" "anssi-guide-docker-v1.0.pdf"
    # Crypto agility EN
    "https://messervices.cyber.gouv.fr/documents-guides/ANSSI-views-on-crypto-agility.pdf" "anssi-views-crypto-agility.pdf"
  )

  local i=0
  while [[ $i -lt ${#ANSSI[@]} ]]; do
    local url="${ANSSI[$i]}"
    local name="${ANSSI[$((i + 1))]}"
    fetch_pdf "$url" "$dir/$name" || true
    i=$((i + 2))
  done
}

# ---------------------------------------------------------------------------
# Section: SEC/SECG
# ---------------------------------------------------------------------------
fetch_secg() {
  echo ""
  echo "================================================================="
  echo " SECG — Standards for Efficient Cryptography Group"
  echo "================================================================="
  local dir="$SCRIPT_DIR/secg"
  mkdir -p "$dir"

  # Note: SEC 3 (ECDH) is no longer publicly available (secg.org acquired by BlackBerry).
  local -a SECG=(
    # SEC 1: Elliptic Curve Cryptography (parameter formats, operations)
    "https://www.secg.org/sec1-v2.pdf" "sec1-v2.pdf"
    # SEC 2: Recommended Elliptic Curve Domain Parameters
    "https://www.secg.org/sec2-v2.pdf" "sec2-v2.pdf"
  )

  local i=0
  while [[ $i -lt ${#SECG[@]} ]]; do
    local url="${SECG[$i]}"
    local name="${SECG[$((i + 1))]}"
    fetch_pdf "$url" "$dir/$name" || true
    i=$((i + 2))
  done

  warn "SEC 3 (ECDH implementation guide) no longer publicly available — secg.org acquired by BlackBerry."
}

# ---------------------------------------------------------------------------
# Section: ANSI
# ---------------------------------------------------------------------------
fetch_ansi() {
  echo ""
  echo "================================================================="
  echo " ANSI X9 — American National Standards Institute"
  echo "================================================================="
  local dir="$SCRIPT_DIR/ansi"
  mkdir -p "$dir"

  # ANSI standards are not freely available — download publicly accessible drafts
  # or provide a reference index
  cat >"$dir/README.md" <<'EOF'
# ANSI X9 Standards

ANSI X9 standards are not freely available for download. They must be purchased
from ANSI (https://webstore.ansi.org/) or accessed through a standards subscription.

## Referenced ANSI Standards

| Standard | Title | Accessibility |
|----------|-------|--------------|
| ANSI X9.62-2005 | Public Key Cryptography for the Financial Services Industry: The Elliptic Curve Digital Signature Algorithm (ECDSA) | Purchase required |
| ANSI X9.63-2011 | Public Key Cryptography for the Financial Services Industry: Key Agreement and Key Transport Using Elliptic Curve Cryptography | Purchase required |
| ANSI X9.31-1998 | Digital Signatures Using Reversible Public Key Cryptography for the Financial Services Industry | Purchase required (deprecated) |
| ANSI X9.23-1995 | Financial Institution Encryption of Wholesale Financial Messages | Purchase required (withdrawn) |

## Alternative Free References

- ECDSA: See FIPS 186-5 (../nist/fips/NIST.FIPS.186-5.pdf)
- ECDH: See NIST SP 800-56A r3 (../nist/sp800/NIST.SP.800-56Ar3.pdf)
- SEC 1/2: See ../secg/ for SECG documents (free)
EOF
  ok "ANSI README created (standards not freely downloadable)"
}

# ---------------------------------------------------------------------------
# Section: OWASP
# ---------------------------------------------------------------------------
fetch_owasp() {
  echo ""
  echo "================================================================="
  echo " OWASP — Open Web Application Security Project"
  echo "================================================================="
  local dir="$SCRIPT_DIR/owasp"
  mkdir -p "$dir"

  local -a OWASP=(
    # Top 10 2021
    "https://owasp.org/Top10/A01_2021-Broken_Access_Control/" "Top10-2021-A01-Broken-Access-Control.html"
    "https://owasp.org/Top10/A02_2021-Cryptographic_Failures/" "Top10-2021-A02-Cryptographic-Failures.html"
    "https://owasp.org/Top10/A03_2021-Injection/" "Top10-2021-A03-Injection.html"
    "https://owasp.org/Top10/A04_2021-Insecure_Design/" "Top10-2021-A04-Insecure-Design.html"
    "https://owasp.org/Top10/A05_2021-Security_Misconfiguration/" "Top10-2021-A05-Security-Misconfiguration.html"
    "https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/" "Top10-2021-A06-Vulnerable-Components.html"
    "https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/" "Top10-2021-A07-Auth-Failures.html"
    "https://owasp.org/Top10/A08_2021-Software_and_Data_Integrity_Failures/" "Top10-2021-A08-Integrity-Failures.html"
    "https://owasp.org/Top10/A09_2021-Security_Logging_and_Monitoring_Failures/" "Top10-2021-A09-Logging-Failures.html"
    "https://owasp.org/Top10/A10_2021-Server-Side_Request_Forgery_(SSRF)/" "Top10-2021-A10-SSRF.html"
    # Cheat Sheets
    "https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html" "cheatsheet-cryptographic-storage.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html" "cheatsheet-key-management.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html" "cheatsheet-password-storage.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/TLS_Cheat_Sheet.html" "cheatsheet-tls.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html" "cheatsheet-authentication.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html" "cheatsheet-jwt.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html" "cheatsheet-tls2.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Injection_Prevention_Cheat_Sheet.html" "cheatsheet-injection-prevention.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html" "cheatsheet-sql-injection.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html" "cheatsheet-csrf.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html" "cheatsheet-input-validation.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html" "cheatsheet-logging.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html" "cheatsheet-secrets-management.html"
    "https://cheatsheetseries.owasp.org/cheatsheets/Access_Control_Cheat_Sheet.html" "cheatsheet-access-control.html"
  )

  local i=0
  while [[ $i -lt ${#OWASP[@]} ]]; do
    local url="${OWASP[$i]}"
    local name="${OWASP[$((i + 1))]}"
    fetch_html "$url" "$dir/$name" || true
    i=$((i + 2))
  done

  # CWE Top 25 and key CWE entries
  echo "  Fetching CWE entries…"
  local cwe_dir="$dir/cwe"
  mkdir -p "$cwe_dir"
  fetch_html "https://cwe.mitre.org/top25/archive/2024/2024_cwe_top25.html" "$cwe_dir/cwe-top25-2024.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/310.html" "$cwe_dir/cwe-310-cryptographic-issues.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/320.html" "$cwe_dir/cwe-320-key-management-errors.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/326.html" "$cwe_dir/cwe-326-inadequate-key-strength.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/327.html" "$cwe_dir/cwe-327-broken-algorithm.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/328.html" "$cwe_dir/cwe-328-reversible-one-way-hash.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/330.html" "$cwe_dir/cwe-330-insufficient-random-values.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/347.html" "$cwe_dir/cwe-347-improper-crypto-signature-verification.html" || true
  fetch_html "https://cwe.mitre.org/data/definitions/400.html" "$cwe_dir/cwe-400-resource-exhaustion.html" || true
}

# ---------------------------------------------------------------------------
# Section: IEEE
# ---------------------------------------------------------------------------
fetch_ieee() {
  echo ""
  echo "================================================================="
  echo " IEEE — Institute of Electrical and Electronics Engineers"
  echo "================================================================="
  local dir="$SCRIPT_DIR/ieee"
  mkdir -p "$dir"

  # IEEE standards are not freely available in full. We download the freely
  # accessible abstract/overview pages and create a reference index.
  cat >"$dir/README.md" <<'EOF'
# IEEE Standards Referenced in Cosmian KMS

IEEE standards require purchase or IEEE Xplore subscription.

## Referenced IEEE Standards

| Standard | Title | Free Resources |
|----------|-------|---------------|
| IEEE 1619-2007 | IEEE Standard for Cryptographic Protection of Data on Block-Oriented Storage Devices (XTS-AES) | See NIST SP 800-38E |
| IEEE P1363 | Standard Specifications for Public Key Cryptography | Drafts at grouper.ieee.org |
| IEEE P1363a | Standard Specifications for Public Key Cryptography Amendment 1: Additional Techniques | |

## Notes

- IEEE 1619 (XTS-AES): The XTS mode is defined by IEEE 1619-2007. The NIST description
  is in SP 800-38E (../nist/sp800/NIST.SP.800-38E.pdf).
- Purchase: https://standards.ieee.org/
EOF
  ok "IEEE README created (standards require IEEE Xplore subscription)"
}

# ---------------------------------------------------------------------------
# Section: ETSI
# ---------------------------------------------------------------------------
fetch_etsi() {
  echo ""
  echo "================================================================="
  echo " ETSI — European Telecommunications Standards Institute"
  echo "================================================================="
  local dir="$SCRIPT_DIR/etsi"
  mkdir -p "$dir"

  # ETSI freely provides PDFs via https://www.etsi.org/deliver/
  # URL format: /deliver/etsi_{type}/{range}/{docnum}/{version}_60/{type}_{docnum}v{vnum}p.pdf
  local -a ETSI=(
    # EN 319 102-1: AdES signature validation procedures
    "https://www.etsi.org/deliver/etsi_en/319100_319199/31910201/01.03.01_60/en_31910201v010301p.pdf" "ETSI-EN-319-102-1-AdES-validation.pdf"
    # EN 319 122-1: CAdES (CMS Advanced Electronic Signatures)
    "https://www.etsi.org/deliver/etsi_en/319100_319199/31912201/01.02.01_60/en_31912201v010201p.pdf" "ETSI-EN-319-122-1-CAdES.pdf"
    # EN 319 132-1: XAdES (XML Advanced Electronic Signatures)
    "https://www.etsi.org/deliver/etsi_en/319100_319199/31913201/01.02.01_60/en_31913201v010201p.pdf" "ETSI-EN-319-132-1-XAdES.pdf"
    # EN 319 142-1: PAdES (PDF Advanced Electronic Signatures)
    "https://www.etsi.org/deliver/etsi_en/319100_319199/31914201/01.02.01_60/en_31914201v010201p.pdf" "ETSI-EN-319-142-1-PAdES.pdf"
    # EN 319 401: General Policy Requirements for TSP
    "https://www.etsi.org/deliver/etsi_en/319400_319499/319401/03.01.01_60/en_319401v030101p.pdf" "ETSI-EN-319-401-TSP-policy.pdf"
    # EN 319 411-1: Policy Requirements for CAs issuing public key certs
    "https://www.etsi.org/deliver/etsi_en/319400_319499/31941101/01.03.01_60/en_31941101v010301p.pdf" "ETSI-EN-319-411-1-PKI-policy.pdf"
    # EN 319 421: Time-Stamp policy
    "https://www.etsi.org/deliver/etsi_en/319400_319499/319421/01.02.01_60/en_319421v010201p.pdf" "ETSI-EN-319-421-timestamp.pdf"
    # EN 319 521: Attribute certificate TSP
    "https://www.etsi.org/deliver/etsi_en/319500_319599/319521/01.01.01_60/en_319521v010101p.pdf" "ETSI-EN-319-521-attributes.pdf"
    # TS 119 312: Cryptographic suites for electronic signatures
    "https://www.etsi.org/deliver/etsi_ts/119300_119399/119312/01.05.01_60/ts_119312v010501p.pdf" "ETSI-TS-119-312-crypto-suites.pdf"
    # TS 103 523-1: Middlebox TLS
    "https://www.etsi.org/deliver/etsi_ts/103500_103599/10352301/01.02.01_60/ts_10352301v010201p.pdf" "ETSI-TS-103-523-middlebox-tls.pdf"
    # TR 103 626: Quantum-safe cryptography
    "https://www.etsi.org/deliver/etsi_tr/103600_103699/103626/01.01.01_60/tr_103626v010101p.pdf" "ETSI-TR-103-626-quantum-safe.pdf"
    # TS 103 744: Quantum-safe cryptographic algorithms
    "https://www.etsi.org/deliver/etsi_ts/103700_103799/103744/01.02.01_60/ts_103744v010201p.pdf" "ETSI-TS-103-744-QSC-algorithms.pdf"
    # TS 119 495: Sector-specific requirements (PSD2/Open Banking)
    "https://www.etsi.org/deliver/etsi_ts/119400_119499/119495/01.03.01_60/ts_119495v010301p.pdf" "ETSI-TS-119-495-eIDAS-banking.pdf"
  )

  local i=0
  while [[ $i -lt ${#ETSI[@]} ]]; do
    local url="${ETSI[$i]}"
    local name="${ETSI[$((i + 1))]}"
    fetch_pdf "$url" "$dir/$name" || true
    i=$((i + 2))
  done
}

# ---------------------------------------------------------------------------
# Section: IETF Drafts
# ---------------------------------------------------------------------------
fetch_ietf_drafts() {
  echo ""
  echo "================================================================="
  echo " IETF Drafts — Post-Quantum Cryptography working documents"
  echo "================================================================="
  local dir="$SCRIPT_DIR/ietf-drafts"
  mkdir -p "$dir"

  local -a DRAFTS=(
    # Hybrid TLS (X25519 + ML-KEM) — IETF TLS WG
    "https://www.ietf.org/archive/id/draft-ietf-tls-hybrid-design-10.txt" "draft-ietf-tls-hybrid-design.txt"
    # ML-KEM for TLS 1.3 — IETF TLS WG
    "https://www.ietf.org/archive/id/draft-ietf-tls-mlkem-01.txt" "draft-ietf-tls-mlkem.txt"
    # Composite public keys for X.509 — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ounsworth-pq-composite-keys-14.txt" "draft-composite-keys.txt"
    # ML-KEM (Kyber) in X.509 certificates — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ietf-lamps-kyber-certificates-06.txt" "draft-ml-kem-certificates.txt"
    # ML-DSA (Dilithium) in X.509 certificates — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ietf-lamps-dilithium-certificates-04.txt" "draft-ml-dsa-certificates.txt"
    # SLH-DSA (SPHINCS+) in X.509 certificates — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ietf-lamps-x509-shbs-05.txt" "draft-slh-dsa-certificates.txt"
    # KEM Recipient Info for CMS — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ietf-lamps-cms-kemri-09.txt" "draft-cms-kemri.txt"
    # ML-KEM in CMS — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ietf-lamps-cms-kyber-06.txt" "draft-cms-ml-kem.txt"
    # Composite signatures for PKIX — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ounsworth-pq-composite-sigs-13.txt" "draft-composite-sigs.txt"
    # Composite PQ KEM for CMS — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ietf-lamps-pq-composite-kem-05.txt" "draft-pq-composite-kem.txt"
    # PQT Hybrid terminology — IETF PQUIP WG
    "https://www.ietf.org/archive/id/draft-ietf-pquip-pqt-hybrid-terminology-04.txt" "draft-pqt-hybrid-terminology.txt"
    # HPKE for JOSE — IETF JOSE WG
    "https://www.ietf.org/archive/id/draft-ietf-jose-hpke-encrypt-07.txt" "draft-jose-hpke-encrypt.txt"
    # HPKE for COSE — IETF COSE WG
    "https://www.ietf.org/archive/id/draft-ietf-cose-hpke-07.txt" "draft-cose-hpke.txt"
    # ML-DSA in COSE — IETF COSE WG
    "https://www.ietf.org/archive/id/draft-ietf-cose-dilithium-02.txt" "draft-cose-ml-dsa.txt"
    # LAMPS PQ composite signatures — IETF LAMPS WG
    "https://www.ietf.org/archive/id/draft-ietf-lamps-pq-composite-sigs-03.txt" "draft-lamps-pq-composite-sigs.txt"
  )

  local i=0
  while [[ $i -lt ${#DRAFTS[@]} ]]; do
    local url="${DRAFTS[$i]}"
    local name="${DRAFTS[$((i + 1))]}"
    fetch_html "$url" "$dir/$name" || true
    i=$((i + 2))
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "================================================================="
  echo " Cosmian KMS — Standards Reference Library Fetcher"
  echo " Section: $SECTION"
  echo "================================================================="

  case "$SECTION" in
    rfc) fetch_rfcs ;;
    nist)
      fetch_nist_fips
      fetch_nist_sp800
      ;;
    bsi) fetch_bsi ;;
    anssi) fetch_anssi ;;
    secg) fetch_secg ;;
    ansi) fetch_ansi ;;
    ieee) fetch_ieee ;;
    etsi) fetch_etsi ;;
    owasp) fetch_owasp ;;
    drafts) fetch_ietf_drafts ;;
    all)
      fetch_rfcs
      fetch_nist_fips
      fetch_nist_sp800
      fetch_bsi
      fetch_anssi
      fetch_secg
      fetch_ansi
      fetch_ieee
      fetch_etsi
      fetch_owasp
      fetch_ietf_drafts
      ;;
    *)
      echo "Unknown section: $SECTION"
      echo "Usage: $0 [rfc|nist|bsi|anssi|secg|ansi|ieee|etsi|owasp|drafts|all]"
      exit 1
      ;;
  esac

  echo ""
  echo "================================================================="
  echo " Summary"
  echo "================================================================="
  echo "  RFC files:       $(find "$SCRIPT_DIR/rfc" -name "*.txt" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  NIST FIPS PDFs:  $(find "$SCRIPT_DIR/nist/fips" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  NIST SP PDFs:    $(find "$SCRIPT_DIR/nist/sp800" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  BSI PDFs:        $(find "$SCRIPT_DIR/bsi" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  ANSSI PDFs:      $(find "$SCRIPT_DIR/anssi" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  SECG PDFs:       $(find "$SCRIPT_DIR/secg" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  ETSI PDFs:       $(find "$SCRIPT_DIR/etsi" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  OWASP files:     $(find "$SCRIPT_DIR/owasp" -type f 2>/dev/null | wc -l | tr -d ' ')"
  echo "  IETF drafts:     $(find "$SCRIPT_DIR/ietf-drafts" -type f 2>/dev/null | wc -l | tr -d ' ')"
  total=$(find "$SCRIPT_DIR" -type f ! -name "*.sh" ! -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "  TOTAL files:     $total"
  echo "================================================================="
  ok "Done."
}

main
