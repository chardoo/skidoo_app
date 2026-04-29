import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── Data models ────────────────────────────────────────────────────────────────

/// One-time prekey entry with integer keyId matching the server spec.
class OtpkEntry {
  final int keyId;
  final String publicKey; // base64url

  const OtpkEntry({required this.keyId, required this.publicKey});

  Map<String, dynamic> toJson() => {'keyId': keyId, 'publicKey': publicKey};
}

/// Bundle published to POST /chat/keys/bundle.
/// Field names are camelCase to match the server spec.
class PublishableKeyBundle {
  final String identityKey;           // base64url X25519 IK public key
  final int registrationId;
  final int signedPreKeyId;
  final String signedPreKey;          // base64url X25519 SPK public key
  final String signedPreKeySignature; // base64url HMAC-SHA256 of SPK pub
  final List<OtpkEntry> oneTimePreKeys;

  const PublishableKeyBundle({
    required this.identityKey,
    required this.registrationId,
    required this.signedPreKeyId,
    required this.signedPreKey,
    required this.signedPreKeySignature,
    required this.oneTimePreKeys,
  });

  Map<String, dynamic> toJson() => {
        'identityKey': identityKey,
        'registrationId': registrationId,
        'signedPreKeyId': signedPreKeyId,
        'signedPreKey': signedPreKey,
        'signedPreKeySignature': signedPreKeySignature,
        'oneTimePreKeys': oneTimePreKeys.map((e) => e.toJson()).toList(),
      };
}

/// Bundle returned by GET /chat/keys/{userId}/bundle.
/// Server response shape:
/// {
///   "identityKey": "...",
///   "registrationId": 123,
///   "signedPreKey": { "keyId": 1, "publicKey": "...", "signature": "..." },
///   "oneTimePreKey": { "keyId": 5, "publicKey": "..." }  // may be null
/// }
class RecipientKeyBundle {
  final String identityKey;
  final int signedPreKeyId;
  final String signedPreKey;
  final String signedPreKeySignature;
  final int? oneTimePreKeyId;
  final String? oneTimePreKey;
  final int? registrationId;

  const RecipientKeyBundle({
    required this.identityKey,
    required this.signedPreKeyId,
    required this.signedPreKey,
    required this.signedPreKeySignature,
    this.oneTimePreKeyId,
    this.oneTimePreKey,
    this.registrationId,
  });

  factory RecipientKeyBundle.fromJson(Map<String, dynamic> json) {
    final spk = json['signedPreKey'];
    if (spk == null || spk is! Map<String, dynamic>) {
      throw Exception('RecipientKeyBundle: missing or invalid signedPreKey');
    }
    final otpk = json['oneTimePreKey'] is Map<String, dynamic>
        ? json['oneTimePreKey'] as Map<String, dynamic>
        : null;
    return RecipientKeyBundle(
      identityKey: json['identityKey'] as String,
      signedPreKeyId: (spk['keyId'] as num).toInt(),
      signedPreKey: spk['publicKey'] as String,
      signedPreKeySignature: spk['signature'] as String,
      oneTimePreKeyId: (otpk?['keyId'] as num?)?.toInt(),
      oneTimePreKey: otpk?['publicKey'] as String?,
      registrationId: (json['registrationId'] as num?)?.toInt(),
    );
  }
}

/// Returned by [E2eeService.createSendingSession].
class SendingSession {
  final Uint8List sessionKey;
  final String ephemeralPublicKey; // base64url — send this in the first message
  final int? otpkId;               // OPK consumed (null if none) — send this too

  const SendingSession({
    required this.sessionKey,
    required this.ephemeralPublicKey,
    this.otpkId,
  });
}

/// Output of [E2eeService.encrypt].
class EncryptedPayload {
  final String ciphertext; // base64url — AES-GCM ciphertext + 16-byte MAC
  final String iv;         // base64url — 12-byte nonce

  const EncryptedPayload({required this.ciphertext, required this.iv});
}

// ── Service ────────────────────────────────────────────────────────────────────

