-- +goose Up
CREATE TABLE invoice_lines (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_id  bigint NOT NULL REFERENCES invoices (id),
  description text NOT NULL,
  quantity    integer NOT NULL,
  unit_minor  bigint NOT NULL
);
-- +goose Down
DROP TABLE invoice_lines;
