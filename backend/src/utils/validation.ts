export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export function isValidCPF(cpf: string): boolean {
  const cleanCpf = cpf.replace(/\D/g, '');

  if (cleanCpf.length !== 11) return false;
  if (/^(\d)\1{10}$/.test(cleanCpf)) return false;

  const firstVerifier = calculateCPFVerifier(cleanCpf.substring(0, 9));
  const secondVerifier = calculateCPFVerifier(cleanCpf.substring(0, 10));

  return (
    firstVerifier === parseInt(cleanCpf[9]) &&
    secondVerifier === parseInt(cleanCpf[10])
  );
}

function calculateCPFVerifier(base: string): number {
  let sum = 0;
  let multiplier = base.length + 1;

  for (let i = 0; i < base.length; i++) {
    sum += parseInt(base[i]) * multiplier;
    multiplier--;
  }

  const remainder = sum % 11;
  return remainder < 2 ? 0 : 11 - remainder;
}

export function isValidPhoneNumber(phone: string): boolean {
  const cleanPhone = phone.replace(/\D/g, '');
  return cleanPhone.length >= 10 && cleanPhone.length <= 11;
}

export function sanitizeCPF(cpf: string): string {
  return cpf.replace(/\D/g, '');
}

export function sanitizePhoneNumber(phone: string): string {
  return phone.replace(/\D/g, '');
}
