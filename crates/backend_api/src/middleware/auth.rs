//! Authentication middleware for Axum

use axum::{
    async_trait,
    extract::{FromRequestParts, RequestParts},
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
};
use std::sync::Arc;
use crate::auth::{TokenClaims, validate_token, Role, check_role};
use crate::models::TokenConstraints;

/// Authenticated user extracted from JWT
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub claims: TokenClaims,
    pub member_id: uuid::Uuid,
    pub role: Role,
    pub constraints: TokenConstraints,
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
            AuthError::MissingToken => (StatusCode::UNAUTHORIZED, "Missing authorization token"),
            AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "Invalid token"),
            AuthError::ExpiredToken => (StatusCode::UNAUTHORIZED, "Token expired"),
            AuthError::RevokedToken => (StatusCode::UNAUTHORIZED, "Token revoked"),
            AuthError::InsufficientRole { required } => (
                StatusCode::FORBIDDEN,
                &format!("Insufficient role. Required: {:?}", required),
            ),
        };
        (status, body).into_response()
    }
}

impl From<super::super::auth::AuthError> for AuthError {
    fn from(err: super::super::auth::AuthError) -> Self {
        match err {
            super::super::auth::AuthError::InvalidSignature => AuthError::InvalidToken,
            super::super::auth::AuthError::Expired => AuthError::ExpiredToken,
            super::super::auth::AuthError::Revoked => AuthError::RevokedToken,
            _ => AuthError::InvalidToken,
        }
    }
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
        
        // In production, fetch revocation list from DB
        let revocation_list = vec![];
        
        let claims = validate_token(token, &revocation_list).map_err(|e| {
            match e {
                super::super::auth::AuthError::Expired => AuthError::ExpiredToken,
                super::super::auth::AuthError::Revoked => AuthError::RevokedToken,
                _ => AuthError::InvalidToken,
            }
        })?;
        
        // Check role requirement (parsed from parts)
        // For now, assume minimum role is Usher
        let required_role = Role::Usher;
        check_role(&claims, required_role).map_err(|_| AuthError::InsufficientRole { required: required_role })?;
        
        Ok(RequireRole(required_role))
    }
}

/// Extractor that provides full authenticated user
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
        let revocation_list = vec![];
        
        let claims = validate_token(token, &revocation_list).map_err(AuthError::from)?;
        let role: Role = claims.role.as_str().into();
        
        Ok(AuthenticatedUser {
            member_id: claims.sub,
            claims,
            role,
            constraints: claims.constraints.clone(),
        })
    }
}