//! Authentication handler functions

use axum::{Json, http::StatusCode, extract::State};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::Utc;
use sqlite_embedded::Pool;

use crate::auth::jwt::{issue_token, TokenConstraints, VerificationStatus};
use crate::auth::roles::Role;

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub otp: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub access_token: String,
    pub expires_in: i64,
    pub member_id: Uuid,
    pub role: Role,
    pub name: String,
}

#[derive(Debug, Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub token_jti: Uuid,
    pub expires_at: chrono::DateTime<Utc>,
    pub refresh_limit: u32,
}

#[derive(Debug, Deserialize)]
pub struct TokenRequest {
    pub subject_member_id: Uuid,
    pub delegate_to_role: Role,
    pub expires_in_seconds: i64,
}

pub async fn login(
    State(pool): State<Pool>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    // Check if OTP is valid (for demo, accept 123456)
    if req.otp != "123456" {
        return Err(StatusCode::UNAUTHORIZED);
    }
    
    // Find user in clergy_users table
    let mut stmt = conn.prepare(
        "SELECT branch_id, name FROM clergy_users WHERE email = ?1"
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let result = stmt.query_row([&req.email], |row| {
        let branch_id: String = row.get(0)?;
        let name: String = row.get(1)?;
        Ok((branch_id, name))
    });
    
    let (branch_id, name) = match result {
        Ok((id, name)) => (id, name),
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };
    
    // Parse branch_id as Uuid
    let member_id = Uuid::parse_str(&branch_id).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    // Issue token
    let token = issue_token(
        member_id,
        Role::BranchStaff,
        TokenConstraints::default(),
        vec![],
        VerificationStatus::FullyVerified,
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(Json(LoginResponse {
        access_token: token,
        expires_in: 86400, // 24 hours
        member_id,
        role: Role::BranchStaff,
        name,
    }))
}

pub async fn get_me(
    auth_user: crate::middleware::auth::AuthenticatedUser,
) -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "member_id": auth_user.member_id,
        "role": auth_user.role.to_string(),
        "verification_status": format!("{:?}", auth_user.claims.verification_status),
        "expires_at": auth_user.claims.exp,
    }))
}

pub async fn issue_token_handler(
    Json(req): Json<TokenRequest>,
) -> Result<Json<TokenResponse>, StatusCode> {
    let token = issue_token(
        req.subject_member_id,
        req.delegate_to_role,
        TokenConstraints::default(),
        vec![],
        VerificationStatus::FullyVerified,
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(Json(TokenResponse {
        access_token: token,
        token_jti: Uuid::new_v4(),
        expires_at: Utc::now() + chrono::Duration::seconds(req.expires_in_seconds),
        refresh_limit: 3,
    }))
}