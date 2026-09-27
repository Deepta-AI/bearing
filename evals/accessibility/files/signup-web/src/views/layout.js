export function layout({ title, body, scripts = [] }) {
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<link rel="stylesheet" href="/public/styles.css">
</head>
<body>
<header class="top"><a href="/" class="brand"><img src="/public/logo.svg" alt="Tallyfield"></a></header>
<main>
${body}
</main>
${scripts.map((s) => `<script src="${s}" defer></script>`).join("\n")}
</body>
</html>`;
}
