//! Authentication endpoints - Registration, Login, Token Management

use axum::{Json, http::StatusCode, extract::State};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::{Utc, Duration};
use sqlite_embedded::Pool;

use crate::auth::{
    issue_token, issue_temp_token, validate_token,
    TokenConstraints, VerificationStatus, Role, token_lifetime,
};
use crate::middleware::auth::OptionalAuthUser;

// ============================================================
// Request/Response Models
// ============================================================

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub name: String,
}

#[derive(Debug, Serialize)]
pub struct RegisterResponse {
    pub member_id: Uuid,
    pub message: String,
    pub verification_status: VerificationStatus,
}

#[derive(Debug, Deserialize)]
pub struct VerifyOtpRequest {
    pub member_id: Uuid,
    pub otp: String,
}

#[derive(Debug, Serialize)]
pub struct VerifyOtpResponse {
    pub access_token: String,
    pub expires_in: i64,
    pub member_id: Uuid,
    pub role: Role,
}

#[derive(Debug, Deserialize)]
pub struct RefreshTokenRequest {
    pub refresh_token: String,
}

#[derive(Debug, Serialize)]
pub struct RefreshTokenResponse {
    pub access_token: String,
    pub expires_in: i64,
}

#[derive(Debug, Deserialize)]
pub struct TokenRequest {
    pub subject_member_id: Uuid,
    pub delegate_to_role: Role,
    pub expires_in_seconds: i64,
}

#[derive(Debug, Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub token_jti: Uuid,
    pub expires_at: chrono::DateTime<Utc>,
    pub refresh_limit: u32,
}

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
    pub role: String,
    pub name: String,
}

// ============================================================
// In-memory OTP storage (in production, use Redis)
// ============================================================
use std::collections::HashMap;
use std::sync::Mutex;
lazy_static::lazy_static! {
    static ref OTP_STORE: Mutex<HashMap<Uuid, (String, i64)>> = Mutex::new(HashMap::new());
}

fn generate_otp() -> String {
    format!("{:06}", rand::random::<u32>() % 1000000)
}

// ============================================================
// Handlers
// ============================================================

