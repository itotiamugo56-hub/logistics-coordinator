//! JWT Token Issuance and Validation
//! 
//! Implements hierarchical token-based authentication with:
//! - Ed25519 signatures for delegation chains
//! - Role-based expiration times
//! - Token constraints (branch limits, geohash limits)

use chrono::{Utc, Duration};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation, Algorithm};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use std::collections::HashSet;

use crate::auth::roles::Role;
use super::delegation::{DelegationProof, verify_delegation_chain};

// ============================================================
// JWT Configuration
// ============================================================

/// JWT signing secret (from environment variable in production)
const JWT_SECRET: &[u8] = b"zero_trust_logistics_secret_key_2026_32_bytes!!";

/// JWT algorithm
const JWT_ALGORITHM: Algorithm = Algorithm::HS512;

// ============================================================
// Token Claims
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenConstraints {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub allowed_branch_ids: Option<Vec<Uuid>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub allowed_geohashes: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_pickup_radius_km: Option<u32>,
    pub can_verify_members: bool,
    pub single_use: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_flares_per_day: Option<u32>,
}

impl Default for TokenConstraints {
    fn default() -> Self {
        Self {
            allowed_branch_ids: None,
            allowed_geohashes: None,
            max_pickup_radius_km: None,
            can_verify_members: false,
            single_use: false,
            max_flares_per_day: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum VerificationStatus {
    Unverified,
    BiometricOnly,
    HardwareKeyOnly,
    FullyVerified,
    Revoked,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenClaims {
    // Standard JWT claims
    pub sub: Uuid,           // Member ID
    pub iat: i64,            // Issued at (seconds since epoch)
    pub exp: i64,            // Expiration (seconds since epoch)
    pub jti: Uuid,           // Token ID (for revocation)
    
    // Custom claims
    pub role: Role,          // Assigned role
    pub delegation_chain: Vec<DelegationProof>,
    
    // Constraints
    pub constraints: TokenConstraints,
    
    // Verification status
    pub verification_status: VerificationStatus,
}

// ============================================================
// Token Lifetime by Role
// ============================================================
pub fn token_lifetime(role: &Role) -> i64 {
    match role {
        Role::GlobalAdmin => 604800,     // 7 days
        Role::RegionalAdmin => 604800,   // 7 days
        Role::BranchClergy => 259200,    // 3 days
        Role::VerifiedMember => 43200,   // 12 hours
    }
}


// ============================================================
// JWT Issuance
// ============================================================
pub fn issue_token(
    member_id: Uuid,
    role: Role,
    constraints: TokenConstraints,
    delegation_chain: Vec<DelegationProof>,
    verification_status: VerificationStatus,
) -> Result<String, AuthError> {
    let now = Utc::now();
    let lifetime = token_lifetime(&role);
    
    let claims = TokenClaims {
        sub: member_id,
        iat: now.timestamp(),
        exp: (now + Duration::seconds(lifetime)).timestamp(),
        jti: Uuid::new_v4(),
        role,
        delegation_chain,
        constraints,
        verification_status,
    };
    
    encode(
        &Header::new(JWT_ALGORITHM),
        &claims,
        &EncodingKey::from_secret(JWT_SECRET),
    ).map_err(|_| AuthError::TokenCreationFailed)
}

/// Issue a temporary token (24 hours) for unverified members
pub fn issue_temp_token(
    member_id: Uuid,
) -> Result<String, AuthError> {
    let now = Utc::now();
    let claims = TokenClaims {
        sub: member_id,
        iat: now.timestamp(),
        exp: (now + Duration::hours(24)).timestamp(),
        jti: Uuid::new_v4(),
        role: Role::VerifiedMember,
        delegation_chain: vec![],
        constraints: TokenConstraints::default(),
        verification_status: VerificationStatus::Unverified,
    };
    
    encode(
        &Header::new(JWT_ALGORITHM),
        &claims,
        &EncodingKey::from_secret(JWT_SECRET),
    ).map_err(|_| AuthError::TokenCreationFailed)
}

// ============================================================
// JWT Validation
// ============================================================

/// Validate a JWT token and return claims
pub fn validate_token(
    token: &str,
    revocation_list: &HashSet<Uuid>,
) -> Result<TokenClaims, AuthError> {
    let validation = Validation::new(JWT_ALGORITHM);
    
    let token_data = decode::<TokenClaims>(
        token,
        &DecodingKey::from_secret(JWT_SECRET),
        &validation,
    ).map_err(|e| match e.kind() {
        jsonwebtoken::errors::ErrorKind::ExpiredSignature => AuthError::Expired,
        _ => AuthError::InvalidSignature,
    })?;
    
    let claims = token_data.claims;
    
    // Check if token is revoked
    if revocation_list.contains(&claims.jti) {
        return Err(AuthError::Revoked);
    }
    
    // Verify delegation chain
    if !claims.delegation_chain.is_empty() {
        verify_delegation_chain(&claims)?;
    }
    
    Ok(claims)
}

/// Validate token without revocation check (for offline mode)
pub fn validate_token_offline(token: &str) -> Result<TokenClaims, AuthError> {
    let validation = Validation::new(JWT_ALGORITHM);
    
    let token_data = decode::<TokenClaims>(
        token,
        &DecodingKey::from_secret(JWT_SECRET),
        &validation,
    ).map_err(|e| match e.kind() {
        jsonwebtoken::errors::ErrorKind::ExpiredSignature => AuthError::Expired,
        _ => AuthError::InvalidSignature,
    })?;
    
    Ok(token_data.claims)
}

// ============================================================
// Error Types
// ============================================================

#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("Invalid token signature")]
    InvalidSignature,
    #[error("Token has expired")]
    Expired,
    #[error("Token has been revoked")]
    Revoked,
    #[error("Invalid delegation chain")]
    InvalidDelegation,
    #[error("Insufficient role")]
    InsufficientRole,
    #[error("Token creation failed")]
    TokenCreationFailed,
    #[error("Missing token")]
    MissingToken,
}

impl From<AuthError> for axum::http::StatusCode {
    fn from(err: AuthError) -> Self {
        match err {
            AuthError::InvalidSignature | AuthError::MissingToken => Self::UNAUTHORIZED,
            AuthError::Expired => Self::UNAUTHORIZED,
            AuthError::Revoked => Self::UNAUTHORIZED,
            AuthError::InvalidDelegation => Self::FORBIDDEN,
            AuthError::InsufficientRole => Self::FORBIDDEN,
            AuthError::TokenCreationFailed => Self::INTERNAL_SERVER_ERROR,
        }
    }
}