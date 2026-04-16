//! Public branch endpoints (no authentication required)

use axum::{Json, extract::State};
use serde::{Serialize, Deserialize};
use sqlite_embedded::{DbPool, get_connection};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BranchResponse {
    pub id: String,
    pub name: String,
    pub address: String,
    pub latitude: f64,
    pub longitude: f64,
    pub senior_pastor: String,
    pub phone: String,
    pub email: String,
    pub service_times: serde_json::Value,
    pub announcement: Option<String>,
    pub is_verified: bool,
    pub last_updated: i64,
    pub branch_clergy_id: Option<String>,  // NEW: Links branch to assigned clergy
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NearbyRequest {
    pub latitude: f64,
    pub longitude: f64,
    pub radius_km: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateBranchRequest {
    pub name: String,
    pub address: String,
    pub latitude: f64,
    pub longitude: f64,
    pub senior_pastor: String,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub service_times: Option<serde_json::Value>,
}

/// Get all branches (public - no auth)
pub async fn get_all_branches(
    State(pool): State<DbPool>,
) -> Json<Vec<BranchResponse>> {
    let conn = get_connection(&pool).unwrap();
    
    let mut stmt = conn.prepare(
        "SELECT id, name, address, latitude, longitude, senior_pastor, phone, email, 
                service_times, announcement, is_verified, last_updated, branch_clergy_id 
         FROM branches WHERE is_verified = 1"
    ).unwrap();
    
    let rows = stmt.query_map([], |row| {
        // Read id as String (since your database stores it as TEXT)
        let id: String = row.get(0)?;
        
        Ok(BranchResponse {
            id,
            name: row.get(1)?,
            address: row.get(2)?,
            latitude: row.get(3)?,
            longitude: row.get(4)?,
            senior_pastor: row.get(5)?,
            phone: row.get(6)?,
            email: row.get(7)?,
            service_times: serde_json::from_str(&row.get::<_, String>(8)?).unwrap_or(serde_json::json!({})),
            announcement: row.get(9)?,
            is_verified: row.get(10)?,
            last_updated: row.get(11)?,
            branch_clergy_id: row.get(12)?,  // NEW
        })
    }).unwrap();
    
    let mut branches = Vec::new();
    for row in rows {
        branches.push(row.unwrap());
    }
    
    Json(branches)
}

/// Get nearby branches (public - no auth)
pub async fn get_nearby_branches(
    State(pool): State<DbPool>,
    Json(_req): Json<NearbyRequest>,
) -> Json<Vec<BranchResponse>> {
    let conn = get_connection(&pool).unwrap();
    
    let mut stmt = conn.prepare(
        "SELECT id, name, address, latitude, longitude, senior_pastor, phone, email,
                service_times, announcement, is_verified, last_updated, branch_clergy_id
         FROM branches 
         WHERE is_verified = 1"
    ).unwrap();
    
    let rows = stmt.query_map([], |row| {
        let id: String = row.get(0)?;
        
        Ok(BranchResponse {
            id,
            name: row.get(1)?,
            address: row.get(2)?,
            latitude: row.get(3)?,
            longitude: row.get(4)?,
            senior_pastor: row.get(5)?,
            phone: row.get(6)?,
            email: row.get(7)?,
            service_times: serde_json::from_str(&row.get::<_, String>(8)?).unwrap_or(serde_json::json!({})),
            announcement: row.get(9)?,
            is_verified: row.get(10)?,
            last_updated: row.get(11)?,
            branch_clergy_id: row.get(12)?,  // NEW
        })
    }).unwrap();
    
    let mut branches = Vec::new();
    for row in rows {
        branches.push(row.unwrap());
    }
    
    Json(branches)
}