/// Universal login for all user types (Clergy, Members)
pub async fn login(
    State(pool): State<Pool>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    println!("🔐 Login attempt - Email: '{}', Password: '{}'", req.email, req.otp);
    
    // First check in clergy_users (Global Admin, Regional Admin, Branch Clergy)
    let mut stmt = conn.prepare(
        "SELECT id, name, role FROM clergy_users WHERE email = ?1 AND password_hash = ?2"
    ).map_err(|e| {
        eprintln!("Failed to prepare statement: {}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    
    let result = stmt.query_row([&req.email, &req.otp], |row| {
        let id: String = row.get(0)?;
        let name: String = row.get(1)?;
        let role: String = row.get(2)?;
        Ok((id, name, role))
    });
    
    match result {
        Ok((id, name, role)) => {
            println!("✅ Clergy login successful: {} ({})", name, role);
            let member_id = Uuid::parse_str(&id).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            let role_enum = Role::from_str(&role);
            let token_lifetime_secs = token_lifetime(&role_enum);
            
            let token = issue_token(
                member_id,
                role_enum,
                TokenConstraints::default(),
                vec![],
                VerificationStatus::FullyVerified,
            ).map_err(|e| {
                eprintln!("Token issuance error: {:?}", e);
                StatusCode::INTERNAL_SERVER_ERROR
            })?;
            
            return Ok(Json(LoginResponse {
                access_token: token,
                expires_in: token_lifetime_secs,
                member_id,
                role: role_enum.to_string(),
                name,
            }));
        }
        Err(e) => {
            println!("❌ Clergy login failed: {}", e);
        }
    }
    
    // Then check in members table (Verified Members)
    let mut stmt = conn.prepare(
        "SELECT id, name FROM members WHERE email = ?1 AND verification_status = 'FullyVerified'"
    ).map_err(|e| {
        eprintln!("Failed to prepare members statement: {}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    
    let result = stmt.query_row([&req.email], |row| {
        let id: String = row.get(0)?;
        let name: String = row.get(1)?;
        Ok((id, name))
    });
    
    match result {
        Ok((id, name)) => {
            println!("✅ Member login successful: {}", name);
            let member_id = Uuid::parse_str(&id).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            let token = issue_token(
                member_id,
                Role::VerifiedMember,
                TokenConstraints::default(),
                vec![],
                VerificationStatus::FullyVerified,
            ).map_err(|e| {
                eprintln!("Token issuance error: {:?}", e);
                StatusCode::INTERNAL_SERVER_ERROR
            })?;
            
            return Ok(Json(LoginResponse {
                access_token: token,
                expires_in: token_lifetime(&Role::VerifiedMember),
                member_id,
                role: "verified_member".to_string(),
                name,
            }));
        }
        Err(e) => {
            println!("❌ Member login failed: {}", e);
        }
    }
    
    println!("❌ Login failed - no match found for email: {}", req.email);
    Err(StatusCode::UNAUTHORIZED)
}

/// Register a new member (unverified)
pub async fn register_member(
    State(pool): State<Pool>,
    Json(req): Json<RegisterRequest>,
) -> Result<Json<RegisterResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let member_id = Uuid::new_v4();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    // Check if email already exists
    let mut stmt = conn.prepare("SELECT id FROM members WHERE email = ?1")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let exists: Result<Uuid, _> = stmt.query_row([&req.email], |row| row.get(0));
    
    if exists.is_ok() {
        return Err(StatusCode::CONFLICT);
    }
    
    // Insert member
    conn.execute(
        "INSERT INTO members (id, email, name, role, verification_status, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)",
        [
            &member_id.to_string(),
            &req.email,
            &req.name,
            "VerifiedMember",
            "Unverified",
            &now_str,
        ],
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    // Generate and store OTP
    let otp = generate_otp();
    let expires_at = now + 300; // 5 minutes
    {
        let mut store = OTP_STORE.lock().unwrap();
        store.insert(member_id, (otp.clone(), expires_at));
    }
    
    // In production, send OTP via email/SMS here
    println!("📧 OTP for {}: {}", req.email, otp);
    
    Ok(Json(RegisterResponse {
        member_id,
        message: "OTP sent to email".to_string(),
        verification_status: VerificationStatus::Unverified,
    }))
}

/// Verify OTP and issue access token
pub async fn verify_otp(
    State(pool): State<Pool>,
    Json(req): Json<VerifyOtpRequest>,
) -> Result<Json<VerifyOtpResponse>, StatusCode> {
    // Verify OTP
    let (stored_otp, expires_at) = {
        let store = OTP_STORE.lock().unwrap();
        store.get(&req.member_id)
            .ok_or(StatusCode::BAD_REQUEST)?
            .clone()
    };
    
    let now = Utc::now().timestamp();
    if now > expires_at {
        return Err(StatusCode::BAD_REQUEST);
    }
    
    if stored_otp != req.otp {
        return Err(StatusCode::UNAUTHORIZED);
    }
    
    // Clear OTP after use
    {
        let mut store = OTP_STORE.lock().unwrap();
        store.remove(&req.member_id);
    }
    
    // Update member verification status
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    conn.execute(
        "UPDATE members SET verification_status = ?1, updated_at = ?2 WHERE id = ?3",
        ["FullyVerified", &Utc::now().timestamp().to_string(), &req.member_id.to_string()],
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    // Issue token
    let token = crate::auth::issue_token(
        req.member_id,
        Role::VerifiedMember,
        TokenConstraints::default(),
        vec![],
        VerificationStatus::FullyVerified,
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(Json(VerifyOtpResponse {
        access_token: token,
        expires_in: 43200, // 12 hours
        member_id: req.member_id,
        role: Role::VerifiedMember,
    }))
}

/// Refresh expired token
pub async fn refresh_token(
    Json(req): Json<RefreshTokenRequest>,
) -> Result<Json<RefreshTokenResponse>, StatusCode> {
    let revocation_list = std::collections::HashSet::new();
    let claims = validate_token(&req.refresh_token, &revocation_list)
        .map_err(|_| StatusCode::UNAUTHORIZED)?;
    
    // Issue new token with same claims
    let new_token = issue_token(
        claims.sub,
        claims.role,
        claims.constraints,
        claims.delegation_chain,
        claims.verification_status,
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(Json(RefreshTokenResponse {
        access_token: new_token,
        expires_in: token_lifetime(&claims.role),
    }))
}

/// Get current user info (protected endpoint example)
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

/// Legacy token issuance handler (kept for compatibility)
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
        expires_at: Utc::now() + Duration::seconds(req.expires_in_seconds),
        refresh_limit: 3,
    }))
}