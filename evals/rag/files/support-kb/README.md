# support-kb

The in-app help widget for Ledgerleaf Payroll. A customer types a question
and today the widget runs `kbot.search.search()`, a substring match over the
help-centre articles, and shows the three article titles it finds. Support
wants real answers with links to the exact part of the article.

## Scale (production, September 2026)

- Help centre: about 2,300 articles (this repository carries a 15-article
  sample in `data/kb/`, exported from the help-centre CMS as markdown).
- Widget traffic: about 3,500 questions a day, peaking on payroll day (the
  last working day of the month).
- Articles change weekly; the CMS export runs nightly and overwrites files in
  place. Old articles are sometimes left in the export with a "Superseded"
  banner instead of being deleted. An article unpublished in the CMS is
  simply missing from the next export.

## Platform

- Production database: Postgres 16. The platform team has approved the
  `pgvector` extension for this service. There is no database in local
  development or CI; tests use in-memory stand-ins.
- Models are called through `kbot.llm.LLMClient`; embeddings through
  `kbot.embeddings.Embedder`. CI has no network and no API key, so tests use
  `FakeLLM` and `HashingEmbedder`, which are deterministic.

## Data from support

`data/support-questions.csv` holds questions real customers asked in chat,
collected by the support leads, with the article each lead would have sent
in reply (`none` when the help centre does not cover it).

## Commands

    make test      # unit tests (pytest via uv, offline)
