//! Geospatial proximity handlers

use axum::{Json, extract::State};
use crate::models::{ProximityRequest, ProximityResponse};
use crate::middleware::AuthenticatedUser;

pub async fn find_nearby_branches(
    _user: AuthenticatedUser,
    State(_pool): State<sqlite_embedded::DbPool>,
    Json(_req): Json<ProximityRequest>,
) -> Json<ProximityResponse> {
    Json(ProximityResponse {
        branches: vec![],
        cache_ttl_seconds: 86400,
        server_time: chrono::Utc::now(),
    })
}