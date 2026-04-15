//! Signal Flare handlers

use axum::{Json, extract::{Path, State}, http::StatusCode};
use uuid::Uuid;
use chrono::Utc;
use serde_json::{json, Value};
use crate::models::{FlareResponse, SimpleFlareSubmission};
use crate::middleware::AuthenticatedUser;

/// Calculate haversine distance between two points (in km)
fn haversine_distance(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    const R: f64 = 6371.0;
    let d_lat = (lat2 - lat1).to_radians();
    let d_lng = (lng2 - lng1).to_radians();
    let a = (d_lat / 2.0).sin() * (d_lat / 2.0).sin()
        + lat1.to_radians().cos()
        * lat2.to_radians().cos()
        * (d_lng / 2.0).sin()
        * (d_lng / 2.0).sin();
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());
    R * c
}

/// Find the nearest branch to the given coordinates
async fn find_nearest_branch(
    lat: f64,
    lng: f64,
    pool: &sqlite_embedded::DbPool,
) -> Result<(String, String), StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let mut stmt = conn.prepare(
        "SELECT id, name, latitude, longitude FROM branches WHERE is_active = 1 AND is_verified = 1"
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let rows = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, f64>(2)?,
            row.get::<_, f64>(3)?,
        ))
    }).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let mut nearest_branch_id = None;
    let mut nearest_branch_name = None;
    let mut min_distance = f64::MAX;
    
    for row in rows {
        if let Ok((id, name, branch_lat, branch_lng)) = row {
            let distance = haversine_distance(lat, lng, branch_lat, branch_lng);
            if distance < min_distance {
                min_distance = distance;
                nearest_branch_id = Some(id);
                nearest_branch_name = Some(name);
            }
        }
    }
    
    match (nearest_branch_id, nearest_branch_name) {
        (Some(id), Some(name)) => Ok((id, name)),
        _ => Err(StatusCode::NOT_FOUND),
    }
}

/// Submit a new Signal Flare (supports both authenticated and anonymous users)
pub async fn submit_flare(
    auth: Option<AuthenticatedUser>,
    State(pool): State<sqlite_embedded::DbPool>,
    Json(req): Json<SimpleFlareSubmission>,
) -> Result<Json<FlareResponse>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let now = Utc::now();
    let now_str = now.timestamp().to_string();
    
    // Find nearest branch to assign this flare to
    let (branch_id, branch_name) = find_nearest_branch(req.lat, req.lng, &pool).await?;
    
    // Generate new flare ID
    let flare_id = Uuid::new_v4();
    
    // Check if user is authenticated or anonymous
    let (member_id, is_anonymous) = match auth {
        Some(user) => (user.member_id.to_string(), false),
        None => {
            // Create anonymous session ID (temporary, not stored in members table)
            (format!("anon_{}", Uuid::new_v4()), true)
        }
    };
    
    // Insert flare into database with branch_id
    let result = conn.execute(
        "INSERT INTO flares (id, member_id, branch_id, latitude, longitude, geohash10, is_anonymous, status, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?9)",
        [
            &flare_id.to_string(),
            &member_id,
            &branch_id,
            &req.lat.to_string(),
            &req.lng.to_string(),
            &req.geohash10,
            &(is_anonymous as i32).to_string(),
            "queued",
            &now_str,
        ],
    );
    
    match result {
        Ok(_) => Ok(Json(FlareResponse {
            flare_id,
            status: "queued".to_string(),
            assigned_branch_id: Some(Uuid::parse_str(&branch_id).unwrap()),
            server_received_time: now,
            retry_queue_position: 0,
            is_anonymous: Some(is_anonymous),
            message: if is_anonymous {
                Some(format!("Flare sent to {}. Create an account to track status.", branch_name))
            } else {
                Some(format!("Flare sent to {}. Clergy notified.", branch_name))
            },
        })),
        Err(e) => {
            eprintln!("Error inserting flare: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

/// Get flare status
pub async fn get_flare_status(
    auth: Option<AuthenticatedUser>,
    State(pool): State<sqlite_embedded::DbPool>,
    Path(flare_id): Path<Uuid>,
) -> Result<Json<Value>, StatusCode> {
    let conn = pool.get().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let flare_id_str = flare_id.to_string();
    
    let mut stmt = conn.prepare(
        "SELECT id, member_id, branch_id, is_anonymous, status, eta_seconds, created_at, updated_at
         FROM flares WHERE id = ?1"
    ).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let flare_result = stmt.query_row([&flare_id_str], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
            row.get::<_, i32>(3)?,
            row.get::<_, String>(4)?,
            row.get::<_, Option<i32>>(5)?,
            row.get::<_, i64>(6)?,
            row.get::<_, i64>(7)?,
        ))
    });
    
    match flare_result {
        Ok((id, member_id, _branch_id, is_anonymous, status, eta_seconds, created_at, updated_at)) => {
            let is_authorized = match auth {
                Some(user) => user.member_id.to_string() == member_id,
                None => is_anonymous == 1,
            };
            
            if !is_authorized {
                return Err(StatusCode::FORBIDDEN);
            }
            
            Ok(Json(json!({
                "flare_id": id,
                "status": status,
                "eta_seconds": eta_seconds,
                "is_anonymous": is_anonymous == 1,
                "created_at": created_at,
                "updated_at": updated_at,
            })))
        }
        Err(_) => Err(StatusCode::NOT_FOUND),
    }
}