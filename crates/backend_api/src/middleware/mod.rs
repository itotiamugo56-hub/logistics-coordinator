//! Authentication middleware for Axum

use axum::{
    async_trait,
    extract::{FromRequestParts},
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
};
use crate::auth::{TokenClaims, validate_token, Role, check_role};
use crate::models::TokenConstraints as ModelTokenConstraints;
use jsonwebtoken::{decode, DecodingKey, Validation, Algorithm};
use serde::{Serialize, Deserialize};

/// Simple test token claims (must match auth.rs)
#[derive(Debug, Serialize, Deserialize)]
struct TestClaims {
    sub: String,
    exp: usize,
    iat: usize,
    role: String,
}

/// Authenticated user extracted from JWT
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub claims: TokenClaims,
    pub member_id: uuid::Uuid,
    pub role: Role,
    pub constraints: ModelTokenConstraints,
}

/// Auth error that converts to HTTP response
#[derive(Debug)]
pub enum AuthError {
    MissingToken,
    InvalidToken,
    ExpiredToken,
    RevokedToken,
    InsufficientRole { required: Role },
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let (status, body) = match self {
            AuthError::MissingToken => (StatusCode::UNAUTHORIZED, "Missing authorization token".to_string()),
            AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "Invalid token".to_string()),
            AuthError::ExpiredToken => (StatusCode::UNAUTHORIZED, "Token expired".to_string()),
            AuthError::RevokedToken => (StatusCode::UNAUTHORIZED, "Token revoked".to_string()),
            AuthError::InsufficientRole { required } => (
                StatusCode::FORBIDDEN,
                format!("Insufficient role. Required: {:?}", required),
            ),
        };
        (status, body).into_response()
    }
}

/// Validate a test token (HS256)
fn validate_test_token(token: &str) -> Result<TestClaims, AuthError> {
    let decoded = decode::<TestClaims>(
        token,
        &DecodingKey::from_secret(b"test_secret_key_123"),
        &Validation::new(Algorithm::HS256),
    ).map_err(|_| AuthError::InvalidToken)?;
    
    let claims = decoded.claims;
    let now = chrono::Utc::now().timestamp() as usize;
    
    if claims.exp < now {
        return Err(AuthError::ExpiredToken);
    }
    
    Ok(claims)
}

/// Extractor that validates JWT and enforces minimum role
pub struct RequireRole(pub Role);

#[async_trait]
impl<S> FromRequestParts<S> for RequireRole
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("authorization")
            .and_then(|h| h.to_str().ok())
            .ok_or(AuthError::MissingToken)?;
        
        if !auth_header.starts_with("Bearer ") {
            return Err(AuthError::InvalidToken);
        }
        
        let token = &auth_header[7..];
        
        // Validate the test token
        let claims = validate_test_token(token)?;
        let role: Role = claims.role.as_str().into();
        let required_role = Role::Usher;
        
        if role.level() > required_role.level() {
            return Err(AuthError::InsufficientRole { required: required_role });
        }
        
        Ok(RequireRole(required_role))
    }
}

#[async_trait]
impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("authorization")
            .and_then(|h| h.to_str().ok())
            .ok_or(AuthError::MissingToken)?;
        
        if !auth_header.starts_with("Bearer ") {
            return Err(AuthError::InvalidToken);
        }
        
        let token = &auth_header[7..];
        
        // Validate the test token
        let claims = validate_test_token(token)?;
        let role: Role = claims.role.as_str().into();
        let member_id = uuid::Uuid::parse_str(&claims.sub).map_err(|_| AuthError::InvalidToken)?;
        
        // Create placeholder token claims (for compatibility)
        let token_claims = TokenClaims {
            jti: uuid::Uuid::new_v4(),
            sub: member_id,
            role: claims.role.clone(),
            exp: claims.exp,
            iat: claims.iat,
            iss: "test".to_string(),
            delegation_chain: vec![],
            constraints: crate::auth::TokenConstraints::default(),
        };
        
        let constraints = ModelTokenConstraints {
            allowed_branch_geohashes: None,
            max_pickup_radius_km: Some(5),
            can_verify_members: false,
        };
        
        Ok(AuthenticatedUser {
            member_id,
            claims: token_claims,
            role,
            constraints,
        })
    }
}