import { db, FieldValue } from '../config/firebase';
import { AppError } from '../middleware/errorHandler';
import { sanitizeCPF, sanitizePhoneNumber } from '../utils/validation';

interface InitializeUserProfileParams {
  uid: string;
  nomeCompleto: string;
  email: string;
  cpf: string;
  telefone: string;
}

const CPF_ALREADY_REGISTERED = 'CPF já cadastrado em outra conta';

export async function initializeUserProfile({
  uid,
  nomeCompleto,
  email,
  cpf,
  telefone,
}: InitializeUserProfileParams): Promise<void> {
  const firebaseDb = db();
  const sanitizedCPF = sanitizeCPF(cpf);
  const sanitizedPhone = sanitizePhoneNumber(telefone);
  const userRef = firebaseDb.collection('users').doc(uid);
  const walletRef = firebaseDb.collection('wallets').doc(uid);
  const cpfRegistrationRef = firebaseDb.collection('cpfRegistrations').doc(sanitizedCPF);
  const matchingUsersQuery = firebaseDb.collection('users').where('cpf', '==', sanitizedCPF);

  await firebaseDb.runTransaction(async (transaction) => {
    const [userDoc, walletDoc, cpfRegistrationDoc, matchingUsersSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(walletRef),
      transaction.get(cpfRegistrationRef),
      transaction.get(matchingUsersQuery),
    ]);
    const registeredUserId = cpfRegistrationDoc.get('userId');
    const cpfBelongsToAnotherProfile = matchingUsersSnapshot.docs.some(
      (document) => document.id !== uid
    );

    if (
      cpfBelongsToAnotherProfile ||
      (typeof registeredUserId === 'string' && registeredUserId !== uid)
    ) {
      throw new AppError(409, CPF_ALREADY_REGISTERED);
    }

    const previousCPF = sanitizeCPF(userDoc.get('cpf') ?? '');
    const previousCPFRegistrationRef =
      previousCPF && previousCPF !== sanitizedCPF
        ? firebaseDb.collection('cpfRegistrations').doc(previousCPF)
        : null;
    const previousCPFRegistrationDoc = previousCPFRegistrationRef
      ? await transaction.get(previousCPFRegistrationRef)
      : null;
    const now = FieldValue.serverTimestamp();

    transaction.set(
      cpfRegistrationRef,
      {
        userId: uid,
        createdAt: cpfRegistrationDoc.get('createdAt') ?? now,
        updatedAt: now,
      },
      { merge: true }
    );

    if (previousCPFRegistrationRef && previousCPFRegistrationDoc?.get('userId') === uid) {
      transaction.delete(previousCPFRegistrationRef);
    }

    transaction.set(
      userRef,
      {
        uid,
        nomeCompleto,
        email,
        cpf: sanitizedCPF,
        telefone: sanitizedPhone,
        mfaHabilitado: false,
        mfaSecret: null,
        createdAt: userDoc.get('createdAt') ?? now,
        updatedAt: now,
      },
      { merge: true }
    );

    if (!walletDoc.exists) {
      transaction.set(walletRef, {
        userId: uid,
        saldoReais: 0.0,
        updatedAt: now,
      });
    }
  });
}

export async function deleteInitializedUserProfile(uid: string, cpf: string): Promise<void> {
  const firebaseDb = db();
  const cpfRegistrationRef = firebaseDb.collection('cpfRegistrations').doc(sanitizeCPF(cpf));

  await firebaseDb.runTransaction(async (transaction) => {
    const cpfRegistrationDoc = await transaction.get(cpfRegistrationRef);

    transaction.delete(firebaseDb.collection('users').doc(uid));
    transaction.delete(firebaseDb.collection('wallets').doc(uid));

    if (cpfRegistrationDoc.get('userId') === uid) {
      transaction.delete(cpfRegistrationRef);
    }
  });
}
