//! Signal Flare handlers

use axum::{Json, extract::{Path, State}};
use uuid::Uuid;
use chrono::Utc;
use serde_json::{json, Value};
use crate::models::{FlareSubmission, FlareResponse};
use crate::middleware::AuthenticatedUser;

/// Submit a new Signal Flare
pub async fn submit_flare(
    _user: AuthenticatedUser,
    State(_pool): State<sqlite_embedded::DbPool>,
    Json(req): Json<FlareSubmission>,
) -> Json<FlareResponse> {
    Json(FlareResponse {
        flare_id: req.signal_flare_id,
        status: "queued".to_string(),
        assigned_branch_id: None,
        server_received_time: Utc::now(),
        retry_queue_position: 0,
    })
}

/// Get flare status
pub async fn get_flare_status(
    _user: AuthenticatedUser,
    State(_pool): State<sqlite_embedded::DbPool>,
    Path(flare_id): Path<Uuid>,
) -> Json<Value> {
    Json(json!({
        "flare_id": flare_id,
        "status": "dispatched",
        "eta_seconds": 300,
    }))
}