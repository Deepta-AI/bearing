# Third-party notices

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This file sits
     at the repository root and ships with the product: it gives every
     component whose licence requires attribution (MIT, BSD, Apache-2.0, ISC
     and the like; the gate marks them) the credit in the form its licence
     demands. Its readers are customers and their legal teams.
     The table: one row per component in the delivered artefact (what is
     compiled or installed, not what the manifest lists), plus the language
     runtime linked in. The copyright lines come from the package's LICENSE,
     NOTICE and source headers; a missing one or a missing licence file is
     listed for the authors, never invented or borrowed from another row.
     Example: | express | 4.21.2 | MIT | Copyright (c) 2009-2014 TJ Holowaychuk | https://github.com/expressjs/express | -->

This product includes software developed by third parties. The
components below are distributed under their own licences, reproduced
or referenced as each licence requires. Prepared from <the built
artefact, lockfile or SBOM> on <YYYY-MM-DD>; regenerate it when the
dependencies change.

| Component | Version | Licence | Copyright | Source |
| --- | --- | --- | --- | --- |
| <name> | <version> | <SPDX id> | <copyright line from the package's LICENSE> | <repository or registry URL> |

## Licence texts

<!-- What: one subsection per distinct licence in the table, then one per
     Apache-2.0 component that ships a NOTICE file.
     Good: every licence in the table has its text here; nothing is
     summarised or linked where the licence asks for the text itself.
     Example: "### MIT", then the MIT text once, covering every MIT row. -->

One section per distinct licence, with the full text as the licence
requires. Apache-2.0 components also carry their NOTICE file contents
under their own heading below.

### <SPDX id>

<!-- What: the full text of this licence, verbatim, headed by its SPDX id.
     Good: copied from a component's LICENSE file or the SPDX list, not
     retyped; a licence with a copyright placeholder keeps the placeholder
     here, since each component's own line is in the table.
     Example: "### BSD-3-Clause" followed by the three-clause text. -->

<full licence text>

### NOTICE for <component> (Apache-2.0)

<!-- What: the contents of this component's NOTICE file, one subsection per
     Apache-2.0 component that has one.
     Good: copied whole from the package; Apache-2.0 requires the NOTICE
     contents to be carried, and the licence name alone does not satisfy it.
     Example: "### NOTICE for log4j-api (Apache-2.0)" then its NOTICE lines. -->

<contents of the component's NOTICE file>
