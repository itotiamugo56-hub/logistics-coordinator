//! Authentication endpoints

use axum::Json;
use crate::models::{TokenRequest, TokenResponse};
use crate::auth::{issue_token, Role, TokenConstraints};
use jsonwebtoken::{encode, Header, EncodingKey, Algorithm};
use serde::{Serialize, Deserialize};
use chrono::{Utc, Duration};
use uuid::Uuid;

/// Simple test token claims (for development)
#[derive(Debug, Serialize, Deserialize)]
struct TestClaims {
    sub: String,
    exp: usize,
    iat: usize,
    role: String,
}

pub async fn issue_token_handler(
    Json(req): Json<TokenRequest>,
) -> Json<TokenResponse> {
    // For testing, create a simple valid JWT
    let now = Utc::now();
    let exp = (now + Duration::seconds(req.expires_in_seconds as i64)).timestamp() as usize;
    let iat = now.timestamp() as usize;
    
    let claims = TestClaims {
        sub: req.subject_member_id.to_string(),
        exp,
        iat,
        role: req.delegate_to_role.clone(),
    };
    
    // Create a valid JWT (using HS256 for simplicity in tests)
    let token = encode(
        &Header::new(Algorithm::HS256),
        &claims,
        &EncodingKey::from_secret(b"test_secret_key_123"),
    ).unwrap_or_else(|_| "invalid.token".to_string());
    
    Json(TokenResponse {
        access_token: token,
        token_jti: Uuid::new_v4(),
        expires_at: now + Duration::seconds(req.expires_in_seconds as i64),
        refresh_limit: 3,
    })
}