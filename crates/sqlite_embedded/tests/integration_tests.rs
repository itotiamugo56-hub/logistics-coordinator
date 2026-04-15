use sqlite_embedded::*;
use tempfile::tempdir;
use uuid::Uuid;
use crdt_engine::Op;

#[test]
fn test_full_database_workflow() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db").to_str().unwrap().to_string();
    
    // 1. Initialize database
    let pool = init_database(&db_path).unwrap();
    run_migrations(&pool).unwrap();
    
    // 2. Insert a test branch
    let conn = get_connection(&pool).unwrap();
    conn.execute(
        "INSERT INTO branches (id, branch_code, h3_index_9, allowed_weekdays, is_authenticated) VALUES (?, ?, ?, ?, 1)",
        rusqlite::params![Uuid::new_v4().as_bytes(), "TEST.001", "89283082873ffff", "[\"Sunday\"]"],
    ).unwrap();
    
    // 3. Verify branch exists
    let count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM branches WHERE branch_code = ?",
        rusqlite::params!["TEST.001"],
        |row| row.get(0),
    ).unwrap();
    assert_eq!(count, 1);
    
    // 4. Queue an operation
    use crypto_core::ed25519::generate_keypair;
    use crdt_engine::OpType;
    
    let (_, sk) = generate_keypair();
    let peer_id = [1u8; 32];
    
    let op = Op::new(1, peer_id, OpType::InsertPickup {
        flare_id: [42u8; 16],
        location_h3: "89283082873ffff".to_string(),
        timestamp_ms: 1000,
    }, &sk);
    
    let op_id = enqueue_op(&pool, &op).unwrap();
    assert!(op_id > 0);
    
    // 5. Process queue
    let pending = process_queue(&pool, 10).unwrap();
    assert_eq!(pending.len(), 1);
    
    // 6. Mark as synced
    mark_synced(&pool, op_id).unwrap();
    
    // 7. Verify queue is empty
    let pending_after = process_queue(&pool, 10).unwrap();
    assert_eq!(pending_after.len(), 0);
    
    println!("✅ Full database workflow passed!");
}

#[test]
fn test_queue_persistence() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db").to_str().unwrap().to_string();
    
    // First connection - enqueue
    {
        let pool = init_database(&db_path).unwrap();
        run_migrations(&pool).unwrap();
        
        let (_, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let op = Op::new(1, peer_id, crdt_engine::OpType::InsertPickup {
            flare_id: [42u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        
        let op_id = enqueue_op(&pool, &op).unwrap();
        assert!(op_id > 0);
    }
    
    // Second connection - verify op still there
    {
        let pool = init_database(&db_path).unwrap();
        let pending = process_queue(&pool, 10).unwrap();
        assert_eq!(pending.len(), 1);
    }
    
    println!("✅ Queue persistence test passed!");
}

// Helper
use crypto_core::ed25519::generate_keypair;