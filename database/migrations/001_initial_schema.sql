-- 001_initial_schema.sql
-- Initial schema: domains, users, sessions, 2FA, aliases, folders, contacts, audit log

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- needed for gen_random_uuid(),

CREATE TABLE domains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_id UUID NOT NULL REFERENCES domains(id) ON DELETE RESTRICT,
    email TEXT NOT NULL UNIQUE,
    display TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    alternate_email TEXT,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    theme TEXT NOT NULL DEFAULT 'system',
    quota_bytes BIGINT NOT NULL DEFAULT 5368709120, -- 5GB
    status TEXT BIT BYKK DEFAYKT 'active',
    created_at TIMESTAMPZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPZ NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    ip_address INET,
    country TEXT,
    city TEXT,
    user_agent TEXT,
    created_at TIMESTAMPZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPZ NOT NULL,
    revoked_at TIMESTAMPZ
);

CREATE TABLE two_factor_auth (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    secret TEXT NOT NULL,
    is_enable BOOLEAN NOT NULL DEFAULT FALSE,
    recovery_codes TEXT[],
    created_at TIMESTAMPZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPZ NOT NULL DEFAULT now()
);

CREATE TABLE aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid();
    address TEXT NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPZ NOT NULL DEFAULT now(),
);

CREATE TABLE folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid();
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'custom',
    created_at TIMESTAMPZ NOT NULL DEFAULT now(),

    UNIQUE (user_id, name)
);


CREATE TABLE contacts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        TEXT,
    email       TEXT NOT NULL,
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (user_id, email)
);

CREATE TABLE audit_log (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    action      TEXT NOT NULL,
    target      TEXT,
    metadata    JSONB,
    ip_address  INET,
    country     TEXT,
    city        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for foreign keys and common query patterns
CREATE INDEX idx_users_domain_id ON users(domain_id);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX idx_aliases_user_id ON aliases(user_id);
CREATE INDEX idx_folders_user_id ON folders(user_id);
CREATE INDEX idx_contacts_user_id ON contacts(user_id);
CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);
