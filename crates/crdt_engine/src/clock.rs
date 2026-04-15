use std::collections::BTreeMap;
use serde::{Serialize, Deserialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct VectorClock {
    pub entries: BTreeMap<[u8; 32], u64>,
}

impl VectorClock {
    pub fn new() -> Self {
        Self {
            entries: BTreeMap::new(),
        }
    }
    
    pub fn increment(&mut self, peer_id: [u8; 32]) -> u64 {
        let counter = self.entries.entry(peer_id).or_insert(0);
        *counter += 1;
        *counter
    }
    
    pub fn set(&mut self, peer_id: [u8; 32], value: u64) {
        self.entries.insert(peer_id, value);
    }
    
    pub fn get(&self, peer_id: &[u8; 32]) -> u64 {
        *self.entries.get(peer_id).unwrap_or(&0)
    }
    
    pub fn merge(&mut self, other: &VectorClock) {
        for (peer_id, counter) in &other.entries {
            let entry = self.entries.entry(*peer_id).or_insert(0);
            *entry = (*entry).max(*counter);
        }
    }
    
    /// Check if this clock is causally after another
    pub fn is_after(&self, other: &VectorClock) -> bool {
        let mut has_greater = false;
        
        // Get all unique peer IDs from both clocks
        let mut all_peers = std::collections::HashSet::new();
        for peer_id in self.entries.keys() {
            all_peers.insert(*peer_id);
        }
        for peer_id in other.entries.keys() {
            all_peers.insert(*peer_id);
        }
        
        for peer_id in all_peers {
            let self_counter = self.get(&peer_id);
            let other_counter = other.get(&peer_id);
            
            if self_counter < other_counter {
                return false;
            }
            if self_counter > other_counter {
                has_greater = true;
            }
        }
        
        has_greater
    }
    
    /// Check if this clock is causally before another
    pub fn is_before(&self, other: &VectorClock) -> bool {
        other.is_after(self)
    }
    
    /// Check if clocks are concurrent
    pub fn is_concurrent(&self, other: &VectorClock) -> bool {
        !self.is_after(other) && !other.is_after(self)
    }
}

impl Default for VectorClock {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_vector_clock_merge() {
        let peer1 = [1u8; 32];
        let peer2 = [2u8; 32];
        
        let mut clock1 = VectorClock::new();
        clock1.increment(peer1);
        clock1.increment(peer1);
        
        let mut clock2 = VectorClock::new();
        clock2.increment(peer2);
        
        clock1.merge(&clock2);
        
        assert_eq!(clock1.get(&peer1), 2);
        assert_eq!(clock1.get(&peer2), 1);
    }
    
    #[test]
    fn test_causal_ordering() {
        let peer = [1u8; 32];
        let mut clock1 = VectorClock::new();
        clock1.increment(peer);
        
        let mut clock2 = VectorClock::new();
        clock2.increment(peer);
        clock2.increment(peer);
        
        assert!(clock2.is_after(&clock1));
        assert!(!clock1.is_after(&clock2));
    }
    
    #[test]
    fn test_concurrent_clocks() {
        let peer1 = [1u8; 32];
        let peer2 = [2u8; 32];
        
        let mut clock1 = VectorClock::new();
        clock1.increment(peer1);
        
        let mut clock2 = VectorClock::new();
        clock2.increment(peer2);
        
        assert!(clock1.is_concurrent(&clock2));
        assert!(!clock1.is_after(&clock2));
        assert!(!clock2.is_after(&clock1));
    }
    
    #[test]
    fn test_is_after_with_same_peer() {
        let peer = [1u8; 32];
        let mut clock1 = VectorClock::new();
        clock1.set(peer, 1);
        
        let mut clock2 = VectorClock::new();
        clock2.set(peer, 2);
        
        assert!(clock2.is_after(&clock1));
        assert!(!clock1.is_after(&clock2));
    }
}