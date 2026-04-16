//! Admin endpoints - Global Admin and Regional Admin operations

use axum::{Json, http::StatusCode, extract::State};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::Utc;
use sqlite_embedded::Pool;
use r2d2_sqlite::rusqlite;

use crate::auth::roles::Role;

// ============================================================
// Request/Response Models
// ============================================================

#[derive(Debug, Deserialize)]
pub struct CreateRegionalRequest {
    pub email: String,
    pub name: String,
    pub region_name: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct CreateRegionalResponse {
    pub member_id: Uuid,
    pub email: String,
    pub name: String,
    pub role: String,
    pub region_id: Uuid,
    pub region_name: String,
    pub temp_password: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateClergyRequest {
    pub email: String,
    pub name: String,
    pub password: String,
    pub region_id: Option<Uuid>,
}

#[derive(Debug, Serialize)]
pub struct CreateClergyResponse {
    pub member_id: Uuid,
    pub email: String,
    pub name: String,
    pub role: String,
    pub temp_password: String,
}

#[derive(Debug, Serialize)]
pub struct BootstrapResponse {
    pub member_id: Uuid,
    pub email: String,
    pub name: String,
    pub role: String,
    pub temp_password: String,
    pub message: String,
}

// ============================================================
// Bootstrap - First Global Admin (Run once)
// ============================================================

pub async fn bootstrap_admin(
    State(pool): State<Pool>,
) -> Result<Json<BootstrapResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    // Check if any global admin exists
    let mut stmt = conn.prepare("SELECT COUNT(*) FROM clergy_users WHERE role = 'global_admin'")
        .map_err(|e| {
            eprintln!("Error checking admin count: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    
    let count: i64 = stmt.query_row([], |row| row.get(0))
        .map_err(|e| {
            eprintln!("Error reading count: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    
    if count > 0 {
        eprintln!("Global admin already exists");
        return Err(StatusCode::FORBIDDEN);
    }
    
    let member_id = Uuid::new_v4();
    let temp_password = format!("admin{}", rand::random::<u32>() % 10000);
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    let branch_id_placeholder = Uuid::new_v4().to_string(); // Placeholder branch_id
    
    // Create global admin - matching actual schema
    let result = conn.execute(
        "INSERT INTO clergy_users (id, branch_id, email, name, role, password_hash, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        &[
            &member_id.to_string(),
            &branch_id_placeholder,
            "admin@repentance.org",
            "Global Admin",
            "global_admin",
            &temp_password,
            &now_str,
        ],
    );
    
    match result {
        Ok(_) => {
            println!("🔐 BOOTSTRAP ADMIN CREATED");
            println!("   Email: admin@repentance.org");
            println!("   Password: {}", temp_password);
            println!("   PLEASE CHANGE PASSWORD AFTER FIRST LOGIN!");
            
            Ok(Json(BootstrapResponse {
                member_id,
                email: "admin@repentance.org".to_string(),
                name: "Global Admin".to_string(),
                role: "global_admin".to_string(),
                temp_password,
                message: "Bootstrap admin created. Please change password after first login.".to_string(),
            }))
        }
        Err(e) => {
            eprintln!("Error creating bootstrap admin: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// ============================================================
// Global Admin: Create Regional Admin
// ============================================================

pub async fn create_regional_admin(
    auth_user: crate::middleware::auth::AuthenticatedUser,
    State(pool): State<Pool>,
    Json(req): Json<CreateRegionalRequest>,
) -> Result<Json<CreateRegionalResponse>, StatusCode> {
    // Only Global Admin can create Regional Admin
    if auth_user.role != Role::GlobalAdmin {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let member_id = Uuid::new_v4();
    let region_id = Uuid::new_v4();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    let branch_id_placeholder = Uuid::new_v4().to_string();
    
    // Check if email already exists
    let mut stmt = conn.prepare("SELECT id FROM clergy_users WHERE email = ?1")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let exists: Result<String, _> = stmt.query_row([&req.email], |row| row.get(0));
    
    if exists.is_ok() {
        return Err(StatusCode::CONFLICT);
    }
    
    // Create region
    conn.execute(
        "INSERT INTO regions (id, name, created_by, created_at)
         VALUES (?1, ?2, ?3, ?4)",
        [
            &region_id.to_string(),
            &req.region_name,
            &auth_user.member_id.to_string(),
            &now_str,
        ],
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    // Create regional admin
    conn.execute(
        "INSERT INTO clergy_users (id, branch_id, email, name, role, region_id, created_by, password_hash, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        [
            &member_id.to_string(),
            &branch_id_placeholder,
            &req.email,
            &req.name,
            "regional_admin",
            &region_id.to_string(),
            &auth_user.member_id.to_string(),
            &req.password,
            &now_str,
        ],
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    println!("✅ Regional Admin created: {} ({})", req.name, req.email);
    
    Ok(Json(CreateRegionalResponse {
        member_id,
        email: req.email,
        name: req.name,
        role: "regional_admin".to_string(),
        region_id,
        region_name: req.region_name,
        temp_password: req.password,
    }))
}

// ============================================================
// Global/Regional Admin: Create Branch Clergy
// ============================================================

pub async fn create_branch_clergy(
    auth_user: crate::middleware::auth::AuthenticatedUser,
    State(pool): State<Pool>,
    Json(req): Json<CreateClergyRequest>,
) -> Result<Json<CreateClergyResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let member_id = Uuid::new_v4();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    let branch_id_placeholder = Uuid::new_v4().to_string();
    
    // Check if email already exists
    let mut stmt = conn.prepare("SELECT id FROM clergy_users WHERE email = ?1")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let exists: Result<String, _> = stmt.query_row([&req.email], |row| row.get(0));
    
    if exists.is_ok() {
        return Err(StatusCode::CONFLICT);
    }
    
    // Check permissions
    match auth_user.role {
        Role::GlobalAdmin => {
            // Global Admin can create anywhere
            conn.execute(
                "INSERT INTO clergy_users (id, branch_id, email, name, role, created_by, password_hash, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                [
                    &member_id.to_string(),
                    &branch_id_placeholder,
                    &req.email,
                    &req.name,
                    "branch_clergy",
                    &auth_user.member_id.to_string(),
                    &req.password,
                    &now_str,
                ],
            ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        }
        Role::RegionalAdmin => {
            // Regional Admin must have a region
            let region_id = req.region_id.ok_or(StatusCode::BAD_REQUEST)?;
            
            // Verify the regional admin belongs to this region
            let mut stmt = conn.prepare("SELECT region_id FROM clergy_users WHERE id = ?1")
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            let admin_region: Result<String, _> = stmt.query_row([&auth_user.member_id.to_string()], |row| row.get(0));
            
            match admin_region {
                Ok(admin_region_id) => {
                    if admin_region_id != region_id.to_string() {
                        return Err(StatusCode::FORBIDDEN);
                    }
                }
                Err(_) => return Err(StatusCode::FORBIDDEN),
            }
            
            conn.execute(
                "INSERT INTO clergy_users (id, branch_id, email, name, role, region_id, created_by, password_hash, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                [
                    &member_id.to_string(),
                    &branch_id_placeholder,
                    &req.email,
                    &req.name,
                    "branch_clergy",
                    &region_id.to_string(),
                    &auth_user.member_id.to_string(),
                    &req.password,
                    &now_str,
                ],
            ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        }
        _ => return Err(StatusCode::FORBIDDEN),
    }
    
    println!("✅ Branch Clergy created: {} ({}) by {:?}", req.name, req.email, auth_user.role);
    
    Ok(Json(CreateClergyResponse {
        member_id,
        email: req.email,
        name: req.name,
        role: "branch_clergy".to_string(),
        temp_password: req.password,
    }))
}

// ============================================================
// List all clergy (admin only)
// ============================================================

#[derive(Debug, Serialize)]
pub struct ClergyInfo {
    pub id: Uuid,
    pub email: String,
    pub name: String,
    pub role: String,
    pub region_id: Option<Uuid>,
    pub created_by: Option<Uuid>,
    pub created_at: i64,
}

pub async fn list_clergy(
    auth_user: crate::middleware::auth::AuthenticatedUser,
    State(pool): State<Pool>,
) -> Result<Json<Vec<ClergyInfo>>, StatusCode> {
    // Only Global Admin and Regional Admin can list
    if auth_user.role != Role::GlobalAdmin && auth_user.role != Role::RegionalAdmin {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let mut query = String::from("SELECT id, email, name, role, region_id, created_by, created_at FROM clergy_users");
    let mut params: Vec<String> = vec![];
    
    if auth_user.role == Role::RegionalAdmin {
        let mut stmt = conn.prepare("SELECT region_id FROM clergy_users WHERE id = ?1")
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        let region_id: Result<String, _> = stmt.query_row([&auth_user.member_id.to_string()], |row| row.get(0));
        
        if let Ok(region) = region_id {
            query.push_str(" WHERE region_id = ?1");
            params.push(region);
        }
    }
    
    let mut stmt = conn.prepare(&query).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let rows = stmt.query_map(rusqlite::params_from_iter(params), |row| {
        let id_str: String = row.get(0)?;
        let email: String = row.get(1)?;
        let name: String = row.get(2)?;
        let role: String = row.get(3)?;
        let region_id_opt: Option<String> = row.get(4)?;
        let created_by_opt: Option<String> = row.get(5)?;
        let created_at: i64 = row.get(6)?;
        
        // Try to parse as UUID, skip if invalid (like "clergy_001")
        let id_parsed = Uuid::parse_str(&id_str);
        let region_id_parsed = region_id_opt.as_ref().and_then(|s| Uuid::parse_str(s).ok());
        let created_by_parsed = created_by_opt.as_ref().and_then(|s| Uuid::parse_str(s).ok());
        
        if let Ok(id) = id_parsed {
            Ok(ClergyInfo {
                id,
                email,
                name,
                role,
                region_id: region_id_parsed,
                created_by: created_by_parsed,
                created_at,
            })
        } else {
            // Skip records with invalid UUIDs (like "clergy_001")
            Err(rusqlite::Error::InvalidQuery)
        }
    }).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let clergy: Vec<ClergyInfo> = rows.filter_map(|r| r.ok()).collect();
    Ok(Json(clergy))
}