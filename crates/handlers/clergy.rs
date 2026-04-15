use axum::{
    Json, extract::{Path, State}, http::StatusCode,
};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::{Utc, DateTime};
use crate::db::DbPool;
use crate::auth::AuthenticatedUser;

// ============================================================
// Request/Response Models
// ============================================================

#[derive(Debug, Serialize, Deserialize)]
pub struct PickupPoint {
    pub id: String,
    pub branch_id: String,
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub pickup_time: String,
    pub transport_manager_name: Option<String>,
    pub transport_manager_phone: Option<String>,
    pub is_active: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreatePickupPointRequest {
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub pickup_time: String,
    pub transport_manager_name: Option<String>,
    pub transport_manager_phone: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdatePickupPointRequest {
    pub name: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub pickup_time: Option<String>,
    pub transport_manager_name: Option<String>,
    pub transport_manager_phone: Option<String>,
    pub is_active: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Event {
    pub id: String,
    pub branch_id: String,
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub event_date: i64,
    pub description: Option<String>,
    pub is_active: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateEventRequest {
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub event_date: i64,
    pub description: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Alert {
    pub id: String,
    pub branch_id: String,
    pub message: String,
    pub affected_service: Option<String>,
    pub expires_at: i64,
    pub is_active: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateAlertRequest {
    pub message: String,
    pub affected_service: Option<String>,
    pub expires_at: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateBranchRequest {
    pub name: Option<String>,
    pub address: Option<String>,
    pub senior_pastor: Option<String>,
    pub phone: Option<String>,
    pub email: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateServiceTimesRequest {
    pub service_times: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub otp: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LoginResponse {
    pub token: String,
    pub branch_id: String,
    pub name: String,
}

// ============================================================
// Pickup Points Handlers
// ============================================================

pub async fn get_pickup_points(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
) -> Json<Vec<PickupPoint>> {
    let conn = pool.get().unwrap();
    let mut stmt = conn.prepare(
        "SELECT id, branch_id, name, latitude, longitude, pickup_time, 
         transport_manager_name, transport_manager_phone, is_active 
         FROM pickup_points WHERE branch_id = ?1 AND is_active = 1"
    ).unwrap();
    
    let rows = stmt.query_map([branch_id], |row| {
        Ok(PickupPoint {
            id: row.get(0)?,
            branch_id: row.get(1)?,
            name: row.get(2)?,
            latitude: row.get(3)?,
            longitude: row.get(4)?,
            pickup_time: row.get(5)?,
            transport_manager_name: row.get(6)?,
            transport_manager_phone: row.get(7)?,
            is_active: row.get(8)?,
        })
    }).unwrap();
    
    let points: Vec<PickupPoint> = rows.map(|r| r.unwrap()).collect();
    Json(points)
}

pub async fn create_pickup_point(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
    Json(req): Json<CreatePickupPointRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    
    conn.execute(
        "INSERT INTO pickup_points (id, branch_id, name, latitude, longitude, pickup_time, 
         transport_manager_name, transport_manager_phone, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?9)",
        [
            &id, &branch_id, &req.name, &req.latitude, &req.longitude,
            &req.pickup_time, &req.transport_manager_name, &req.transport_manager_phone,
            &now
        ],
    ).unwrap();
    
    StatusCode::CREATED
}

pub async fn update_pickup_point(
    State(pool): State<DbPool>,
    Path((branch_id, point_id)): Path<(String, String)>,
    Json(req): Json<UpdatePickupPointRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    
    let mut updates = Vec::new();
    let mut params: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
    
    if let Some(name) = req.name {
        updates.push("name = ?");
        params.push(Box::new(name));
    }
    if let Some(latitude) = req.latitude {
        updates.push("latitude = ?");
        params.push(Box::new(latitude));
    }
    if let Some(longitude) = req.longitude {
        updates.push("longitude = ?");
        params.push(Box::new(longitude));
    }
    if let Some(pickup_time) = req.pickup_time {
        updates.push("pickup_time = ?");
        params.push(Box::new(pickup_time));
    }
    if let Some(name) = req.transport_manager_name {
        updates.push("transport_manager_name = ?");
        params.push(Box::new(name));
    }
    if let Some(phone) = req.transport_manager_phone {
        updates.push("transport_manager_phone = ?");
        params.push(Box::new(phone));
    }
    if let Some(is_active) = req.is_active {
        updates.push("is_active = ?");
        params.push(Box::new(is_active));
    }
    
    updates.push("updated_at = ?");
    params.push(Box::new(now));
    params.push(Box::new(point_id));
    params.push(Box::new(branch_id));
    
    let query = format!(
        "UPDATE pickup_points SET {} WHERE id = ? AND branch_id = ?",
        updates.join(", ")
    );
    
    conn.execute(&query, rusqlite::params_from_iter(params)).unwrap();
    StatusCode::OK
}

pub async fn delete_pickup_point(
    State(pool): State<DbPool>,
    Path((branch_id, point_id)): Path<(String, String)>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    conn.execute(
        "DELETE FROM pickup_points WHERE id = ?1 AND branch_id = ?2",
        [point_id, branch_id],
    ).unwrap();
    StatusCode::OK
}

// ============================================================
// Events Handlers
// ============================================================

pub async fn get_events(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
) -> Json<Vec<Event>> {
    let conn = pool.get().unwrap();
    let mut stmt = conn.prepare(
        "SELECT id, branch_id, name, latitude, longitude, event_date, description, is_active 
         FROM events WHERE branch_id = ?1 AND is_active = 1 AND event_date > ?2
         ORDER BY event_date"
    ).unwrap();
    
    let now = Utc::now().timestamp();
    
    let rows = stmt.query_map([branch_id, now], |row| {
        Ok(Event {
            id: row.get(0)?,
            branch_id: row.get(1)?,
            name: row.get(2)?,
            latitude: row.get(3)?,
            longitude: row.get(4)?,
            event_date: row.get(5)?,
            description: row.get(6)?,
            is_active: row.get(7)?,
        })
    }).unwrap();
    
    let events: Vec<Event> = rows.map(|r| r.unwrap()).collect();
    Json(events)
}

pub async fn create_event(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
    Json(req): Json<CreateEventRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    
    conn.execute(
        "INSERT INTO events (id, branch_id, name, latitude, longitude, event_date, description, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8)",
        [
            &id, &branch_id, &req.name, &req.latitude, &req.longitude,
            &req.event_date, &req.description, &now
        ],
    ).unwrap();
    
    StatusCode::CREATED
}

pub async fn delete_event(
    State(pool): State<DbPool>,
    Path((branch_id, event_id)): Path<(String, String)>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    conn.execute(
        "DELETE FROM events WHERE id = ?1 AND branch_id = ?2",
        [event_id, branch_id],
    ).unwrap();
    StatusCode::OK
}

// ============================================================
// Alerts Handlers
// ============================================================

pub async fn get_alerts(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
) -> Json<Vec<Alert>> {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    
    let mut stmt = conn.prepare(
        "SELECT id, branch_id, message, affected_service, expires_at, is_active 
         FROM alerts WHERE branch_id = ?1 AND is_active = 1 AND expires_at > ?2"
    ).unwrap();
    
    let rows = stmt.query_map([branch_id, now], |row| {
        Ok(Alert {
            id: row.get(0)?,
            branch_id: row.get(1)?,
            message: row.get(2)?,
            affected_service: row.get(3)?,
            expires_at: row.get(4)?,
            is_active: row.get(5)?,
        })
    }).unwrap();
    
    let alerts: Vec<Alert> = rows.map(|r| r.unwrap()).collect();
    Json(alerts)
}

pub async fn create_alert(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
    Json(req): Json<CreateAlertRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    
    conn.execute(
        "INSERT INTO alerts (id, branch_id, message, affected_service, expires_at, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)",
        [
            &id, &branch_id, &req.message, &req.affected_service,
            &req.expires_at, &now
        ],
    ).unwrap();
    
    StatusCode::CREATED
}

pub async fn delete_alert(
    State(pool): State<DbPool>,
    Path((branch_id, alert_id)): Path<(String, String)>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    conn.execute(
        "DELETE FROM alerts WHERE id = ?1 AND branch_id = ?2",
        [alert_id, branch_id],
    ).unwrap();
    StatusCode::OK
}

// ============================================================
// Branch Management Handlers
// ============================================================

pub async fn update_branch(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
    Json(req): Json<UpdateBranchRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    
    let mut updates = Vec::new();
    let mut params: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
    
    if let Some(name) = req.name {
        updates.push("name = ?");
        params.push(Box::new(name));
    }
    if let Some(address) = req.address {
        updates.push("address = ?");
        params.push(Box::new(address));
    }
    if let Some(pastor) = req.senior_pastor {
        updates.push("senior_pastor = ?");
        params.push(Box::new(pastor));
    }
    if let Some(phone) = req.phone {
        updates.push("phone = ?");
        params.push(Box::new(phone));
    }
    if let Some(email) = req.email {
        updates.push("email = ?");
        params.push(Box::new(email));
    }
    
    if updates.is_empty() {
        return StatusCode::BAD_REQUEST;
    }
    
    updates.push("last_updated = ?");
    params.push(Box::new(now));
    params.push(Box::new(branch_id));
    
    let query = format!(
        "UPDATE branches SET {} WHERE id = ?",
        updates.join(", ")
    );
    
    conn.execute(&query, rusqlite::params_from_iter(params)).unwrap();
    StatusCode::OK
}

pub async fn update_service_times(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
    Json(req): Json<UpdateServiceTimesRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    
    conn.execute(
        "UPDATE branches SET service_times = ?1, last_updated = ?2 WHERE id = ?3",
        [&req.service_times.to_string(), &now, &branch_id],
    ).unwrap();
    
    StatusCode::OK
}

// ============================================================
// Photo Handlers
// ============================================================

pub async fn get_photos(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
) -> Json<Vec<String>> {
    let conn = pool.get().unwrap();
    let mut stmt = conn.prepare(
        "SELECT url FROM photos WHERE branch_id = ?1 ORDER BY created_at DESC"
    ).unwrap();
    
    let rows = stmt.query_map([branch_id], |row| {
        Ok(row.get::<_, String>(0)?)
    }).unwrap();
    
    let urls: Vec<String> = rows.map(|r| r.unwrap()).collect();
    Json(urls)
}

pub async fn add_photo(
    State(pool): State<DbPool>,
    Path(branch_id): Path<String>,
    Json(req): Json<serde_json::Value>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    let url = req["url"].as_str().unwrap_or("");
    
    conn.execute(
        "INSERT INTO photos (id, branch_id, url, created_at) VALUES (?1, ?2, ?3, ?4)",
        [&id, &branch_id, &url, &now],
    ).unwrap();
    
    StatusCode::CREATED
}

pub async fn delete_photo(
    State(pool): State<DbPool>,
    Path((branch_id, photo_url)): Path<(String, String)>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    // URL decode the parameter (it comes URL-encoded)
    let decoded_url = urlencoding::decode(&photo_url).unwrap_or_else(|_| photo_url.into());
    
    conn.execute(
        "DELETE FROM photos WHERE branch_id = ?1 AND url = ?2",
        [branch_id, &decoded_url.to_string()],
    ).unwrap();
    
    StatusCode::OK
}

// ============================================================
// Authentication Handlers
// ============================================================

pub async fn login(
    State(pool): State<DbPool>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, StatusCode> {
    let conn = pool.get().unwrap();
    
    // For now, accept any OTP "123456" for testing
    if req.otp != "123456" {
        return Err(StatusCode::UNAUTHORIZED);
    }
    
    let mut stmt = conn.prepare(
        "SELECT branch_id, name FROM clergy_users WHERE email = ?1"
    ).unwrap();
    
    let result = stmt.query_row([req.email], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
    });
    
    match result {
        Ok((branch_id, name)) => {
            Ok(Json(LoginResponse {
                token: "test_token_123".to_string(),
                branch_id,
                name,
            }))
        }
        Err(_) => Err(StatusCode::UNAUTHORIZED),
    }
}