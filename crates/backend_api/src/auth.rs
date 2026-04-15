//! Hierarchical JWT authentication with Ed25519 signatures

use serde::{Serialize, Deserialize};
use chrono::{Utc, Duration};
use uuid::Uuid;
use jsonwebtoken::{encode, DecodingKey, EncodingKey, Validation, Algorithm};
use crypto_core::ed25519;
use thiserror::Error;
use std::fmt;

/// User roles (hierarchy: 0=highest, 4=lowest)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum Role {
    GlobalAdmin,
    National,
    Regional,
    BranchCoord,
    Usher,
}

impl fmt::Display for Role {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Role::GlobalAdmin => "global_admin",
            Role::National => "national",
            Role::Regional => "regional",
            Role::BranchCoord => "branch_coord",
            Role::Usher => "usher",
        };
        write!(f, "{}", s)
    }
}

impl Role {
    pub fn level(&self) -> u8 {
        match self {
            Role::GlobalAdmin => 0,
            Role::National => 1,
            Role::Regional => 2,
            Role::BranchCoord => 3,
            Role::Usher => 4,
        }
    }
    
    pub fn can_delegate_to(&self) -> Vec<Role> {
        match self {
            Role::GlobalAdmin => vec![Role::National],
            Role::National => vec![Role::Regional],
            Role::Regional => vec![Role::BranchCoord],
            Role::BranchCoord => vec![Role::Usher],
            Role::Usher => vec![],
        }
    }
}

impl From<&str> for Role {
    fn from(s: &str) -> Self {
        match s {
            "global_admin" => Role::GlobalAdmin,
            "national" => Role::National,
            "regional" => Role::Regional,
            "branch_coord" => Role::BranchCoord,
            "usher" => Role::Usher,
            _ => Role::Usher,
        }
    }
}

/// JWT claims with delegation chain
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenClaims {
    pub jti: Uuid,
    pub sub: Uuid,
    pub role: String,
    pub exp: usize,
    pub iat: usize,
    pub iss: String,
    pub delegation_chain: Vec<String>,
    pub constraints: TokenConstraints,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TokenConstraints {
    pub allowed_branch_h3: Option<Vec<String>>,
    pub max_pickup_radius_km: Option<u32>,
    pub can_verify_members: bool,
}

/// Authentication errors
#[derive(Error, Debug)]
pub enum AuthError {
    #[error("Invalid token signature")]
    InvalidSignature,
    
    #[error("Token expired")]
    Expired,
    
    #[error("Token revoked")]
    Revoked,
    
    #[error("Insufficient role: required {required}, has {has}")]
    InsufficientRole { required: Role, has: Role },
    
    #[error("Invalid delegation chain")]
    InvalidDelegation,
    
    #[error("JWT error: {0}")]
    JwtError(#[from] jsonwebtoken::errors::Error),
}

/// Issue a new delegated token
#[allow(unused_variables)]
pub fn issue_token(
    subject_member_id: Uuid,
    target_role: Role,
    issuer_role: Role,
    issuer_key: &ed25519::SecretKey,
    parent_token_signature: Option<&str>,
    expires_in_seconds: u32,
    constraints: TokenConstraints,
) -> Result<String, AuthError> {
    if !issuer_role.can_delegate_to().contains(&target_role) {
        return Err(AuthError::InvalidDelegation);
    }
    
    let now = Utc::now();
    let exp = (now + Duration::seconds(expires_in_seconds as i64)).timestamp() as usize;
    let iat = now.timestamp() as usize;
    
    let mut delegation_chain = Vec::new();
    if let Some(parent_sig) = parent_token_signature {
        delegation_chain.push(parent_sig.to_string());
    }
    
    let claims = TokenClaims {
        jti: Uuid::new_v4(),
        sub: subject_member_id,
        role: target_role.to_string(),
        exp,
        iat,
        iss: "zero-trust-logistics.internal".to_string(),
        delegation_chain,
        constraints,
    };
    
    // Placeholder - in production use proper key
    let token = encode(
        &jsonwebtoken::Header::new(Algorithm::EdDSA),
        &claims,
        &EncodingKey::from_ed_der(&[]),
    ).map_err(|_| AuthError::InvalidSignature)?;
    
    Ok(token)
}

/// Validate a token and extract claims
pub fn validate_token(token: &str, _revocation_list: &[Uuid]) -> Result<TokenClaims, AuthError> {
    let decoded = jsonwebtoken::decode::<TokenClaims>(
        token,
        &DecodingKey::from_ed_der(&[]),
        &Validation::new(Algorithm::EdDSA),
    ).map_err(|_| AuthError::InvalidSignature)?;
    
    let claims = decoded.claims;
    let now = Utc::now().timestamp() as usize;
    
    if claims.exp < now {
        return Err(AuthError::Expired);
    }
    
    Ok(claims)
}

/// Check if a role meets the required minimum (takes reference to avoid move)
pub fn check_role(claims: &TokenClaims, required: &Role) -> Result<(), AuthError> {
    let claim_role: Role = claims.role.as_str().into();
    let required_level = required.level();
    let claim_level = claim_role.level();
    
    if claim_level > required_level {
        return Err(AuthError::InsufficientRole {
            required: required.clone(),
            has: claim_role,
        });
    }
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_role_hierarchy() {
        assert!(Role::GlobalAdmin.can_delegate_to().contains(&Role::National));
        assert!(Role::BranchCoord.can_delegate_to().contains(&Role::Usher));
        assert!(Role::Usher.can_delegate_to().is_empty());
    }
    
    #[test]
    fn test_role_levels() {
        assert!(Role::GlobalAdmin.level() < Role::National.level());
        assert!(Role::National.level() < Role::Regional.level());
        assert!(Role::Regional.level() < Role::BranchCoord.level());
        assert!(Role::BranchCoord.level() < Role::Usher.level());
    }
}