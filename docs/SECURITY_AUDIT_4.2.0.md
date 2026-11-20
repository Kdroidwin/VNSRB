# Online Security Audit — 4.2.0

Date: 2026-11-20
Scope: VNDB API calls, account synchronization, remote image loading, update metadata, and links supplied by VNDB records.

## Findings and fixes

| Severity | Finding | Change |
| --- | --- | --- |
| High | Authenticated API requests could follow redirects. A redirect could forward a credential-bearing request to a different host. | Dio requests now require HTTPS to an explicit host allowlist, port 443, and no URL user information. Redirects are disabled. Authentication requests also explicitly disable redirects. |
| Medium | Collection sync recursively paginated an untrusted response and trusted record fields before saving them. A malformed or unexpectedly large response could consume memory, overflow the call stack, or abort synchronization. | Pagination is iterative and capped at 50,000 records. Response envelope, IDs, labels, dates, notes, votes, and timestamps are validated before use. Empty continuation pages and duplicate IDs are rejected. Authentication tokens and IDs used in request paths are validated. Collection matching uses maps to avoid quadratic scans. |
| Medium | Remote image URLs could be loaded by the cache manager's default HTTP client, which follows redirects. VNDB data or an imported backup could therefore trigger requests to an unexpected host. | VNDB image URLs are validated against the HTTPS image CDN. The cache manager uses a dedicated client that rejects redirects, credentials, non-image responses, and responses larger than 32 MiB; requests and body streams have timeouts. All cached image widgets use this client. |
| Medium | VNDB external links were passed directly to the platform URL launcher, including arbitrary URI schemes. | Only bounded HTTP(S) URLs with a host and without user information are displayed and opened. |
| Low | Update metadata parsing assumed one response type and trusted dynamic fields. The update/release links also referenced the old repository name. | Metadata accepts only a small string or map payload with bounded version strings; repository links now target VNSRB. |

## Verification limits

This is a source-level audit, not a live penetration test. No credentials or live account operations were used. The allowlist and validation reduce the identified request-routing and malformed-response risks; they do not guarantee the security or availability of VNDB, GitHub, the operating system, or third-party Flutter packages.
