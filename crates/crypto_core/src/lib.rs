#![cfg_attr(not(feature = "std"), no_std)]
#![forbid(unsafe_code)]

pub mod ed25519;
pub mod kdf;

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_ed25519_basics() {
        let (pk, sk) = ed25519::generate_keypair();
        let msg = b"test message";
        let sig = ed25519::sign(msg, &sk);
        assert!(ed25519::verify(msg, &sig, &pk));
    }
}