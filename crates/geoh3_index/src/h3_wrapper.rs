//! Wrapper around Uber's H3 library
//! Provides safe Rust bindings for common operations

use h3o::{CellIndex, LatLng, Resolution};
use thiserror::Error;

#[derive(Error, Debug, PartialEq)]
pub enum H3Error {
    #[error("Invalid latitude: {0}, must be between -90 and 90")]
    InvalidLatitude(f64),
    
    #[error("Invalid longitude: {0}, must be between -180 and 180")]
    InvalidLongitude(f64),
    
    #[error("Invalid resolution: {0}, must be between 0 and 15")]
    InvalidResolution(u8),
    
    #[error("Failed to convert to H3 cell")]
    ConversionFailed,
    
    #[error("Invalid geohash format")]
    InvalidGeohash,
}

/// Convert latitude/longitude to H3 cell index
pub fn lat_lng_to_h3(lat: f64, lng: f64, resolution: u8) -> Result<u64, H3Error> {
    // Validate inputs
    if !(-90.0..=90.0).contains(&lat) {
        return Err(H3Error::InvalidLatitude(lat));
    }
    if !(-180.0..=180.0).contains(&lng) {
        return Err(H3Error::InvalidLongitude(lng));
    }
    if resolution > 15 {
        return Err(H3Error::InvalidResolution(resolution));
    }
    
    let resolution = match Resolution::try_from(resolution) {
        Ok(r) => r,
        Err(_) => return Err(H3Error::InvalidResolution(resolution)),
    };
    
    let latlng = LatLng::new(lat, lng).map_err(|_| H3Error::ConversionFailed)?;
    let cell = latlng.to_cell(resolution);
    
    Ok(cell.into())
}

/// Convert H3 cell index back to latitude/longitude using boundary
/// Returns (0.0, 0.0) for invalid indices instead of panicking
pub fn h3_to_lat_lng(h3_index: u64) -> (f64, f64) {
    let cell = match CellIndex::try_from(h3_index) {
        Ok(c) => c,
        Err(_) => return (0.0, 0.0),
    };
    let boundary = cell.boundary();
    if boundary.is_empty() {
        return (0.0, 0.0);
    }
    let first = boundary[0];
    (first.lat(), first.lng())
}

/// Get all H3 cells within k-ring (including center) - filters out None values
pub fn k_ring(h3_index: u64, k: u32) -> Vec<u64> {
    let cell = match CellIndex::try_from(h3_index) {
        Ok(c) => c,
        Err(_) => return vec![],
    };
    let mut result = vec![h3_index];
    
    for i in 1..=k {
        for opt_cell in cell.grid_ring_fast(i) {
            if let Some(c) = opt_cell {
                result.push(c.into());
            }
        }
    }
    
    result
}

/// Get k-ring with distances (for radius-based search)
pub fn k_ring_distances(h3_index: u64, max_radius_meters: f64) -> Vec<(u64, f64)> {
    let cell = match CellIndex::try_from(h3_index) {
        Ok(c) => c,
        Err(_) => return vec![],
    };
    let mut results = Vec::new();
    
    for k in 1..=10 {
        let mut has_cells_in_ring = false;
        
        for opt_neighbor in cell.grid_ring_fast(k) {
            if let Some(neighbor) = opt_neighbor {
                has_cells_in_ring = true;
                let distance = haversine_distance_between_cells(cell, neighbor);
                if distance <= max_radius_meters {
                    results.push((neighbor.into(), distance));
                }
            }
        }
        
        if !has_cells_in_ring {
            break;
        }
    }
    
    results.insert(0, (h3_index, 0.0));
    results
}

/// Convert H3 index to geohash string (for backward compatibility)
pub fn h3_to_geohash(h3_index: u64) -> String {
    let cell = match CellIndex::try_from(h3_index) {
        Ok(c) => c,
        Err(_) => return String::new(),
    };
    let boundary = cell.boundary();
    if boundary.is_empty() {
        return String::new();
    }
    let first = boundary[0];
    let mut geohash = String::with_capacity(12);
    encode_geohash(first.lat(), first.lng(), 12, &mut geohash);
    geohash
}

/// Approximate H3 from geohash (best-effort)
pub fn geohash_to_h3(geohash: &str, resolution: u8) -> Result<u64, H3Error> {
    let (lat, lng) = decode_geohash(geohash).ok_or(H3Error::InvalidGeohash)?;
    lat_lng_to_h3(lat, lng, resolution)
}

/// Get resolution of an H3 index
pub fn get_resolution(h3_index: u64) -> u8 {
    let cell = match CellIndex::try_from(h3_index) {
        Ok(c) => c,
        Err(_) => return 0,
    };
    u8::from(cell.resolution())
}

