//! Geospatial H3 Indexing for Zero-Trust Logistics
//! 
//! This crate provides:
//! - Lat/Lng to H3 index conversion (resolutions 0-15)
//! - K-ring neighbor search for proximity queries
//! - Distance calculations between H3 cells
//! - Tile signing/verification using Person A's crypto
//! - ETA estimation for offline routing

// Declare modules first
pub mod h3_wrapper;
pub mod distance;
pub mod tile_signer;
pub mod eta;

// Then re-export main public functions
pub use h3_wrapper::{
    lat_lng_to_h3, 
    h3_to_lat_lng, 
    k_ring, 
    k_ring_distances,
    h3_to_geohash, 
    geohash_to_h3,
    get_resolution,
    H3Error,
};

pub use distance::{
    h3_distance_meters,
    haversine_distance_meters,
    precompute_distance_matrix,
    distance_to_walking_seconds,
    DistanceMatrix,
};

pub use tile_signer::{
    sign_tile_bundle,
    verify_tile_bundle,
    create_tile_signature,
    verify_tile_signature,
    TileSignature,
};

pub use eta::{
    estimate_eta_seconds,
    EtaEstimator,
};

/// H3 resolution constants (most useful for logistics)
pub mod resolutions {
    /// Cell area ~ 0.1 km² - for member-level proximity
    pub const MEMBER_PROXIMITY: u8 = 9;
    
    /// Cell area ~ 3.7 km² - for regional dispatch
    pub const REGIONAL_DISPATCH: u8 = 6;
    
    /// Cell area ~ 0.0004 km² - for precise building location
    pub const BUILDING_PRECISE: u8 = 12;
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_h3_conversion_works() {
        let result = lat_lng_to_h3(40.756, -73.986, 9);
        assert!(result.is_ok());
        let h3 = result.unwrap();
        assert!(h3 > 0);
    }
    
    #[test]
    fn test_roundtrip_accuracy() {
        let lat = 40.756;
        let lng = -73.986;
        let h3 = lat_lng_to_h3(lat, lng, 9).unwrap();
        let (lat2, lng2) = h3_to_lat_lng(h3);
        let diff_lat = (lat - lat2).abs();
        let diff_lng = (lng - lng2).abs();
        // H3 resolution 9 has ~170m edges, so error can be up to ~0.0015 degrees
        assert!(diff_lat < 0.002);
        assert!(diff_lng < 0.002);
    }
}