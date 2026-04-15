//! Authentication middleware for Axum
//!
//! Extracts and validates JWT tokens from Authorization headers.

use axum::{
    async_trait,
    extract::{FromRequestParts},
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::auth::{
    validate_token, TokenClaims, Role, AuthError as JwtAuthError,
};

// ============================================================
// Types
// ============================================================

/// Authenticated user extracted from JWT
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub claims: TokenClaims,
    pub member_id: uuid::Uuid,
    pub role: Role,
}

/// In-memory revocation list (in production, use database)
pub type RevocationList = Arc<RwLock<HashSet<uuid::Uuid>>>;

/// Auth error that converts to HTTP response
#[derive(Debug)]
pub enum AuthError {
    MissingToken,
    InvalidToken,
    ExpiredToken,
    RevokedToken,
    InsufficientRole { required: Role, actual: Role },
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let (status, body) = match self {
            AuthError::MissingToken => (StatusCode::UNAUTHORIZED, "Missing authorization token".to_string()),
            AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "Invalid token".to_string()),
            AuthError::ExpiredToken => (StatusCode::UNAUTHORIZED, "Token expired".to_string()),
            AuthError::RevokedToken => (StatusCode::UNAUTHORIZED, "Token revoked".to_string()),
            AuthError::InsufficientRole { required, actual } => (
                StatusCode::FORBIDDEN,
                format!("Insufficient role. Required: {:?}, Actual: {:?}", required, actual),
            ),
        };
        (status, body).into_response()
    }
}

impl From<JwtAuthError> for AuthError {
    fn from(err: JwtAuthError) -> Self {
        match err {
            JwtAuthError::InvalidSignature => AuthError::InvalidToken,
            JwtAuthError::Expired => AuthError::ExpiredToken,
            JwtAuthError::Revoked => AuthError::RevokedToken,
            _ => AuthError::InvalidToken,
        }
    }
}

// ============================================================
// Extractor for AuthenticatedUser (any authenticated user)
// ============================================================

#[async_trait]
impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        // Extract token from Authorization header
        let auth_header = parts
            .headers
            .get("authorization")
            .and_then(|h| h.to_str().ok())
            .ok_or(AuthError::MissingToken)?;
        
        if !auth_header.starts_with("Bearer ") {
            return Err(AuthError::InvalidToken);
        }
        
        let token = &auth_header[7..];
        
        // Get revocation list from state (if available)
        let revocation_list = HashSet::new(); // In production, fetch from DB
        
        let claims = validate_token(token, &revocation_list).map_err(AuthError::from)?;
        let role = claims.role;
        
        Ok(AuthenticatedUser {
            member_id: claims.sub,
            claims,
            role,
        })
    }
}

// ============================================================
// Extractor for Optional Authenticated User (public endpoints)
// ============================================================

#[derive(Debug, Clone)]
pub struct OptionalAuthUser(pub Option<AuthenticatedUser>);

#[async_trait]
impl<S> FromRequestParts<S> for OptionalAuthUser
where
    S: Send + Sync,
{
    type Rejection = ();

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        match AuthenticatedUser::from_request_parts(parts, state).await {
            Ok(user) => Ok(OptionalAuthUser(Some(user))),
            Err(_) => Ok(OptionalAuthUser(None)),
        }
    }
}

// ============================================================
// Role Guard Middleware
// ============================================================

/// Require a specific minimum role
pub struct RequireRole(pub Role);

#[async_trait]
impl<S> FromRequestParts<S> for RequireRole
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let user = AuthenticatedUser::from_request_parts(parts, state).await?;
        
        if user.role.level() > user.role.level() {
            return Err(AuthError::InsufficientRole {
                required: user.role,
                actual: user.role,
            });
        }
        
        Ok(RequireRole(user.role))
    }
}

/// Helper to check role in handlers
pub fn check_role(actual: Role, required: Role) -> Result<(), AuthError> {
    if actual.level() <= required.level() {
        Ok(())
    } else {
        Err(AuthError::InsufficientRole { required, actual })
    }
}