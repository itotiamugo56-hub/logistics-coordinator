use crate::op::{Op, OpType, PickupStatus};
use crate::clock::VectorClock;
use std::collections::HashMap;
use serde::{Serialize, Deserialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FlareState {
    pub flare_id: [u8; 16],
    pub status: PickupStatus,
    pub location_h3: String,
    pub assigned_clergy_h3: Option<String>,
    pub eta_seconds: Option<u16>,
    pub lamport: u64,  // Use lamport timestamp for ordering instead of vector clock
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CRDTState {
    pub flares: HashMap<[u8; 16], FlareState>,
    pub vector_clock: VectorClock,
}

impl CRDTState {
    pub fn new() -> Self {
        Self {
            flares: HashMap::new(),
            vector_clock: VectorClock::new(),
        }
    }
    
    pub fn apply(&mut self, op: &Op, peer_id: [u8; 32]) -> Result<(), String> {
        // Update vector clock for this peer
        self.vector_clock.increment(peer_id);
        
        match &op.op_type {
            OpType::InsertPickup { flare_id, location_h3, timestamp_ms: _ } => {
                // Only insert if not exists OR new op has higher lamport
                if let Some(existing) = self.flares.get(flare_id) {
                    if op.lamport <= existing.lamport {
                        return Ok(());
                    }
                }
                
                self.flares.insert(*flare_id, FlareState {
                    flare_id: *flare_id,
                    status: PickupStatus::Queued,
                    location_h3: location_h3.clone(),
                    assigned_clergy_h3: None,
                    eta_seconds: None,
                    lamport: op.lamport,
                });
            }
            
            OpType::UpdateStatus { flare_id, new_status } => {
                if let Some(flare) = self.flares.get_mut(flare_id) {
                    if op.lamport > flare.lamport && flare.status.can_transition_to(new_status) {
                        flare.status = new_status.clone();
                        flare.lamport = op.lamport;
                    }
                } else {
                    // Create new flare with this status
                    self.flares.insert(*flare_id, FlareState {
                        flare_id: *flare_id,
                        status: new_status.clone(),
                        location_h3: "unknown".to_string(),
                        assigned_clergy_h3: None,
                        eta_seconds: None,
                        lamport: op.lamport,
                    });
                }
            }
            
            OpType::AssignClergy { flare_id, clergy_h3, eta_seconds } => {
                if let Some(flare) = self.flares.get_mut(flare_id) {
                    if op.lamport > flare.lamport {
                        flare.assigned_clergy_h3 = Some(clergy_h3.clone());
                        flare.eta_seconds = Some(*eta_seconds);
                        if flare.status == PickupStatus::Queued {
                            flare.status = PickupStatus::Dispatched;
                        }
                        flare.lamport = op.lamport;
                    }
                } else {
                    self.flares.insert(*flare_id, FlareState {
                        flare_id: *flare_id,
                        status: PickupStatus::Dispatched,
                        location_h3: "unknown".to_string(),
                        assigned_clergy_h3: Some(clergy_h3.clone()),
                        eta_seconds: Some(*eta_seconds),
                        lamport: op.lamport,
                    });
                }
            }
            
            OpType::CompletePickup { flare_id, completion_proof: _ } => {
                if let Some(flare) = self.flares.get_mut(flare_id) {
                    if op.lamport > flare.lamport {
                        flare.status = PickupStatus::Completed;
                        flare.lamport = op.lamport;
                    }
                } else {
                    self.flares.insert(*flare_id, FlareState {
                        flare_id: *flare_id,
                        status: PickupStatus::Completed,
                        location_h3: "unknown".to_string(),
                        assigned_clergy_h3: None,
                        eta_seconds: None,
                        lamport: op.lamport,
                    });
                }
            }
        }
        
        Ok(())
    }
    
    /// Merge another CRDT state into this one
    pub fn merge(&mut self, other: &CRDTState) {
        for (flare_id, other_flare) in &other.flares {
            match self.flares.get_mut(flare_id) {
                Some(local_flare) => {
                    // Higher lamport wins
                    if other_flare.lamport > local_flare.lamport {
                        self.flares.insert(*flare_id, other_flare.clone());
                    }
                }
                None => {
                    self.flares.insert(*flare_id, other_flare.clone());
                }
            }
        }
        
        self.vector_clock.merge(&other.vector_clock);
    }
}

impl Default for CRDTState {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::op::Op;
    use crypto_core::ed25519::generate_keypair;
    
    #[test]
    fn test_insert_then_update_same_state() {
        let (_pk, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let mut state = CRDTState::new();
        
        let insert_op = Op::new(1, peer_id, OpType::InsertPickup {
            flare_id: [1u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        state.apply(&insert_op, peer_id).unwrap();
        
        let update_op = Op::new(2, peer_id, OpType::UpdateStatus {
            flare_id: [1u8; 16],
            new_status: PickupStatus::Dispatched,
        }, &sk);
        state.apply(&update_op, peer_id).unwrap();
        
        let flare = state.flares.get(&[1u8; 16]).unwrap();
        assert_eq!(flare.status, PickupStatus::Dispatched);
        assert_eq!(flare.lamport, 2);
    }
    
    #[test]
    fn test_update_before_insert_out_of_order() {
        let (_pk, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let mut state = CRDTState::new();
        
        // Update with higher lamport arrives first
        let update_op = Op::new(2, peer_id, OpType::UpdateStatus {
            flare_id: [1u8; 16],
            new_status: PickupStatus::Dispatched,
        }, &sk);
        state.apply(&update_op, peer_id).unwrap();
        
        // Insert with lower lamport arrives later
        let insert_op = Op::new(1, peer_id, OpType::InsertPickup {
            flare_id: [1u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        state.apply(&insert_op, peer_id).unwrap();
        
        // Status should remain Dispatched (higher lamport wins)
        let flare = state.flares.get(&[1u8; 16]).unwrap();
        assert_eq!(flare.status, PickupStatus::Dispatched);
        assert_eq!(flare.lamport, 2);
    }
    
    #[test]
    fn test_merge_two_states() {
        let (_pk, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let mut state1 = CRDTState::new();
        let insert_op = Op::new(1, peer_id, OpType::InsertPickup {
            flare_id: [1u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        state1.apply(&insert_op, peer_id).unwrap();
        
        let mut state2 = CRDTState::new();
        let update_op = Op::new(2, peer_id, OpType::UpdateStatus {
            flare_id: [1u8; 16],
            new_status: PickupStatus::Dispatched,
        }, &sk);
        state2.apply(&update_op, peer_id).unwrap();
        
        // Merge state2 into state1
        state1.merge(&state2);
        
        let flare = state1.flares.get(&[1u8; 16]).unwrap();
        assert_eq!(flare.status, PickupStatus::Dispatched);
        assert_eq!(flare.lamport, 2);
    }
    
    #[test]
    fn test_idempotent_insert() {
        let (_pk, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let mut state = CRDTState::new();
        let op = Op::new(1, peer_id, OpType::InsertPickup {
            flare_id: [1u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        
        state.apply(&op, peer_id).unwrap();
        state.apply(&op, peer_id).unwrap();
        
        assert_eq!(state.flares.len(), 1);
    }
    
    #[test]
    fn test_merge_preserves_newer_state() {
        let (_pk, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        
        let mut state1 = CRDTState::new();
        let op1 = Op::new(1, peer_id, OpType::InsertPickup {
            flare_id: [1u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1000,
        }, &sk);
        state1.apply(&op1, peer_id).unwrap();
        
        let mut state2 = CRDTState::new();
        let op2 = Op::new(2, peer_id, OpType::UpdateStatus {
            flare_id: [1u8; 16],
            new_status: PickupStatus::Dispatched,
        }, &sk);
        state2.apply(&op2, peer_id).unwrap();
        
        // Merge both ways
        state1.merge(&state2);
        assert_eq!(state1.flares.get(&[1u8; 16]).unwrap().status, PickupStatus::Dispatched);
        
        let mut state3 = CRDTState::new();
        state3.apply(&op1, peer_id).unwrap();
        state3.merge(&state2);
        assert_eq!(state3.flares.get(&[1u8; 16]).unwrap().status, PickupStatus::Dispatched);
    }
}