CREATE TABLE "idempotency_keys" (
	"account_id" text NOT NULL,
	"key" text NOT NULL,
	"status_code" integer NOT NULL,
	"body" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "idempotency_keys_account_key" ON "idempotency_keys" USING btree ("account_id","key");
