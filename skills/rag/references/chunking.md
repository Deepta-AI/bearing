# Chunking

A chunk is the unit of retrieval and the unit of citation. It must be
readable on its own and small enough that five of them fit the answer
budget. Sizes are in tokens of the embedding model, not characters.

## Size by document type

| Document type | Split on | Size | Overlap | Notes |
| --- | --- | --- | --- | --- |
| Prose (articles, policies) | paragraph, then sentence | 300 to 500 | 50 | prepend `title > section` |
| Manuals, contracts, legal | heading hierarchy | 400 to 800 | 0 | never split a numbered clause; hierarchical parents at the section |
| Markdown, docs sites | headings, then paragraphs | 300 to 600 | 40 | keep code fences whole |
| Source code | function or class boundary (tree-sitter) | 200 to 600 | 0 | prepend file path and symbol name; skip generated files |
| Tables, CSV | rows, with the header repeated | 20 to 50 rows | 0 | one chunk per logical group; the caption chunk holds title, caption and header, never the rows |
| PDF with layout | page, then blocks | 400 to 600 | 50 | store page number; OCR quality decides everything |
| Chat and tickets | thread, then message groups | 300 to 500 | 0 | keep the question with its answer |
| Slides | one slide | whole slide | 0 | caption images with `claude-sonnet-5` |
| Images and diagrams | one image | caption | 0 | chunk text is the caption plus any extracted labels |

## Rules

1. Structure first. Split on the document's own structure (headings,
   clauses, functions) before falling back to size. A fixed-size
   splitter over structured text is the most common cause of recall
   below 0.8.
2. Context prefix. Every chunk's embedded text starts with the document
   title and the section path. The stored text keeps the raw span so
   citations quote what is on the page.
3. Overlap only for prose. Overlap on structured text duplicates
   clauses and doubles the same hit.
4. Never split a sentence, a code fence, a table row, or a list item.
5. Metadata on every chunk: `document_id`, `version`, `ord`, `title`,
   `section`, `page`, `tenant_id`, `updated_at`, `language`, `kind`.
   Filters run on metadata inside the SQL query.
6. Small-to-big when sections are long: embed child chunks of 200 to
   300 tokens, return the parent (section) at answer time. The
   `chunks.parent_id` column carries it.
7. Deduplicate by `content_hash` across documents. Boilerplate (footers,
   nav, legal notices) appears in every document and wins every search.
8. Log the distribution: chunks per document, tokens per chunk (p50,
   p95), chunks over the size cap. A p95 past the embedding model's
   input limit means silent truncation.

## Checks the ingestion prints

```
chunking: <D> documents, <C> chunks, p50 <n> tokens, p95 <n> tokens,
<X> over cap (truncated), <Y> duplicates dropped
```

Zero documents or zero chunks is a failure, not a clean run.
