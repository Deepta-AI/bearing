CREATE TABLE "payments" (
	"id" text PRIMARY KEY NOT NULL,
	"account_id" text NOT NULL,
	"amount_minor" bigint NOT NULL,
	"currency" text NOT NULL,
	"status" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE INDEX "payments_account_created" ON "payments" USING btree ("account_id","created_at");
