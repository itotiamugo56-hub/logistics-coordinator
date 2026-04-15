use argon2::{Argon2, PasswordHasher};
use argon2::password_hash::SaltString;
use blake3;

pub fn hash_password(password: &[u8], salt: &[u8; 16]) -> [u8; 32] {
    let salt_str = SaltString::encode_b64(salt).unwrap();
    let argon2 = Argon2::default();
    let hash = argon2.hash_password(password, &salt_str).unwrap();

    let hash_str = hash.to_string();
    blake3::hash(hash_str.as_bytes()).into()
}

pub fn verify_password(password: &[u8], salt: &[u8; 16], stored_hash: &[u8; 32]) -> bool {
    let computed = hash_password(password, salt);
    computed == *stored_hash
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_password_hash_deterministic() {
        let password = b"test_password";
        let salt = [0u8; 16];
        let hash1 = hash_password(password, &salt);
        let hash2 = hash_password(password, &salt);
        assert_eq!(hash1, hash2);
    }

    #[test]
    fn test_verify_correct() {
        let password = b"correct_password";
        let salt = [1u8; 16];
        let hash = hash_password(password, &salt);
        assert!(verify_password(password, &salt, &hash));
    }

    #[test]
    fn test_verify_wrong() {
        let password = b"correct_password";
        let salt = [2u8; 16];
        let hash = hash_password(password, &salt);
        let wrong = b"wrong_password";
        assert!(!verify_password(wrong, &salt, &hash));
    }
}