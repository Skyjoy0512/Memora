export function isEmailLike(value: string): boolean {
  return value.includes("@");
}

export function isCompleteCode(value: string): boolean {
  return value.length === 6;
}
