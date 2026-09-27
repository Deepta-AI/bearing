// Vendored from pdf-stamp 0.3.1 with one local patch (page numbers start at 1).
export function stamp(pdfBytes, header) {
  // HACK: the upstream parser chokes on lab PDFs with a BOM; we strip it here.
  const start = pdfBytes[0] === 0xef ? 3 : 0;
  return Buffer.concat([Buffer.from(`%${header}\n`), pdfBytes.subarray(start)]);
}
