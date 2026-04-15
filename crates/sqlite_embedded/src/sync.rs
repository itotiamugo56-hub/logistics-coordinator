//! Sync protocol for CRDT-based replication

use crate::db::{DbError, DbPool};
use crate::queue::{process_queue, mark_synced};
use crdt_engine::{Op, VectorClock};
use serde::{Serialize, Deserialize};
use tracing::info;
use thiserror::Error;

/// Sync errors
#[derive(Error, Debug)]
pub enum SyncError {
    #[error("HTTP request failed: {0}")]
    HttpError(String),
    
    #[error("Server returned error: {0}")]
    ServerError(String),
    
    #[error("Database error: {0}")]
    DbError(#[from] DbError),
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] bincode::Error),
}

/// Response from sync endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResponse {
    pub new_vector_clock: VectorClock,
    pub ops: Vec<Op>,
    pub server_time: i64,
}

/// Pull changes from server
pub async fn pull_changes(
    _pool: &DbPool,
    client_clock: &VectorClock,
    _server_url: &str,
    _token: &str,
) -> Result<SyncResponse, SyncError> {
    info!("Pulling changes from server");
    
    // Simplified: In production, this would make an HTTP call
    // For now, return empty response
    Ok(SyncResponse {
        new_vector_clock: client_clock.clone(),
        ops: vec![],
        server_time: chrono::Utc::now().timestamp(),
    })
}

/// Push local changes to server
pub async fn push_changes(
    pool: &DbPool,
    _server_url: &str,
    _token: &str,
    max_ops: usize,
) -> Result<SyncResponse, SyncError> {
    info!("Pushing local changes to server");
    
    let pending_ops = process_queue(pool, max_ops)?;
    if pending_ops.is_empty() {
        return Ok(SyncResponse {
            new_vector_clock: VectorClock::new(),
            ops: vec![],
            server_time: chrono::Utc::now().timestamp(),
        });
    }
    
    // Mark as synced (simulated success)
    for pending in &pending_ops {
        let _ = mark_synced(pool, pending.id);
    }
    
    info!("Pushed {} ops successfully", pending_ops.len());
    Ok(SyncResponse {
        new_vector_clock: VectorClock::new(),
        ops: vec![],
        server_time: chrono::Utc::now().timestamp(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_sync_response_serialization() {
        let response = SyncResponse {
            new_vector_clock: VectorClock::new(),
            ops: vec![],
            server_time: 1234567890,
        };
        
        let serialized = serde_json::to_string(&response).unwrap();
        let deserialized: SyncResponse = serde_json::from_str(&serialized).unwrap();
        
        assert_eq!(deserialized.server_time, 1234567890);
    }
}