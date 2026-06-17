# ANSI/INCITS 359-2004 — Role Based Access Control

## Standard

**ANSI/INCITS 359-2004**, *American National Standard for Information Technology — Role Based
Access Control*, adopted February 11, 2004 by the American National Standards Institute /
International Committee for Information Technology Standards (ANSI/INCITS).

Revised as **INCITS 359-2012** in 2012.

- NIST CSRC project page (archived): <https://csrc.nist.gov/projects/role-based-access-control>
- Purchase INCITS 359-2012: <https://standards.incits.org/apps/group_public/project/details.php?project_id=1658>

> **Note**: The normative standard (ANSI/INCITS 359-2004 and its 2012 revision) is a paid
> document and cannot be distributed freely. The files in this folder are the freely available
> foundational research papers on which the standard is based, all published by the NIST
> Cybersecurity Resource Center (CSRC).

---

## Files in this folder

| File | Description |
|------|-------------|
| `ferraiolo-kuhn-92-rbac-original.pdf` | Ferraiolo & Kuhn (1992) — *Role-Based Access Controls* — the original formal RBAC model, 15th National Computer Security Conference. |
| `sandhu96-rbac-models.pdf` | Sandhu, Coyne, Feinstein, Youman (1996) — *Role-Based Access Control Models* — IEEE Computer 29(2); preprint hosted by NIST CSRC. Proposed the Core/Hierarchical/Constrained RBAC framework that ANSI/INCITS 359 formalises. |
| `sandhu-ferraiolo-kuhn-00-nist-model-unified.pdf` | Sandhu, Ferraiolo, Kuhn (2000) — *The NIST Model for Role-Based Access Control: Towards a Unified Standard* — Proceedings, 5th ACM Workshop on RBAC. First public draft of the NIST RBAC model that became the basis for the 2004 standard. |
| `ferraiolo-kuhn-sandhu-07-rbac-update.pdf` | Ferraiolo, Kuhn, Sandhu (2007) — RBAC standard update discussion hosted by NIST CSRC. |
| `nist-csrc-rbac-project-page.html` | Archived NIST CSRC RBAC project page (retrieved 2026-06-17). |

---

## Relevance to Cosmian KMS

The Cosmian KMS four-role model (Operator, CryptoOfficer, Administrator, Auditor) is
designed within the ANSI/INCITS 359 framework:

| ANSI/INCITS 359 concept | Cosmian KMS implementation |
|---|---|
| §4.2 Core RBAC | Users assigned exactly one role per request; each role has a well-defined permission set |
| §4.3 Hierarchical RBAC | Administrator supersedes CryptoOfficer and Operator; CryptoOfficer manages lifecycle; Operator handles crypto use |
| §4.4 Constrained RBAC — Static Separation of Duty | Auditor role is mutually exclusive with all other roles; validated at server startup |
