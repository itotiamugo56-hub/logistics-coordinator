//! SQLite Embedded Database with CRDT Sync
//! 
//! This crate provides:
//! - Persistent storage for members, branches, pickup logs
//! - CRDT-based sync with server
//! - Offline queue for pending operations
//! - H3 geospatial queries using Person C's crate

pub mod db;
pub mod sync;
pub mod queue;
pub mod models;

// Re-export main types
pub use db::{init_database, run_migrations, DbError, DbPool, get_connection};
pub use sync::{pull_changes, push_changes, SyncResponse, SyncError};
pub use queue::{enqueue_op, process_queue, mark_synced, mark_sync_failed, OutboxOp, queue_size};
pub use models::{PickupLog, Branch, Member, PickupStatus};

/// Type alias for database connection pool
pub type Pool = r2d2::Pool<r2d2_sqlite::SqliteConnectionManager>;