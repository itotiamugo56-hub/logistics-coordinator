//! Offline queue manager for pending sync operations

use crate::db::{DbError, get_connection, DbPool};
use rusqlite::params;
use chrono::Utc;
use tracing::{info, warn};
use serde::{Serialize, Deserialize};

/// Operation stored in outbox
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutboxOp {
    pub id: i64,
    pub op_type: String,
    pub op_data: Vec<u8>,
    pub lamport_timestamp: u64,
    pub retry_count: u32,
    pub next_retry_at: i64,
    pub created_at: i64,
    pub synced_at: Option<i64>,
}

/// Enqueue an operation for later sync
pub fn enqueue_op(pool: &DbPool, op: &crdt_engine::Op) -> Result<i64, DbError> {
    let conn = get_connection(pool)?;
    
    let op_data = bincode::serialize(op)?;
    let op_type = match &op.op_type {
        crdt_engine::OpType::InsertPickup { .. } => "insert_pickup",
        crdt_engine::OpType::UpdateStatus { .. } => "update_status",
        crdt_engine::OpType::AssignClergy { .. } => "assign_clergy",
        crdt_engine::OpType::CompletePickup { .. } => "complete_pickup",
    };
    
    let now = Utc::now().timestamp();
    let next_retry_at = now;
    
    conn.execute(
        "INSERT INTO outbox_queue (op_type, op_data, lamport_timestamp, next_retry_at, created_at) 
         VALUES (?, ?, ?, ?, ?)",
        params![op_type, op_data, op.lamport as i64, next_retry_at, now],
    )?;
    
    let id = conn.last_insert_rowid();
    info!("Enqueued operation {} (id: {})", op_type, id);
    
    Ok(id)
}

/// Get pending operations ready for sync
pub fn process_queue(pool: &DbPool, max_ops: usize) -> Result<Vec<OutboxOp>, DbError> {
    let conn = get_connection(pool)?;
    let now = Utc::now().timestamp();
    
    let mut stmt = conn.prepare(
        "SELECT id, op_type, op_data, lamport_timestamp, retry_count, next_retry_at, created_at, synced_at
         FROM outbox_queue 
         WHERE synced_at IS NULL AND next_retry_at <= ?
         ORDER BY lamport_timestamp ASC
         LIMIT ?"
    )?;
    
    let rows = stmt.query_map(params![now, max_ops as i64], |row| {
        Ok(OutboxOp {
            id: row.get(0)?,
            op_type: row.get(1)?,
            op_data: row.get(2)?,
            lamport_timestamp: row.get::<_, i64>(3)? as u64,
            retry_count: row.get(4)?,
            next_retry_at: row.get(5)?,
            created_at: row.get(6)?,
            synced_at: row.get(7)?,
        })
    })?;
    
    let mut ops = Vec::new();
    for row in rows {
        ops.push(row?);
    }
    
    Ok(ops)
}

/// Mark an operation as successfully synced
pub fn mark_synced(pool: &DbPool, op_id: i64) -> Result<(), DbError> {
    let conn = get_connection(pool)?;
    let now = Utc::now().timestamp();
    
    conn.execute(
        "UPDATE outbox_queue SET synced_at = ? WHERE id = ?",
        params![now, op_id],
    )?;
    
    info!("Marked operation {} as synced", op_id);
    Ok(())
}

/// Mark sync failure, update retry schedule with exponential backoff
pub fn mark_sync_failed(pool: &DbPool, op_id: i64) -> Result<(), DbError> {
    let conn = get_connection(pool)?;
    
    let retry_count: u32 = conn.query_row(
        "SELECT retry_count FROM outbox_queue WHERE id = ?",
        params![op_id],
        |row| row.get(0),
    )?;
    
    let new_retry_count = retry_count + 1;
    let backoff_seconds = (2u32.pow(new_retry_count)).min(3600);
    let next_retry_at = Utc::now().timestamp() + backoff_seconds as i64;
    
    conn.execute(
        "UPDATE outbox_queue SET retry_count = ?, next_retry_at = ? WHERE id = ?",
        params![new_retry_count, next_retry_at, op_id],
    )?;
    
    warn!("Operation {} failed, retry {} scheduled", op_id, new_retry_count);
    Ok(())
}

/// Get queue size (pending ops)
pub fn queue_size(pool: &DbPool) -> Result<usize, DbError> {
    let conn = get_connection(pool)?;
    let count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM outbox_queue WHERE synced_at IS NULL",
        [],
        |row| row.get(0),
    )?;
    Ok(count as usize)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::{init_database, run_migrations};
    use tempfile::tempdir;
    use crypto_core::ed25519::generate_keypair;
    use crdt_engine::{Op, OpType};
    
    #[test]
    fn test_enqueue_and_process() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db").to_str().unwrap().to_string();
        
        let pool = init_database(&db_path).unwrap();
        run_migrations(&pool).unwrap();
        
        let (_, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let op = Op::new(1, peer_id, OpType::InsertPickup {
            flare_id: [42u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        
        let id = enqueue_op(&pool, &op).unwrap();
        assert!(id > 0);
        
        let pending = process_queue(&pool, 10).unwrap();
        assert_eq!(pending.len(), 1);
        assert_eq!(pending[0].id, id);
        
        mark_synced(&pool, id).unwrap();
        
        let pending_after = process_queue(&pool, 10).unwrap();
        assert_eq!(pending_after.len(), 0);
    }
    
    #[test]
    fn test_exponential_backoff() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db").to_str().unwrap().to_string();
        
        let pool = init_database(&db_path).unwrap();
        run_migrations(&pool).unwrap();
        
        let (_, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let op = Op::new(1, peer_id, OpType::InsertPickup {
            flare_id: [42u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        
        let id = enqueue_op(&pool, &op).unwrap();
        
        mark_sync_failed(&pool, id).unwrap();
        
        let conn = get_connection(&pool).unwrap();
        let retry_count: u32 = conn.query_row(
            "SELECT retry_count FROM outbox_queue WHERE id = ?",
            params![id],
            |row| row.get(0),
        ).unwrap();
        assert_eq!(retry_count, 1);
    }
}