/// X3DH key exchange + AES-256-GCM message encryption.
///
/// Key storage layout in FlutterSecureStorage:
///   e2ee.ik.priv              — X25519 identity key private (32 bytes, base64url)
///   e2ee.ik.pub               — X25519 identity key public  (32 bytes, base64url)
///   e2ee.spk.priv             — X25519 signed prekey private (current)
///   e2ee.spk.pub              — X25519 signed prekey public  (current)
///   e2ee.spk.sig              — HMAC-SHA256 signature of SPK pub
///   e2ee.spk.prev.priv        — previous SPK private (kept for one rotation window)
///   e2ee.spk.prev.id          — previous SPK ID
///   e2ee.spk_created_at       — ISO-8601 timestamp of current SPK creation
///   e2ee.reg_id               — registration ID (integer string)
///   e2ee.spk_id               — signed prekey ID (integer string)
///   e2ee.otpk.<id>.priv       — one-time prekey private (deleted after use)
///   e2ee.session.<roomId>     — AES-256 session key for a room (base64url)
///   e2ee.ik_peer.<userId>     — cached peer identity key (base64url)
///   e2ee.cached_bundle.<uid>  — {ik, spkId} for Phase 6 invalidation
class E2eeService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kIkPriv      = 'e2ee.ik.priv';
  static const _kIkPub       = 'e2ee.ik.pub';
  static const _kSpkPriv     = 'e2ee.spk.priv';
  static const _kSpkPub      = 'e2ee.spk.pub';
  static const _kSpkSig      = 'e2ee.spk.sig';
  static const _kRegId       = 'e2ee.reg_id';
  static const _kSpkId       = 'e2ee.spk_id';
  static const _kSpkCreatedAt = 'e2ee.spk_created_at';
  static const _kSpkPrevPriv  = 'e2ee.spk.prev.priv';
  static const _kSpkPrevId    = 'e2ee.spk.prev.id';

  static const int _initialOtpkCount = 100;
  static const Duration _spkRotationPeriod = Duration(days: 7);

  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();
  final _hmac   = Hmac.sha256();
  final _hkdf   = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// True when identity key material already exists in secure storage.
  Future<bool> hasKeys() async {
    final v = await _storage.read(key: _kIkPriv);
    return v != null && v.isNotEmpty;
  }

  /// Generates IK, SPK, registrationId, signedPreKeyId, and [_initialOtpkCount] OPKs.
  /// Stores all private keys in secure storage.
  /// Returns the bundle to publish to the server.
  ///
  /// Call this only when [hasKeys()] returns false — it overwrites existing keys.
  Future<PublishableKeyBundle> generateKeys() async {
    final rng = Random.secure();

    // Identity key (X25519)
    final ikPair = await _x25519.newKeyPair();
    final ikPub  = await ikPair.extractPublicKey();
    final ikPriv = await ikPair.extractPrivateKeyBytes();

    // Signed prekey (X25519)
    final spkPair = await _x25519.newKeyPair();
    final spkPub  = await spkPair.extractPublicKey();
    final spkPriv = await spkPair.extractPrivateKeyBytes();

    // HMAC-SHA256 signature of SPK public key bytes (using IK private key as HMAC key)
    final spkSig = await _signSpk(
      ikPrivBytes: Uint8List.fromList(ikPriv),
      spkPubBytes: spkPub.bytes,
    );

    final registrationId = rng.nextInt(0x7FFFFFFF);
    final spkId          = rng.nextInt(0x7FFFFFFF);

    await Future.wait([
      _storage.write(key: _kIkPriv,      value: _b64e(ikPriv)),
      _storage.write(key: _kIkPub,       value: _b64e(ikPub.bytes)),
      _storage.write(key: _kSpkPriv,     value: _b64e(spkPriv)),
      _storage.write(key: _kSpkPub,      value: _b64e(spkPub.bytes)),
      _storage.write(key: _kSpkSig,      value: _b64e(spkSig)),
      _storage.write(key: _kRegId,       value: registrationId.toString()),
      _storage.write(key: _kSpkId,       value: spkId.toString()),
      _storage.write(key: _kSpkCreatedAt, value: DateTime.now().toIso8601String()),
    ]);

    final otpks = await _generateOtpkEntries(_initialOtpkCount);

    return PublishableKeyBundle(
      identityKey: _b64e(ikPub.bytes),
      registrationId: registrationId,
      signedPreKeyId: spkId,
      signedPreKey: _b64e(spkPub.bytes),
      signedPreKeySignature: _b64e(spkSig),
      oneTimePreKeys: otpks,
    );
  }

  /// Generates [count] fresh OPKs for a top-up call.
  Future<List<OtpkEntry>> generateOtpks(int count) =>
      _generateOtpkEntries(count);

  /// Returns the publishable bundle for the current stored keys with an empty
  /// [oneTimePreKeys] list (OTPKs are managed separately via [generateOtpks]).
  /// Returns null if no key material exists yet.
  Future<PublishableKeyBundle?> currentBundle() async {
    final ikPub  = await _storage.read(key: _kIkPub);
    final spkPub = await _storage.read(key: _kSpkPub);
    final spkSig = await _storage.read(key: _kSpkSig);
    final regId  = await _storage.read(key: _kRegId);
    final spkId  = await _storage.read(key: _kSpkId);
    if (ikPub == null || spkPub == null || spkSig == null ||
        regId == null || spkId == null) {
      return null;
    }
    return PublishableKeyBundle(
      identityKey: ikPub,
      registrationId: int.parse(regId),
      signedPreKeyId: int.parse(spkId),
      signedPreKey: spkPub,
      signedPreKeySignature: spkSig,
      oneTimePreKeys: [],
    );
  }

  // ── SPK rotation ────────────────────────────────────────────────────────────

  /// Returns true when the current SPK is older than [_spkRotationPeriod].
  /// Initialises the creation timestamp to now (without rotating) if it is
  /// missing — this handles devices that upgraded before rotation was added.
  Future<bool> needsSPKRotation() async {
    var v = await _storage.read(key: _kSpkCreatedAt);
    if (v == null) {
      if (await hasKeys()) {
        // First run after upgrade: stamp now so rotation triggers in 7 days.
        await _storage.write(
            key: _kSpkCreatedAt, value: DateTime.now().toIso8601String());
      }
      return false;
    }
    return DateTime.now().difference(DateTime.parse(v)) >= _spkRotationPeriod;
  }

  /// Generates a new SPK, archives the old one as "prev" (kept for one
  /// rotation window to decrypt in-flight first messages), and returns the
  /// new [PublishableKeyBundle] (empty OTPKs — top up separately).
  Future<PublishableKeyBundle> rotateSPK() async {
    // Archive current SPK so in-flight X3DH messages can still be decrypted.
    final curPriv = await _storage.read(key: _kSpkPriv);
    final curId   = await _storage.read(key: _kSpkId);
    if (curPriv != null && curId != null) {
      await Future.wait([
        _storage.write(key: _kSpkPrevPriv, value: curPriv),
        _storage.write(key: _kSpkPrevId,   value: curId),
      ]);
    }

    final spkPair = await _x25519.newKeyPair();
    final spkPub  = await spkPair.extractPublicKey();
    final spkPriv = await spkPair.extractPrivateKeyBytes();
    final ikPriv  = await _readPrivKey(_kIkPriv);
    final spkSig  = await _signSpk(ikPrivBytes: ikPriv, spkPubBytes: spkPub.bytes);
    final newSpkId = Random.secure().nextInt(0x7FFFFFFF);

    await Future.wait([
      _storage.write(key: _kSpkPriv,      value: _b64e(spkPriv)),
      _storage.write(key: _kSpkPub,       value: _b64e(spkPub.bytes)),
      _storage.write(key: _kSpkSig,       value: _b64e(spkSig)),
      _storage.write(key: _kSpkId,        value: newSpkId.toString()),
      _storage.write(key: _kSpkCreatedAt, value: DateTime.now().toIso8601String()),
    ]);

    final ikPub = (await _storage.read(key: _kIkPub))!;
    final regId = (await _storage.read(key: _kRegId))!;
    return PublishableKeyBundle(
      identityKey: ikPub,
      registrationId: int.parse(regId),
      signedPreKeyId: newSpkId,
      signedPreKey: _b64e(spkPub.bytes),
      signedPreKeySignature: _b64e(spkSig),
      oneTimePreKeys: [],
    );
  }

  // ── Sending: X3DH → session key ────────────────────────────────────────────

  /// Performs X3DH as the initiator with [bundle] to derive a 32-byte session key.
  ///
  ///   DH1 = X25519(my_identity_private,   recipient.signedPreKey)
  ///   DH2 = X25519(ephemeral_private,      recipient.identityKey)
  ///   DH3 = X25519(ephemeral_private,      recipient.signedPreKey)
  ///   DH4 = X25519(ephemeral_private,      recipient.oneTimePreKey)  // if present
  ///
  ///   master_secret = HKDF(DH1||DH2||DH3||DH4, salt=32×0x00, info="chat-e2e")
  Future<SendingSession> createSendingSession(RecipientKeyBundle bundle) async {
    final ikAPriv = await _readPrivKey(_kIkPriv);

    // Generate a single-use ephemeral key pair
    final ekPair = await _x25519.newKeyPair();
    final ekPub  = await ekPair.extractPublicKey();
    final ekPriv = Uint8List.fromList(await ekPair.extractPrivateKeyBytes());

    final ikBPub  = _toPub(bundle.identityKey);
    final spkBPub = _toPub(bundle.signedPreKey);

    final dh1 = await _dh(ikAPriv,  spkBPub); // IK_A × SPK_B
    final dh2 = await _dh(ekPriv,   ikBPub);  // EK_A × IK_B
    final dh3 = await _dh(ekPriv,   spkBPub); // EK_A × SPK_B

    Uint8List? dh4;
    int? otpkId;
    if (bundle.oneTimePreKey != null) {
      final otpkBPub = _toPub(bundle.oneTimePreKey!);
      dh4    = await _dh(ekPriv, otpkBPub);   // EK_A × OPK_B
      otpkId = bundle.oneTimePreKeyId;
    }

    final sessionKey = await _x3dhDerive(dh1, dh2, dh3, dh4);

    return SendingSession(
      sessionKey: sessionKey,
      ephemeralPublicKey: _b64e(ekPub.bytes),
      otpkId: otpkId,
    );
  }

  // ── Receiving: X3DH → session key ─────────────────────────────────────────

  /// Derives the session key as the responder.
  ///
  ///   DH1 = X25519(my_signed_prekey_private,   sender.identityKey)
  ///   DH2 = X25519(my_identity_private,         sender.ephemeralKey)
  ///   DH3 = X25519(my_signed_prekey_private,    sender.ephemeralKey)
  ///   DH4 = X25519(my_one_time_prekey_private,  sender.ephemeralKey) // if otpkId != null
  ///
  /// [senderIdentityKey] — IK_A public key (base64url), from the WS message.
  /// [senderEphemeralKey] — EK_A public key (base64url), from the WS message.
  /// [consumedOtpkId]    — keyId of the OPK consumed (null if none).
  /// [usePrevSPK]        — use the archived previous SPK (for SPK rotation fallback).
  /// [deleteConsumedOtpk] — delete the OTPK private key after deriving DH4.
  ///                        Pass false when test-decrypting before committing.
  Future<Uint8List> deriveReceivingKey({
    required String senderIdentityKey,
    required String senderEphemeralKey,
    int? consumedOtpkId,
    bool usePrevSPK = false,
    bool deleteConsumedOtpk = true,
  }) async {
    final Uint8List spkBPriv;
    if (usePrevSPK) {
      final v = await _storage.read(key: _kSpkPrevPriv);
      if (v == null || v.isEmpty) {
        throw Exception('E2EE: no previous SPK available for fallback');
      }
      spkBPriv = _b64d(v);
    } else {
      spkBPriv = await _readPrivKey(_kSpkPriv);
    }

    final ikBPriv = await _readPrivKey(_kIkPriv);

    final ikAPub = _toPub(senderIdentityKey);
    final ekAPub = _toPub(senderEphemeralKey);

    final dh1 = await _dh(spkBPriv, ikAPub);  // SPK_B × IK_A
    final dh2 = await _dh(ikBPriv,  ekAPub);  // IK_B  × EK_A
    final dh3 = await _dh(spkBPriv, ekAPub);  // SPK_B × EK_A

    Uint8List? dh4;
    if (consumedOtpkId != null) {
      final storageKey = 'e2ee.otpk.$consumedOtpkId.priv';
      try {
        final otpkPriv = await _readPrivKey(storageKey);
        dh4 = await _dh(otpkPriv, ekAPub);    // OPK_B × EK_A
        if (deleteConsumedOtpk) {
          await _storage.delete(key: storageKey);
        }
      } catch (_) {
        // OPK already consumed or not found — proceed without DH4.
      }
    }

    return _x3dhDerive(dh1, dh2, dh3, dh4);
  }

  /// Explicitly deletes a one-time prekey private key from secure storage.
  /// Call this after confirming that a session key derived with that OTPK is correct.
  Future<void> deleteOtpk(int keyId) =>
      _storage.delete(key: 'e2ee.otpk.$keyId.priv');

  // ── Our own identity public key ────────────────────────────────────────────

  /// Returns our X25519 identity public key (base64url), or null if not yet generated.
  Future<String?> identityPublicKey() =>
      _storage.read(key: _kIkPub);

  /// Returns the current SPK ID, or null if no keys have been generated.
  Future<int?> currentSpkId() async {
    final v = await _storage.read(key: _kSpkId);
    return v != null ? int.tryParse(v) : null;
  }

  // ── Session key storage ────────────────────────────────────────────────────

  Future<void> storeSessionKey(String roomId, Uint8List key) =>
      _storage.write(key: 'e2ee.session.$roomId', value: _b64e(key));

  Future<Uint8List?> loadSessionKey(String roomId) async {
    final v = await _storage.read(key: 'e2ee.session.$roomId');
    return v != null ? _b64d(v) : null;
  }

  Future<void> deleteSessionKey(String roomId) =>
      _storage.delete(key: 'e2ee.session.$roomId');

  // ── Peer identity key cache ────────────────────────────────────────────────

  Future<void> storeIdentityKey(String userId, String ikPub) =>
      _storage.write(key: 'e2ee.ik_peer.$userId', value: ikPub);

  Future<String?> loadIdentityKey(String userId) =>
      _storage.read(key: 'e2ee.ik_peer.$userId');

  // ── Phase 6: cached bundle fingerprint (for session invalidation) ──────────

  /// Stores {identityKey, signedPreKeyId} for [userId] so that future room
  /// opens can detect if the recipient rotated or reinstalled their keys.
  Future<void> storeCachedBundle(
    String userId, {
    required String identityKey,
    required int signedPreKeyId,
  }) async {
    final v = jsonEncode({'ik': identityKey, 'spkId': signedPreKeyId});
    await _storage.write(key: 'e2ee.cached_bundle.$userId', value: v);
  }

  /// Returns null if no cached bundle exists for [userId].
  Future<Map<String, dynamic>?> loadCachedBundle(String userId) async {
    final v = await _storage.read(key: 'e2ee.cached_bundle.$userId');
    if (v == null) return null;
    return jsonDecode(v) as Map<String, dynamic>;
  }

  /// Deletes every e2ee key from secure storage. Called when a different user
  /// logs in so that session keys, identity keys, and OPKs are never reused
  /// across accounts.
  Future<void> clearAllKeys() async {
    final all = await _storage.readAll();
    await Future.wait([
      for (final key in all.keys)
        if (key.startsWith('e2ee.')) _storage.delete(key: key),
    ]);
  }

  // ── Encrypt / Decrypt ──────────────────────────────────────────────────────

  /// AES-256-GCM encrypt [plaintext] with [sessionKey].
  Future<EncryptedPayload> encrypt(Uint8List sessionKey, String plaintext) async {
    final nonce = _aesGcm.newNonce();
    final box   = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(sessionKey),
      nonce: nonce,
    );
    // Append 16-byte MAC to ciphertext so the server can relay it as one blob.
    final withMac = Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    return EncryptedPayload(
      ciphertext: _b64e(withMac),
      iv: _b64e(Uint8List.fromList(box.nonce)),
    );
  }

  /// AES-256-GCM decrypt base64url [ciphertext] (with appended 16-byte MAC).
  Future<String> decrypt(
      Uint8List sessionKey, String ciphertext, String iv) async {
    final raw = _b64d(ciphertext);
    if (raw.length < 17) throw Exception('Ciphertext too short');

    final cipher = raw.sublist(0, raw.length - 16);
    final mac    = raw.sublist(raw.length - 16);
    final nonce  = _b64d(iv);

    final plainBytes = await _aesGcm.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(sessionKey),
    );
    return utf8.decode(plainBytes);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<List<OtpkEntry>> _generateOtpkEntries(int count) async {
    final rng    = Random.secure();
    final result = <OtpkEntry>[];
    for (int i = 0; i < count; i++) {
      final keyId = rng.nextInt(0x7FFFFFFF);
      final pair  = await _x25519.newKeyPair();
      final pub   = await pair.extractPublicKey();
      final priv  = await pair.extractPrivateKeyBytes();
      await _storage.write(
          key: 'e2ee.otpk.$keyId.priv', value: _b64e(priv));
      result.add(OtpkEntry(keyId: keyId, publicKey: _b64e(pub.bytes)));
    }
    return result;
  }

  /// X25519 DH with a raw private key seed and a SimplePublicKey.
  Future<Uint8List> _dh(Uint8List privBytes, SimplePublicKey remotePub) async {
    final pair   = await _x25519.newKeyPairFromSeed(privBytes);
    final shared = await _x25519.sharedSecretKey(
        keyPair: pair, remotePublicKey: remotePub);
    return Uint8List.fromList(await shared.extractBytes());
  }

  /// HKDF derivation per spec:
  ///   IKM  = DH1 || DH2 || DH3 [ || DH4 ]
  ///   salt = 32 zero bytes
  ///   info = "chat-e2e"
  Future<Uint8List> _x3dhDerive(
    Uint8List dh1, Uint8List dh2, Uint8List dh3, Uint8List? dh4) async {
    final ikm = Uint8List.fromList([
      ...dh1, ...dh2, ...dh3,
      if (dh4 != null) ...dh4,
    ]);
    final out = await _hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: Uint8List(32),             // 32 zero bytes (salt)
      info: utf8.encode('chat-e2e'),    // per spec
    );
    return Uint8List.fromList(await out.extractBytes());
  }

  /// HMAC-SHA256 of [spkPubBytes] keyed by [ikPrivBytes] — used as SPK signature.
  Future<Uint8List> _signSpk({
    required Uint8List ikPrivBytes,
    required List<int> spkPubBytes,
  }) async {
    final mac = await _hmac.calculateMac(
        spkPubBytes, secretKey: SecretKey(ikPrivBytes));
    return Uint8List.fromList(mac.bytes);
  }

  Future<Uint8List> _readPrivKey(String key) async {
    final v = await _storage.read(key: key);
    if (v == null || v.isEmpty) throw Exception('E2EE private key not found: $key');
    return _b64d(v);
  }

  SimplePublicKey _toPub(String base64url) =>
      SimplePublicKey(_b64d(base64url), type: KeyPairType.x25519);

  // Padding-free base64url encode / decode
  static String _b64e(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _b64d(String s) {
    final padded = s.padRight((s.length + 3) ~/ 4 * 4, '=');
    return Uint8List.fromList(base64Url.decode(padded));
  }
}
