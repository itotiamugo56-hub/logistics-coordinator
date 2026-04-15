//! ETA estimation for offline routing
//! Uses precomputed distance matrix or fallback to direct calculation

use std::collections::HashMap;
use crate::distance::{h3_distance_meters, distance_to_walking_seconds};
use crate::DistanceMatrix;

/// ETA estimator with caching
#[derive(Debug, Clone)]
pub struct EtaEstimator {
    /// Precomputed distance matrix (optional, for faster lookups)
    distance_matrix: Option<DistanceMatrix>,
    
    /// Cache for recently computed ETAs
    cache: HashMap<(u64, u64), u16>,
}

impl EtaEstimator {
    /// Create a new estimator without precomputed matrix
    pub fn new() -> Self {
        Self {
            distance_matrix: None,
            cache: HashMap::new(),
        }
    }
    
    /// Create estimator with precomputed distance matrix
    pub fn with_matrix(matrix: DistanceMatrix) -> Self {
        Self {
            distance_matrix: Some(matrix),
            cache: HashMap::new(),
        }
    }
    
    /// Estimate walking time in seconds between two H3 cells
    pub fn estimate(&mut self, from_h3: u64, to_h3: u64) -> u16 {
        // Check cache first
        if let Some(&eta) = self.cache.get(&(from_h3, to_h3)) {
            return eta;
        }
        
        let eta = self.compute_eta(from_h3, to_h3);
        self.cache.insert((from_h3, to_h3), eta);
        eta
    }
    
    fn compute_eta(&self, from_h3: u64, to_h3: u64) -> u16 {
        // Try precomputed matrix first
        if let Some(matrix) = &self.distance_matrix {
            if let Some(distance) = matrix.get_distance(from_h3, to_h3) {
                return distance_to_walking_seconds(distance);
            }
        }
        
        // Fallback: compute distance on the fly
        let distance = h3_distance_meters(from_h3, to_h3);
        distance_to_walking_seconds(distance)
    }
    
    /// Clear the cache
    pub fn clear_cache(&mut self) {
        self.cache.clear();
    }
    
    /// Get cache size
    pub fn cache_size(&self) -> usize {
        self.cache.len()
    }
}

impl Default for EtaEstimator {
    fn default() -> Self {
        Self::new()
    }
}

/// Quick estimate without caching (single use)
pub fn estimate_eta_seconds(from_h3: u64, to_h3: u64) -> u16 {
    let distance = h3_distance_meters(from_h3, to_h3);
    distance_to_walking_seconds(distance)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::h3_wrapper::lat_lng_to_h3;
    
    #[test]
    fn test_eta_reasonable() {
        // Times Square (40.7580, -73.9855) to Bryant Park (40.7536, -73.9834)
        let times_sq = lat_lng_to_h3(40.7580, -73.9855, 9).unwrap();
        let bryant_park = lat_lng_to_h3(40.7536, -73.9834, 9).unwrap();
        
        let eta = estimate_eta_seconds(times_sq, bryant_park);
        // Walking 500m at 1.4 m/s = ~357 seconds
        // Accept range 300-500 seconds (accounts for boundary approximation)
        assert!(eta > 300 && eta < 500, "ETA was {} seconds, expected between 300-500", eta);
    }
    
    #[test]
    fn test_estimator_with_cache() {
        let times_sq = lat_lng_to_h3(40.7580, -73.9855, 9).unwrap();
        let bryant_park = lat_lng_to_h3(40.7536, -73.9834, 9).unwrap();
        
        let mut estimator = EtaEstimator::new();
        
        let eta1 = estimator.estimate(times_sq, bryant_park);
        let eta2 = estimator.estimate(times_sq, bryant_park);
        
        assert_eq!(eta1, eta2);
        assert_eq!(estimator.cache_size(), 1);
    }
    
    #[test]
    fn test_same_cell_zero() {
        let h3 = lat_lng_to_h3(40.7580, -73.9855, 9).unwrap();
        let eta = estimate_eta_seconds(h3, h3);
        assert_eq!(eta, 0);
    }
}