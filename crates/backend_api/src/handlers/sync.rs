//! CRDT Sync Handlers

use axum::{Json, extract::State};
use serde_json::json;
use uuid::Uuid;
use chrono::Utc;
use crate::models::{SyncPullRequest, SyncPushRequest, SyncResponse, Conflict};
use crate::middleware::AuthenticatedUser;

/// Pull changes from server
pub async fn pull_changes(
    _user: AuthenticatedUser,
    State(_pool): State<sqlite_embedded::DbPool>,
    Json(req): Json<SyncPullRequest>,
) -> Json<SyncResponse> {
    Json(SyncResponse {
        accepted_ops: vec![],
        conflicts: vec![],
        new_vector_clock: req.vector_clock,
        sync_token: Uuid::new_v4().to_string(),
        server_time: Utc::now(),
    })
}

/// Push local changes to server
pub async fn push_changes(
    _user: AuthenticatedUser,
    State(pool): State<sqlite_embedded::DbPool>,
    Json(req): Json<SyncPushRequest>,
) -> Json<SyncResponse> {
    let mut accepted_ops = Vec::new();
    let mut conflicts = Vec::new();
    
    for op in req.pending_ops {
        match sqlite_embedded::enqueue_op(&pool, &op) {
            Ok(id) => {
                accepted_ops.push(Uuid::new_v4());
                let _ = sqlite_embedded::mark_synced(&pool, id);
            }
            Err(e) => {
                conflicts.push(Conflict {
                    op_id: Uuid::new_v4(),
                    resolution: "server_overrides".to_string(),
                    server_state: json!({"error": e.to_string()}),
                });
            }
        }
    }
    
    Json(SyncResponse {
        accepted_ops,
        conflicts,
        new_vector_clock: req.vector_clock,
        sync_token: Uuid::new_v4().to_string(),
        server_time: Utc::now(),
    })
}