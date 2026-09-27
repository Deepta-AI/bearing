import { ValidationError } from './errors.ts';

/** Reads an optional integer query parameter within [min, max]; rejects anything else. */
export function intParam(
  raw: string | null,
  opts: { name: string; min: number; max: number; fallback: number },
): number {
  if (raw === null || raw === '') return opts.fallback;
  if (!/^-?\d+$/.test(raw)) throw new ValidationError(`${opts.name} must be an integer`);
  const n = Number(raw);
  if (n < opts.min || n > opts.max) {
    throw new ValidationError(`${opts.name} must be between ${opts.min} and ${opts.max}`);
  }
  return n;
}

/** Reads a path id: 1 to 64 characters of letters, digits, `_` and `-`. */
export function idParam(raw: string, name: string): string {
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(raw)) throw new ValidationError(`${name} is not a valid id`);
  return raw;
}
