-- +goose Up
CREATE TABLE postings (
    id          bigserial PRIMARY KEY,
    transfer_id uuid        NOT NULL,
    account_id  text        NOT NULL REFERENCES accounts (id),
    amount      bigint      NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX postings_account_idx ON postings (account_id);

-- +goose Down
DROP TABLE postings;
