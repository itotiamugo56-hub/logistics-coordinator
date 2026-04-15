use geoh3_index::*;

#[test]
fn test_full_proximity_workflow() {
    // 1. Convert member location to H3
    let member_h3 = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
    
    // 2. Find nearby branches (simulated)
    let branch1 = lat_lng_to_h3(40.7580, -73.9855, 9).unwrap();
    let branch2 = lat_lng_to_h3(40.7536, -73.9834, 9).unwrap();
    let branches = vec![branch1, branch2];
    
    // 3. Calculate distances
    let mut distances = Vec::new();
    for branch in branches {
        let dist = h3_distance_meters(member_h3, branch);
        distances.push((branch, dist));
    }
    
    // 4. Sort by distance
    distances.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
    
    // 5. Get ETA to closest branch
    let closest = distances[0].0;
    let eta = estimate_eta_seconds(member_h3, closest);
    
    assert!(eta > 0);
    assert!(distances[0].1 < distances[1].1);
}

#[test]
fn test_k_ring_search() {
    let center = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
    let neighbors = k_ring(center, 1);
    
    // Should have 7 cells total (center + 6 neighbors)
    assert_eq!(neighbors.len(), 7);
    assert!(neighbors.contains(&center));
}

#[test]
fn test_tile_signing_integration() {
    use crypto_core::ed25519::generate_keypair;
    
    let (pk, sk) = generate_keypair();
    let tile_data = b"offline map tile data";
    
    let signature = sign_tile_bundle(tile_data, &sk);
    assert!(verify_tile_bundle(tile_data, &signature, &pk));
}