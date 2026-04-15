//! Distance calculations between H3 cells
//! Used for ETA estimation and proximity queries

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use crate::h3_wrapper::h3_to_lat_lng;

/// Precomputed distance matrix for fast lookup
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DistanceMatrix {
    /// Mapping from (from_h3, to_h3) to distance in meters
    pub distances: HashMap<(u64, u64), f64>,
    
    /// Resolution used for this matrix
    pub resolution: u8,
    
    /// List of all H3 cells in the matrix
    pub cells: Vec<u64>,
}

impl DistanceMatrix {
    pub fn new(resolution: u8) -> Self {
        Self {
            distances: HashMap::new(),
            resolution,
            cells: Vec::new(),
        }
    }
    
    /// Get distance between two cells (returns 0 if same)
    pub fn get_distance(&self, from: u64, to: u64) -> Option<f64> {
        if from == to {
            return Some(0.0);
        }
        self.distances.get(&(from, to)).copied()
    }
    
    /// Add a distance entry
    pub fn insert(&mut self, from: u64, to: u64, distance_meters: f64) {
        self.distances.insert((from, to), distance_meters);
        if !self.cells.contains(&from) {
            self.cells.push(from);
        }
        if !self.cells.contains(&to) {
            self.cells.push(to);
        }
    }
}

/// Calculate great-circle distance between two H3 cells (meters)
pub fn h3_distance_meters(from: u64, to: u64) -> f64 {
    let (lat1, lng1) = h3_to_lat_lng(from);
    let (lat2, lng2) = h3_to_lat_lng(to);
    haversine_distance_meters(lat1, lng1, lat2, lng2)
}

/// Haversine distance between two coordinates (meters)
pub fn haversine_distance_meters(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
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

/// Precompute distance matrix for a set of H3 cells (for regional dispatch)
pub fn precompute_distance_matrix(cells: &[u64], resolution: u8) -> DistanceMatrix {
    let mut matrix = DistanceMatrix::new(resolution);
    
    for i in 0..cells.len() {
        for j in 0..cells.len() {
            if i != j && !matrix.distances.contains_key(&(cells[i], cells[j])) {
                let dist = h3_distance_meters(cells[i], cells[j]);
                matrix.insert(cells[i], cells[j], dist);
                matrix.insert(cells[j], cells[i], dist);
            }
        }
    }
    
    matrix
}

/// Approximate walking time in seconds from distance meters
pub fn distance_to_walking_seconds(distance_meters: f64) -> u16 {
    const WALKING_SPEED_MS: f64 = 1.4;
    
    let seconds = (distance_meters / WALKING_SPEED_MS).round() as u16;
    seconds.min(7200)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::h3_wrapper::lat_lng_to_h3;
    
    #[test]
    fn test_distance_between_known_points() {
        let ts = lat_lng_to_h3(40.7580, -73.9855, 9).unwrap();
        let bp = lat_lng_to_h3(40.7536, -73.9834, 9).unwrap();
        
        let dist = h3_distance_meters(ts, bp);
        assert!(dist > 400.0 && dist < 600.0);
    }
    
    #[test]
    fn test_walking_time_reasonable() {
        let seconds = distance_to_walking_seconds(500.0);
        assert!(seconds > 300 && seconds < 400);
    }
    
    #[test]
    fn test_distance_matrix() {
        let cells = vec![
            lat_lng_to_h3(40.7580, -73.9855, 9).unwrap(),
            lat_lng_to_h3(40.7536, -73.9834, 9).unwrap(),
            lat_lng_to_h3(40.7600, -73.9900, 9).unwrap(),
        ];
        
        let matrix = precompute_distance_matrix(&cells, 9);
        assert!(matrix.distances.len() >= 6);
        assert_eq!(matrix.cells.len(), 3);
    }
}