use axum::{
    Json, extract::{Path, State}, http::StatusCode,
};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::Utc;
use r2d2_sqlite::rusqlite;
use sqlite_embedded::Pool;

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
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
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
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
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
// Branch Management Models
// ============================================================

#[derive(Debug, Serialize, Deserialize)]
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

#[derive(Debug, Serialize, Deserialize)]
pub struct BranchResponse {
    pub id: String,
    pub message: String,
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

// ============================================================
// Photo Management Models
// ============================================================

#[derive(Debug, Serialize, Deserialize)]
pub struct AddPhotoRequest {
    pub url: String,
}

// ============================================================
// Login Handler
// ============================================================

pub async fn login(
    State(pool): State<Pool>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR).unwrap();
    
    if req.otp != "123456" {
        return Err(StatusCode::UNAUTHORIZED);
    }
    
    let mut stmt = conn.prepare(
        "SELECT branch_id, name FROM clergy_users WHERE email = ?1"
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR).unwrap();
    
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

// ============================================================
// Branch Creation Handler - UPDATED with is_verified = 1 and branch_clergy_id
// ============================================================

pub async fn create_branch(
    State(pool): State<Pool>,
    Json(req): Json<CreateBranchRequest>,
) -> Result<Json<BranchResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR).unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    let phone = req.phone.as_deref().unwrap_or("");
    let email = req.email.as_deref().unwrap_or("");
    let service_times = req.service_times.clone().unwrap_or(serde_json::json!({}));
    
    // Note: branch_clergy_id will be set by the caller (the authenticated clergy's ID)
    // For now, we leave it as empty string; the caller should update it after creation
    let branch_clergy_id = "";
    
    let result = conn.execute(
        "INSERT INTO branches (id, name, address, latitude, longitude, senior_pastor, phone, email, 
                               service_times, is_verified, branch_clergy_id, created_at, updated_at, last_updated)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 1, ?10, ?11, ?11, ?11)",
        [
            &id, &req.name, &req.address, &req.latitude.to_string(), &req.longitude.to_string(),
            &req.senior_pastor, phone, email, &service_times.to_string(),
            branch_clergy_id, &now_str
        ],
    );
    
    match result {
        Ok(_) => Ok(Json(BranchResponse {
            id,
            message: "Branch created successfully".to_string(),
        })),
        Err(e) => {
            eprintln!("Error creating branch: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// ============================================================
// Pickup Points Handlers
// ============================================================

pub async fn get_pickup_points(
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
) -> Json<Vec<PickupPoint>> {
    let conn = pool.get().unwrap();
    
    let table_check: Result<i64, _> = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='pickup_points'",
        [],
        |row| row.get(0),
    );
    
    if table_check.is_err() || table_check.unwrap_or(0) == 0 {
        return Json(vec![]);
    }
    
    let mut stmt = match conn.prepare(
        "SELECT id, branch_id, name, latitude, longitude, pickup_time, 
         transport_manager_name, transport_manager_phone, is_active 
         FROM pickup_points WHERE branch_id = ?1 AND is_active = 1"
    ) {
        Ok(s) => s,
        Err(_) => return Json(vec![]),
    };
    
    let rows = stmt.query_map([branch_id], |row| {
        // Handle NULL latitude/longitude from database (REAL columns)
        let latitude: Option<f64> = row.get(3)?;
        let longitude: Option<f64> = row.get(4)?;
        
        Ok(PickupPoint {
            id: row.get(0)?,
            branch_id: row.get(1)?,
            name: row.get(2)?,
            latitude: latitude.unwrap_or(0.0),
            longitude: longitude.unwrap_or(0.0),
            pickup_time: row.get(5)?,
            transport_manager_name: row.get(6)?,
            transport_manager_phone: row.get(7)?,
            is_active: row.get(8)?,
        })
    });
    
    match rows {
        Ok(rows_iter) => {
            let points: Vec<PickupPoint> = rows_iter.filter_map(|r| r.ok()).collect();
            Json(points)
        }
        Err(_) => Json(vec![]),
    }
}

pub async fn create_pickup_point(
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
    Json(req): Json<CreatePickupPointRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    let manager_name = req.transport_manager_name.as_deref().unwrap_or("");
    let manager_phone = req.transport_manager_phone.as_deref().unwrap_or("");
    
    let latitude_str = match req.latitude {
        Some(lat) => lat.to_string(),
        None => "0".to_string(),
    };
    
    let longitude_str = match req.longitude {
        Some(lng) => lng.to_string(),
        None => "0".to_string(),
    };
    
    let result = conn.execute(
        "INSERT INTO pickup_points (id, branch_id, name, latitude, longitude, pickup_time, 
         transport_manager_name, transport_manager_phone, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?9)",
        [
            &id, &branch_id, &req.name, &latitude_str, &longitude_str,
            &req.pickup_time, manager_name, manager_phone,
            &now_str
        ],
    );
    
    match result {
        Ok(_) => StatusCode::CREATED,
        Err(_) => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

pub async fn update_pickup_point(
    State(pool): State<Pool>,
    Path((branch_id, point_id)): Path<(String, String)>,
    Json(req): Json<UpdatePickupPointRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    let mut updates = Vec::new();
    let mut params: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
    
    if let Some(name) = req.name {
        updates.push("name = ?");
        params.push(Box::new(name));
    }
    if let Some(latitude) = req.latitude {
        updates.push("latitude = ?");
        params.push(Box::new(latitude.to_string()));
    }
    if let Some(longitude) = req.longitude {
        updates.push("longitude = ?");
        params.push(Box::new(longitude.to_string()));
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
    
    if updates.is_empty() {
        return StatusCode::BAD_REQUEST;
    }
    
    updates.push("updated_at = ?");
    params.push(Box::new(now_str));
    params.push(Box::new(point_id));
    params.push(Box::new(branch_id));
    
    let query = format!(
        "UPDATE pickup_points SET {} WHERE id = ? AND branch_id = ?",
        updates.join(", ")
    );
    
    match conn.execute(&query, rusqlite::params_from_iter(params)) {
        Ok(_) => StatusCode::OK,
        Err(_) => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

pub async fn delete_pickup_point(
    State(pool): State<Pool>,
    Path((branch_id, point_id)): Path<(String, String)>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    match conn.execute(
        "DELETE FROM pickup_points WHERE id = ?1 AND branch_id = ?2",
        [point_id, branch_id],
    ) {
        Ok(_) => StatusCode::OK,
        Err(_) => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

// ============================================================
// Events Handlers
// ============================================================

pub async fn get_events(
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
) -> Json<Vec<Event>> {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    let mut stmt = conn.prepare(
        "SELECT id, branch_id, name, latitude, longitude, event_date, description, is_active 
         FROM events WHERE branch_id = ?1 AND is_active = 1 AND event_date > ?2
         ORDER BY event_date"
    ).unwrap();
    
    let rows = stmt.query_map([branch_id, now_str], |row| {
        // Handle NULL latitude/longitude from database (REAL columns)
        let latitude: Option<f64> = row.get(3)?;
        let longitude: Option<f64> = row.get(4)?;
        
        Ok(Event {
            id: row.get(0)?,
            branch_id: row.get(1)?,
            name: row.get(2)?,
            latitude: latitude.unwrap_or(0.0),
            longitude: longitude.unwrap_or(0.0),
            event_date: row.get(5)?,
            description: row.get(6)?,
            is_active: row.get(7)?,
        })
    }).unwrap();
    
    let events: Vec<Event> = rows.map(|r| r.unwrap()).collect();
    Json(events)
}

pub async fn create_event(
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
    Json(req): Json<CreateEventRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    let description = req.description.as_deref().unwrap_or("");
    
    let latitude_str = match req.latitude {
        Some(lat) => lat.to_string(),
        None => "0".to_string(),
    };
    
    let longitude_str = match req.longitude {
        Some(lng) => lng.to_string(),
        None => "0".to_string(),
    };
    
    conn.execute(
        "INSERT INTO events (id, branch_id, name, latitude, longitude, event_date, description, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8)",
        [
            &id, &branch_id, &req.name, &latitude_str, &longitude_str,
            &req.event_date.to_string(), &description.to_string(), &now_str
        ],
    ).unwrap();
    
    StatusCode::CREATED
}

pub async fn delete_event(
    State(pool): State<Pool>,
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
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
) -> Json<Vec<Alert>> {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    let mut stmt = conn.prepare(
        "SELECT id, branch_id, message, affected_service, expires_at, is_active 
         FROM alerts WHERE branch_id = ?1 AND is_active = 1 AND expires_at > ?2"
    ).unwrap();
    
    let rows = stmt.query_map([branch_id, now_str], |row| {
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
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
    Json(req): Json<CreateAlertRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    let expires_at_str = req.expires_at.to_string();
    let now_str = now.to_string();
    
    let affected_service_value = req.affected_service.as_deref().unwrap_or("");
    
    conn.execute(
        "INSERT INTO alerts (id, branch_id, message, affected_service, expires_at, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)",
        [
            &id, &branch_id, &req.message, affected_service_value,
            &expires_at_str, &now_str
        ],
    ).unwrap();
    
    StatusCode::CREATED
}

pub async fn delete_alert(
    State(pool): State<Pool>,
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
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
    Json(req): Json<UpdateBranchRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
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
    params.push(Box::new(now_str));
    params.push(Box::new(branch_id));
    
    let query = format!(
        "UPDATE branches SET {} WHERE id = ?",
        updates.join(", ")
    );
    
    conn.execute(&query, rusqlite::params_from_iter(params)).unwrap();
    StatusCode::OK
}

pub async fn update_service_times(
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
    Json(req): Json<UpdateServiceTimesRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    conn.execute(
        "UPDATE branches SET service_times = ?1, last_updated = ?2 WHERE id = ?3",
        [&req.service_times.to_string(), &now_str, &branch_id],
    ).unwrap();
    
    StatusCode::OK
}

// ============================================================
// Photo Management Handlers
// ============================================================

pub async fn add_photo(
    State(pool): State<Pool>,
    Path(branch_id): Path<String>,
    Json(req): Json<AddPhotoRequest>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    let now_str = now.to_string();
    
    conn.execute(
        "INSERT INTO photos (id, branch_id, url, created_at) VALUES (?1, ?2, ?3, ?4)",
        [&id, &branch_id, &req.url, &now_str],
    ).unwrap();
    
    StatusCode::CREATED
}

pub async fn get_photos(
    State(pool): State<Pool>,
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

pub async fn delete_photo(
    State(pool): State<Pool>,
    Path((branch_id, photo_url)): Path<(String, String)>,
) -> StatusCode {
    let conn = pool.get().unwrap();
    conn.execute(
        "DELETE FROM photos WHERE branch_id = ?1 AND url = ?2",
        [branch_id, photo_url],
    ).unwrap();
    StatusCode::OK
}