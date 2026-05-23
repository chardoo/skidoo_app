Here's the full encryption flow and what the Flutter frontend needs to implement:                                                                      
                                                                                                                                                         
  ---                                                                                                                                                    
  Encryption Flow: X3DH + AES-256-GCM                                                                                                                    
                                                                                                                                                         
  This is a simplified Signal-style protocol. Encryption is DM rooms only — event/photo/global rooms are always plaintext.                               
                                                                                                                                                         
  ---             
  Phase 1 — First Launch: Generate & Publish Keys                                                                                                        
                                                                                                                                                         
  The frontend generates all key material locally (never send private keys):
                                                                                                                                                         
  - identityKeyPair — X25519, permanent (regenerate only on reinstall)
  - registrationId — random int, stable                                                                                                                  
  - signedPreKeyPair — X25519, rotate every ~7 days
  - signedPreKeySignature — Ed25519 signature of the signed prekey public bytes                                                                          
  - oneTimePreKeys[] — 100 × X25519 pairs                                                                                                                
                                                                                                                                                         
  Then publish public keys:                                                                                                                              
  POST /api/chat/keys/bundle
                                                                                                                                                         
  ---             
  Phase 2 — OTPK Replenishment (ongoing)                                                                                                                 
                                        
  On every app start, call:                                                                                                                              
  GET /api/chat/keys/me/prekeys/count                                                                                                                    
  If oneTimePreKeysRemaining < 10, top up:
  POST /api/chat/keys/prekeys                                                                                                                            
                                                                                                                                                         
  ---                                                                                                                                                    
  Phase 3 — Opening a DM (first message)                                                                                                                 
                                                                                                                                                         
  1. Fetch recipient's bundle — server atomically pops one OTPK:
  GET /api/chat/keys/{recipientId}/bundle                                                                                                                
  1. If e2eAvailable: false → fall back to plaintext.
  2. Run X3DH locally to derive a 32-byte sessionKey:                                                                                                    
  EK = X25519KeyPair.generate()   // ephemeral, this session only                                                                                        
  DH1 = ecdh(myIK.private,  recipientSPK.public)                                                                                                         
  DH2 = ecdh(EK.private,    recipientIK.public)                                                                                                          
  DH3 = ecdh(EK.private,    recipientSPK.public)                                                                                                         
  DH4 = ecdh(EK.private,    recipientOTPK.public)  // omit if OTPK was null                                                                              
  sessionKey = HKDF(DH1+DH2+DH3+DH4, length=32, info="chat-e2e")                                                                                         
  3. Encrypt & send over WebSocket:                                                                                                                      
  {                                                                                                                                                      
    "type": "message",                                                                                                                                   
    "ciphertext": "<base64url AES-GCM output>",                                                                                                          
    "iv": "<base64url 12-byte random nonce>",                                                                                                            
    "ephemeral_key": "<base64url EK.public>",                                                                                                            
    "sender_identity_key": "<base64url myIK.public>",                                                                                                    
    "otpk_id": 42                                                                                                                                        
  }               
  4. Cache sessionKey in flutter_secure_storage keyed by roomId.                                                                                         
                                                                                                                                                         
  ---
  Phase 4 — Receiving the First Message                                                                                                                  
                                                                                                                                                         
  Detected by presence of ephemeral_key in the incoming WS message. Mirror the X3DH from the recipient's side:
  DH1 = ecdh(mySPK.private,   msg.sender_identity_key)                                                                                                   
  DH2 = ecdh(myIK.private,    msg.ephemeral_key)      
  DH3 = ecdh(mySPK.private,   msg.ephemeral_key)                                                                                                         
  DH4 = ecdh(myOTPK[otpk_id].private, msg.ephemeral_key)
  sessionKey = HKDF(DH1+DH2+DH3+DH4, length=32, info="chat-e2e")                                                                                         
  plaintext = AES-GCM.decrypt(msg.ciphertext, key=sessionKey, iv=msg.iv)                                                                                 
  Delete the consumed OTPK private key. Save sessionKey to secure storage.                                                                               
                                                                                                                                                         
  ---                                                                                                                                                    
  Phase 5 — Ongoing Messages (same session)                                                                                                              
                                                                                                                                                         
  ephemeral_key, sender_identity_key, otpk_id are all null/absent.
                                                                                                                                                         
  Send:                                                                                                                                                  
  { "type": "message", "ciphertext": "...", "iv": "..." }                                                                                                
  Receive: look up sessionKey by roomId, decrypt with AES-GCM.                                                                                           
                  
  ---                                                                                                                                                    
  Phase 6 — Session Invalidation
                                                                                                                                                         
  When you open a DM, compare the fetched bundle vs your cached { registrationId, signedPreKeyId }. If either changed → recipient reinstalled or rotated
  keys → delete your cached sessionKey and re-run Phase 3 on next send.                                                                                  
                  
  The WS also pushes participant_key_available and key_bundles events in real time — handle these the same way.                                          
                  
  ---                                                                                                                                                    
  Local Storage (use flutter_secure_storage)
                                                                                                                                                         
  ┌─────────────────────┬─────────────────────────────────────────────────┐
  │         Key         │                      Value                      │                                                                              
  ├─────────────────────┼─────────────────────────────────────────────────┤
  │ identityKeyPair     │ Never leaves device                             │
  ├─────────────────────┼─────────────────────────────────────────────────┤
  │ signedPreKeyPairs[] │ Keep last 2–3 during rotation window            │                                                                              
  ├─────────────────────┼─────────────────────────────────────────────────┤                                                                              
  │ oneTimePreKeys      │ Map<keyId, privateKey> — delete after consuming │                                                                              
  ├─────────────────────┼─────────────────────────────────────────────────┤                                                                              
  │ sessionKeys         │ Map<roomId, Uint8List(32)>                      │
  ├─────────────────────┼─────────────────────────────────────────────────┤                                                                              
  │ cachedBundles       │ Map<userId, {registrationId, signedPreKeyId}>   │
  └─────────────────────┴─────────────────────────────────────────────────┘                                                                              
                  
  ---                                                                                                                                                    
  Key Rules       
           
  - Generate a fresh 12-byte IV for every single message (even in ongoing sessions)
  - The server stores ciphertext opaquely — plaintext never touches the backend                                                                          
  - If you receive a message with ephemeral_key != null, always treat it as a new session and re-derive (overwrite cached key)                           
  - If sessionKey is missing mid-conversation (cleared storage etc.), inbound messages are unrecoverable — show an error. On next outbound send, re-run  
  Phase 3 to re-key both sides                                                                                                                           
                                                                                                                                                         
✻ Crunched for 41s  