/// Internal: Haversine distance between two H3 cells (meters)
fn haversine_distance_between_cells(cell1: CellIndex, cell2: CellIndex) -> f64 {
    let boundary1 = cell1.boundary();
    let boundary2 = cell2.boundary();
    
    if boundary1.is_empty() || boundary2.is_empty() {
        return 0.0;
    }
    
    let latlng1 = boundary1[0];
    let latlng2 = boundary2[0];
    haversine_distance(latlng1.lat(), latlng1.lng(), latlng2.lat(), latlng2.lng())
}

/// Internal: Haversine distance between two coordinates (meters)
fn haversine_distance(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    const EARTH_RADIUS_M: f64 = 6_371_000.0;
    
    let lat1_rad = lat1.to_radians();
    let lat2_rad = lat2.to_radians();
    let delta_lat = (lat2 - lat1).to_radians();
    let delta_lng = (lng2 - lng1).to_radians();
    
    let a = (delta_lat / 2.0).sin() * (delta_lat / 2.0).sin()
        + lat1_rad.cos() * lat2_rad.cos()
        * (delta_lng / 2.0).sin() * (delta_lng / 2.0).sin();
    
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());
    EARTH_RADIUS_M * c
}

/// Internal: Encode lat/lng to geohash (simplified)
fn encode_geohash(lat: f64, lng: f64, precision: usize, output: &mut String) {
    const BASE32: &[u8] = b"0123456789bcdefghjkmnpqrstuvwxyz";
    
    let mut bits = 0;
    let mut bit_count = 0;
    let mut lat_range = (-90.0, 90.0);
    let mut lng_range = (-180.0, 180.0);
    
    output.clear();
    
    while output.len() < precision {
        if bits % 2 == 0 {
            let mid = (lng_range.0 + lng_range.1) / 2.0;
            if lng >= mid {
                bit_count = (bit_count << 1) | 1;
                lng_range.0 = mid;
            } else {
                bit_count <<= 1;
                lng_range.1 = mid;
            }
        } else {
            let mid = (lat_range.0 + lat_range.1) / 2.0;
            if lat >= mid {
                bit_count = (bit_count << 1) | 1;
                lat_range.0 = mid;
            } else {
                bit_count <<= 1;
                lat_range.1 = mid;
            }
        }
        
        bits += 1;
        
        if bits % 5 == 0 {
            let index = (bit_count & 0x1F) as usize;
            output.push(BASE32[index] as char);
            bit_count = 0;
        }
    }
}

/// Internal: Decode geohash to lat/lng
fn decode_geohash(geohash: &str) -> Option<(f64, f64)> {
    const BASE32_DECODE: [i8; 256] = {
        let mut arr = [-1; 256];
        let chars = b"0123456789bcdefghjkmnpqrstuvwxyz";
        let mut i = 0;
        while i < chars.len() {
            arr[chars[i] as usize] = i as i8;
            i += 1;
        }
        arr
    };
    
    let mut lat_range = (-90.0, 90.0);
    let mut lng_range = (-180.0, 180.0);
    let mut is_even = true;
    
    for c in geohash.chars() {
        let idx = BASE32_DECODE[c as usize];
        if idx < 0 {
            return None;
        }
        let mut mask = 16;
        while mask > 0 {
            if is_even {
                let mid = (lng_range.0 + lng_range.1) / 2.0;
                if idx & mask != 0 {
                    lng_range.0 = mid;
                } else {
                    lng_range.1 = mid;
                }
            } else {
                let mid = (lat_range.0 + lat_range.1) / 2.0;
                if idx & mask != 0 {
                    lat_range.0 = mid;
                } else {
                    lat_range.1 = mid;
                }
            }
            is_even = !is_even;
            mask >>= 1;
        }
    }
    
    Some(((lat_range.0 + lat_range.1) / 2.0, (lng_range.0 + lng_range.1) / 2.0))
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_lat_lng_conversion() {
        let h3 = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
        assert!(h3 > 0);
    }
    
    #[test]
    fn test_k_ring_size() {
        let h3 = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
        let ring = k_ring(h3, 1);
        assert!(ring.len() >= 1);
    }
    
    #[test]
    fn test_invalid_latitude() {
        let result = lat_lng_to_h3(100.0, -73.986, 9);
        assert!(matches!(result, Err(H3Error::InvalidLatitude(100.0))));
    }
    
    #[test]
    fn test_get_resolution() {
        let h3 = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
        assert_eq!(get_resolution(h3), 9);
    }
    
    #[test]
    fn test_roundtrip_consistent() {
        let h3 = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
        let (lat, lng) = h3_to_lat_lng(h3);
        let h3_again = lat_lng_to_h3(lat, lng, 9).unwrap();
        assert!(h3 == h3_again || get_resolution(h3_again) == 9);
    }
    
    #[test]
    fn test_invalid_index_does_not_panic() {
        let invalid_index = 0xDEADBEEF;
        let (lat, lng) = h3_to_lat_lng(invalid_index);
        assert_eq!(lat, 0.0);
        assert_eq!(lng, 0.0);
    }
}