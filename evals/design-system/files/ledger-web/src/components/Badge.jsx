const tones = {
  paid: "hsl(142 70% 35%)",
  due: "var(--color-text-muted)",
  overdue: "var(--color-danger)",
};

export function Badge({ tone, children }) {
  return (
    <span style={{ color: tones[tone], fontSize: 13, padding: "0 8px" }}>
      {children}
    </span>
  );
}
