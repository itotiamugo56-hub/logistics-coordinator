//! Tile signing using Person A's crypto
//! Ensures offline tiles are authentic and haven't been tampered with

use crypto_core::ed25519::{self, PublicKey, SecretKey, SignatureBytes};
use serde::{Serialize, Deserialize};
use hex;

/// Signed tile bundle with signature
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TileSignature {
    /// The signature (hex-encoded for serialization)
    pub signature_hex: String,
    
    /// Timestamp when signed
    pub timestamp_ms: u64,
    
    /// Public key that can verify this signature
    pub signer_public_key_hex: String,
}

/// Sign a tile bundle (creates a detached signature)
pub fn sign_tile_bundle(tile_data: &[u8], sk: &SecretKey) -> String {
    let signature = ed25519::sign(tile_data, sk);
    hex::encode(signature.0)
}

/// Verify a tile bundle against its signature
pub fn verify_tile_bundle(tile_data: &[u8], signature_hex: &str, pk: &PublicKey) -> bool {
    let signature_bytes = match hex::decode(signature_hex) {
        Ok(bytes) => {
            if bytes.len() != 64 {
                return false;
            }
            let mut arr = [0u8; 64];
            arr.copy_from_slice(&bytes);
            SignatureBytes(arr)
        }
        Err(_) => return false,
    };
    
    ed25519::verify(tile_data, &signature_bytes, pk)
}

/// Create a full tile signature object
pub fn create_tile_signature(tile_data: &[u8], sk: &SecretKey, pk: &PublicKey) -> TileSignature {
    use std::time::{SystemTime, UNIX_EPOCH};
    
    let timestamp_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as u64;
    
    TileSignature {
        signature_hex: sign_tile_bundle(tile_data, sk),
        timestamp_ms,
        signer_public_key_hex: hex::encode(pk.0),
    }
}

/// Verify a tile signature object
pub fn verify_tile_signature(tile_data: &[u8], signature: &TileSignature) -> bool {
    let pk_bytes = match hex::decode(&signature.signer_public_key_hex) {
        Ok(bytes) => {
            if bytes.len() != 32 {
                return false;
            }
            let mut arr = [0u8; 32];
            arr.copy_from_slice(&bytes);
            PublicKey(arr)
        }
        Err(_) => return false,
    };
    
    verify_tile_bundle(tile_data, &signature.signature_hex, &pk_bytes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crypto_core::ed25519::generate_keypair;
    
    #[test]
    fn test_sign_verify_roundtrip() {
        let (pk, sk) = generate_keypair();
        let tile_data = b"test tile content";
        
        let signature = sign_tile_bundle(tile_data, &sk);
        assert!(verify_tile_bundle(tile_data, &signature, &pk));
    }
    
    #[test]
    fn test_tampered_tile_fails() {
        let (pk, sk) = generate_keypair();
        let mut tile_data = b"original content".to_vec();
        
        let signature = sign_tile_bundle(&tile_data, &sk);
        
        // Tamper with the data
        tile_data[0] ^= 0xFF;
        
        assert!(!verify_tile_bundle(&tile_data, &signature, &pk));
    }
    
    #[test]
    fn test_signature_object() {
        let (pk, sk) = generate_keypair();
        let tile_data = b"important map tiles";
        
        let sig_obj = create_tile_signature(tile_data, &sk, &pk);
        assert!(verify_tile_signature(tile_data, &sig_obj));
    }
}