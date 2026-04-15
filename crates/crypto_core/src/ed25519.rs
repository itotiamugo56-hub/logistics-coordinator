use ed25519_dalek::{Signer, SigningKey, VerifyingKey, Signature, Verifier, PUBLIC_KEY_LENGTH, SECRET_KEY_LENGTH, SIGNATURE_LENGTH};
use rand_core::OsRng;
use zeroize::ZeroizeOnDrop;
use serde::{Serialize, Deserialize};

#[derive(ZeroizeOnDrop, Clone, Debug, Serialize, Deserialize)]
pub struct SecretKey(pub [u8; SECRET_KEY_LENGTH]);

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PublicKey(pub [u8; PUBLIC_KEY_LENGTH]);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SignatureBytes(pub [u8; SIGNATURE_LENGTH]);

impl Serialize for SignatureBytes {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let hex_string = hex::encode(self.0);
        serializer.serialize_str(&hex_string)
    }
}

impl<'de> Deserialize<'de> for SignatureBytes {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let hex_string = String::deserialize(deserializer)?;
        let bytes = hex::decode(&hex_string).map_err(serde::de::Error::custom)?;
        if bytes.len() != SIGNATURE_LENGTH {
            return Err(serde::de::Error::custom("invalid signature length"));
        }
        let mut array = [0u8; SIGNATURE_LENGTH];
        array.copy_from_slice(&bytes);
        Ok(SignatureBytes(array))
    }
}

/// Generate a new Ed25519 keypair using OS randomness
pub fn generate_keypair() -> (PublicKey, SecretKey) {
    let mut csprng = OsRng;
    let signing_key = SigningKey::generate(&mut csprng);
    let verifying_key = signing_key.verifying_key();
    
    let sk = SecretKey(signing_key.to_bytes());
    let pk = PublicKey(verifying_key.to_bytes());
    (pk, sk)
}

/// Sign a message using a secret key
pub fn sign(msg: &[u8], sk: &SecretKey) -> SignatureBytes {
    let signing_key = SigningKey::from_bytes(&sk.0);
    let signature: Signature = signing_key.sign(msg);
    SignatureBytes(signature.to_bytes())
}

/// Verify a signature using a public key
pub fn verify(msg: &[u8], sig: &SignatureBytes, pk: &PublicKey) -> bool {
    let verifying_key = match VerifyingKey::from_bytes(&pk.0) {
        Ok(vk) => vk,
        Err(_) => return false,
    };
    let signature = Signature::from_bytes(&sig.0);
    verifying_key.verify(msg, &signature).is_ok()
}

/// Batch verify multiple signatures
pub fn batch_verify(messages: &[&[u8]], signatures: &[&SignatureBytes], public_keys: &[&PublicKey]) -> bool {
    if messages.len() != signatures.len() || messages.len() != public_keys.len() {
        return false;
    }
    
    for i in 0..messages.len() {
        if !verify(messages[i], signatures[i], public_keys[i]) {
            return false;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_sign_verify_roundtrip() {
        let (pk, sk) = generate_keypair();
        let msg = b"important logistics data";
        let sig = sign(msg, &sk);
        assert!(verify(msg, &sig, &pk));
    }
    
    #[test]
    fn test_batch_verify() {
        let mut pks = Vec::new();
        let mut sigs = Vec::new();
        let mut msgs = Vec::new();
        
        for i in 0..8 {
            let (pk, sk) = generate_keypair();
            let msg = format!("message {}", i).into_bytes();
            let sig = sign(&msg, &sk);
            pks.push(pk);
            sigs.push(sig);
            msgs.push(msg);
        }
        
        let msg_refs: Vec<&[u8]> = msgs.iter().map(|m| m.as_slice()).collect();
        let sig_refs: Vec<&SignatureBytes> = sigs.iter().collect();
        let pk_refs: Vec<&PublicKey> = pks.iter().collect();
        
        assert!(batch_verify(&msg_refs, &sig_refs, &pk_refs));
    }
    
    #[test]
    fn test_bad_signature_fails() {
        let (pk, sk) = generate_keypair();
        let msg = b"good message";
        let mut sig = sign(msg, &sk);
        
        // Corrupt the signature
        sig.0[0] ^= 0xFF;
        
        assert!(!verify(msg, &sig, &pk));
    }
}