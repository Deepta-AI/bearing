CREATE TABLE partners (
    id                text PRIMARY KEY,
    name              text NOT NULL,
    webhook_url       text,
    webhook_secret_env text,
    active            boolean NOT NULL DEFAULT true
);
