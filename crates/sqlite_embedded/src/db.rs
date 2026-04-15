//! Database connection and initialization

use r2d2_sqlite::SqliteConnectionManager;
use r2d2;
use std::path::Path;
use thiserror::Error;
use tracing::info;

/// Database errors
#[derive(Error, Debug)]
pub enum DbError {
    #[error("Failed to open database: {0}")]
    ConnectionError(#[from] rusqlite::Error),
    
    #[error("Failed to initialize connection pool: {0}")]
    PoolError(#[from] r2d2::Error),
    
    #[error("Migration failed: {0}")]
    MigrationError(String),
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] bincode::Error),
    
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),
}

/// Database connection pool type
pub type DbPool = r2d2::Pool<r2d2_sqlite::SqliteConnectionManager>;

/// Initialize database with connection pool
pub fn init_database(path: &str) -> Result<DbPool, DbError> {
    info!("Initializing database at: {}", path);
    
    // Ensure directory exists
    if let Some(parent) = Path::new(path).parent() {
        std::fs::create_dir_all(parent)?;
    }
    
    let manager = SqliteConnectionManager::file(path);
    let pool = r2d2::Pool::builder()
        .max_size(10)
        .build(manager)?;
    
    Ok(pool)
}

/// Get a connection from the pool
pub fn get_connection(pool: &DbPool) -> Result<r2d2::PooledConnection<r2d2_sqlite::SqliteConnectionManager>, DbError> {
    Ok(pool.get()?)
}

/// Run all migrations to create schema
pub fn run_migrations(pool: &DbPool) -> Result<(), DbError> {
    let conn = get_connection(pool)?;
    
    info!("Running database migrations...");
    
    // Create branches table (ministry branches - simplified for member use)
    conn.execute_batch(r#"
        CREATE TABLE IF NOT EXISTS branches (
            id BLOB PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            senior_pastor TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            service_times TEXT NOT NULL,
            announcement TEXT,
            is_verified INTEGER NOT NULL DEFAULT 0,
            last_updated INTEGER NOT NULL
        );
    "#)?;
    
    // Create members table (for clergy authentication)
    conn.execute_batch(r#"
        CREATE TABLE IF NOT EXISTS members (
            id BLOB PRIMARY KEY,
            canonical_id TEXT NOT NULL UNIQUE,
            public_key BLOB NOT NULL,
            hardware_attestation BLOB,
            biometric_hash BLOB,
            enrolled_at INTEGER NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            recovery_h3_index TEXT
        );
        
        CREATE INDEX IF NOT EXISTS idx_members_canonical ON members(canonical_id);
    "#)?;
    
    // Create pickup_logs table with CRDT support (for Signal Flares)
    conn.execute_batch(r#"
        CREATE TABLE IF NOT EXISTS pickup_logs (
            id BLOB PRIMARY KEY,
            flare_id BLOB NOT NULL UNIQUE,
            member_id BLOB NOT NULL,
            assigned_branch_id BLOB,
            request_h3_index TEXT NOT NULL,
            request_time INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'queued',
            eta_seconds INTEGER,
            clergy_contact_ephemeral BLOB,
            lamport_timestamp INTEGER NOT NULL,
            peer_id BLOB NOT NULL,
            FOREIGN KEY (member_id) REFERENCES members(id),
            FOREIGN KEY (assigned_branch_id) REFERENCES branches(id)
        );
        
        CREATE INDEX IF NOT EXISTS idx_pickup_status ON pickup_logs(status);
        CREATE INDEX IF NOT EXISTS idx_pickup_lamport ON pickup_logs(lamport_timestamp);
    "#)?;
    
    // Create outbox_queue table (for offline sync)
    conn.execute_batch(r#"
        CREATE TABLE IF NOT EXISTS outbox_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            op_type TEXT NOT NULL,
            op_data BLOB NOT NULL,
            lamport_timestamp INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            synced_at INTEGER
        );
        
        CREATE INDEX IF NOT EXISTS idx_outbox_retry ON outbox_queue(next_retry_at) WHERE synced_at IS NULL;
    "#)?;
    
    // Create tile_cache table (for offline maps)
    conn.execute_batch(r#"
        CREATE TABLE IF NOT EXISTS tile_cache (
            h3_index TEXT PRIMARY KEY,
            tile_data BLOB NOT NULL,
            tile_signature TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            last_used_at INTEGER
        );
        
        CREATE INDEX IF NOT EXISTS idx_tile_expiry ON tile_cache(expires_at);
    "#)?;
    
    info!("Migrations completed successfully");
    Ok(())
}

/// Insert a test branch (for development)
#[cfg(test)]
pub fn insert_test_branch(pool: &DbPool, name: &str, address: &str, lat: f64, lng: f64, pastor: &str, phone: &str, email: &str) -> Result<(), DbError> {
    let conn = get_connection(pool)?;
    let id = uuid::Uuid::new_v4();
    let service_times = serde_json::json!({
        "Sunday": ["8:00 AM", "10:00 AM", "12:00 PM"]
    });
    
    conn.execute(
        "INSERT INTO branches (id, name, address, latitude, longitude, senior_pastor, phone, email, service_times, is_verified, last_updated) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, strftime('%s','now'))",
        rusqlite::params![id.as_bytes(), name, address, lat, lng, pastor, phone, email, service_times.to_string()],
    )?;
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    
    #[test]
    fn test_database_initialization() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db").to_str().unwrap().to_string();
        
        let pool = init_database(&db_path).unwrap();
        run_migrations(&pool).unwrap();
        
        // Verify tables exist
        let conn = get_connection(&pool).unwrap();
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table'", 
            [], 
            |row| row.get(0)
        ).unwrap();
        assert!(count >= 5);
    }
}