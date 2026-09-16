# Viten Mail — Architecture Documentation

## Project Overview

Viten Mail is a private, self-hosted email service for the domain **vitenhosting.com**, built from scratch to learn practical Linux administration, Postfix, Dovecot, PostgreSQL, FastAPI, React, DNS, security, and deployment.

The first version is private, with accounts created only by the administrator. The architecture is designed from day one to support a future public opening, as well as future expansion into **Viten Drive** and **Viten Photos**.

## Main Domains

| Domain | Purpose |
|---|---|
| `vitenhosting.com` | Primary domain |
| `mail.vitenhosting.com` | Webmail |
| `adminmail.vitenhosting.com` | Admin panel |

Example accounts: `username@vitenhosting.com`, `servicosuporte@vitenhosting.com`

## Service Type

Private initially, with the framework prepared to become a public service in the future.

## High-Level Architecture

\```
User Browser
     |
     v
   Nginx
     |
     +---------------------+
     |                     |
     v                     v
React Frontend       FastAPI Backend
                           |
                           v
                      PostgreSQL
                           |
             +-------------+-------------+
             |             |             |
             v             v             v
          Postfix       Dovecot        Redis
             |             |
             v             v
        SMTP Email    Maildir / IMAP
\```

**Additional services:**
- **Rspamd** — spam filtering, DKIM and reputation analysis
- **ClamAV** — antivirus scanning for attachments
- **Cockpit** — server monitoring and administration
- **Uptime Kuma** — service uptime monitoring

## Core Components

| Component | Function |
|---|---|
| Postfix | SMTP: sending, receiving, queueing, relay and local delivery |
| Dovecot | IMAP, mailbox access, folders, flags, Maildir and mailbox authentication |
| PostgreSQL | Users, domains, aliases, sessions, 2FA, quotas, preferences, contacts and audit logs |
| FastAPI | Webmail/admin API, authentication, IMAP, SMTP, preferences and admin operations |
| React | Webmail and admin panel interface |
| Nginx | Reverse proxy, HTTPS, upload limits, security headers and routing |
| Redis | Cache, rate limiting, temporary state and fast task support |
| Rspamd | Antispam, scoring, reputation and DKIM |
| ClamAV | Attachment and file threat scanning |

## Email Sending Strategy

SMTP is the protocol used to send email. Postfix is the SMTP component of the project.

| Mode | Description |
|---|---|
| SMTP Relay | Postfix delivers messages to a specialized provider, which forwards them to Gmail, Outlook, etc. |
| Direct Delivery | Postfix delivers directly to the recipient's MX server |
| Hybrid (chosen) | Starts with relay, keeps the architecture ready for direct sending or mixed rules |

The transition from relay to direct delivery is technically simple at the application level, since the frontend and backend always send to the local Postfix instance. The real difficulty lies in DNS, PTR/reverse DNS, port 25 availability, IP reputation and deliverability.

**Send flow:**
\```
User
  -> React frontend
  -> FastAPI backend
  -> Postfix SMTP
  -> SMTP relay (initially)
  -> external recipient
\```

## Email Receiving Strategy

External reception is required from the first version.

**Direct reception:** other servers connect directly to the server on port 25, using the domain's MX record. Most autonomous option, but requires a real public IP, no CGNAT, port forwarding, correct firewall rules, continuous availability and proper DNS configuration.

**Reception via provider:** a provider receives the email first and forwards it to the server via authenticated SMTP or webhook/API. Useful when port 25 is blocked, CGNAT is present, or the residential connection isn't ideal.

**Chosen strategy:** direct reception is preferred, with the architecture prepared to fall back to a provider if needed.

**Receive flow:**
\```
External sender
  -> DNS MX
  -> mail.vitenhosting.com
  -> Postfix
  -> Rspamd / ClamAV
  -> Dovecot / Maildir
  -> User inbox
\```

## Message Storage

Messages are stored in Maildir format:

\```
/data/mail/vitenhosting.com/andre/Maildir/
├── cur/
├── new/
└── tmp/
\```

Each email is stored as a complete file containing headers, plain-text body, HTML body, MIME structure and attachments. PostgreSQL does **not** store the raw full content of emails.

## Attachments

| Rule | Value |
|---|---|
| Max message size | 25 MB |
| Max size per attachment | 16 MB |
| Max number of attachments | 10 |
| ZIP files | Allowed if within limits and passing security scanning |

**Model:** hybrid — original attachments stay inside the MIME message, while previews, thumbnails, antivirus results and metadata live in a separate cache.

**Object storage:** not used for primary email storage in the first version, but suitable for Viten Drive, Viten Photos and future caches (e.g. S3, Cloudflare R2, MinIO).

## User Accounts

- Primary email address is immutable, though each account has an internal unique ID.
- Users can change name, password, alternate email, preferences, signature and theme.
- Quota is modeled from the start, even if enforcement is rolled out progressively.

## Account Lifecycle

Deleted accounts enter a `pending_deletion` state and remain recoverable for 30 days before permanent removal.

## Authentication

- Login uses the full email address.
- Sessions use secure cookies: `HttpOnly`, `Secure`, `SameSite`, with expiration and revocation support.
- Alternate email address for account recovery.
- Recovery codes for 2FA loss.

## Two-Factor Authentication

2FA is implemented from the first version: **mandatory for administrators**, **configurable for regular users**.

## Mail Folders

- Inbox
- Sent
- Drafts
- Spam
- Trash
- Archive
- Favorites — implemented as a virtual view based on an IMAP flag

## Webmail Features

**First version scope:**
- Login and 2FA
- Inbox, read, send, reply, reply-all, forward
- Attachments, inline images, drag-and-drop
- Drafts, delete, archive, favorites, read/unread flags
- Search, contacts, signature, custom folders, settings, account recovery

## Message Editor

Composer supports attachments (drag-and-drop), inline images, and standard formatting needed for replying/forwarding within the webmail interface.

## Layout

**Desktop (Gmail-style):**
\```
Top:    logo, search, settings, account
Left:   Compose, Inbox, Favorites, Sent, Drafts, Spam, Trash, Archive, custom folders
Center: message list
Right:  reading pane or full message page
\```

**Mobile:**
Simplified interface — message list, message opens as a separate page, collapsible side menu, simplified search, floating compose button.

## Visual Identity

- Name: **Viten Mail**
- Tab title format: `(n) Viten Hosting Mail`
- Themes: Light, Dark, and System (follows OS setting)

## Admin Panel

Hosted separately at `adminmail.vitenhosting.com`.

**Capabilities:**
- Create, suspend, restore and delete accounts
- Manage aliases and domains
- View quotas and storage usage
- View SMTP queue and logs
- View failed login attempts
- Manage 2FA and backups
- View service status

## Quotas

| Service | Quota |
|---|---|
| Email | Separate quota — initial suggestion: 5 GB per user |
| Drive | Separate quota (future) |
| Photos | Separate quota (future) |

## Backups

\```
/data/backups/viten-mail/
├── postgres/
├── maildir/
├── configs/
├── manifests/
└── secrets-encrypted/
\```

Initially stored on a separate area of the 1 TB disk. This protects against human error and some localized corruption, but does **not** replace an off-disk or off-site backup.

## Monitoring

- **Cockpit** — server administration
- **Uptime Kuma** — service availability
- **Logs** — systemd, Postfix, Dovecot, Rspamd
- Monitoring covers disk usage, SMTP queue, certificates, failed logins and backup status

## Security

- Argon2id for password hashing
- Rate limiting and lockout after failed attempts
- CSRF protection
- Real MIME validation for attachments
- ClamAV attachment scanning
- Rspamd for spam, DKIM and reputation
- Open relay prevention
- Audit logging

## Repository Structure

\```
viten-mail/
├── backend/
│   ├── app/
│   └── tests/
├── frontend/
├── database/
│   ├── migrations/
│   └── seeds/
├── configs/
│   ├── postfix/
│   ├── dovecot/
│   ├── rspamd/
│   ├── clamav/
│   └── nginx/
├── scripts/
├── docs/
└── tests/
\```

**Branch strategy:**

| Branch | Purpose |
|---|---|
| `main` | Stable release |
| `develop` | Development integration |
| `feature/*` | New features |
| `fix/*` | Bug fixes |
| `docs/*` | Documentation |

## Development Phases

| Phase | Goal |
|---|---|
| 1 — Foundation | Repo structure, documentation, PostgreSQL, data model, users, sessions, 2FA, audit logs |
| 2 — Internal Email | Postfix, Dovecot, Maildir, virtual accounts, local-to-local delivery |
| 3 — Webmail | FastAPI, React, login, inbox, send, read, attachments, favorites, contacts |
| 4 — Internet | SMTP relay, external reception, MX, SPF, DKIM, DMARC, TLS |
| 5 — Security | Rspamd, ClamAV, rate limiting, password policy, audit, backups, open relay tests |
| 6 — Administration | Admin panel, quotas, logs, SMTP queue, account states, recovery |
| 7 — Expansion | Viten Drive, Viten Photos, mobile apps, tokens, object storage, multi-domain support |
