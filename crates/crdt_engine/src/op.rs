use serde::{Serialize, Deserialize};
use crypto_core::ed25519::PublicKey;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub enum OpType {
    InsertPickup {
        flare_id: [u8; 16],
        location_h3: String,
        timestamp_ms: u64,
    },
    UpdateStatus {
        flare_id: [u8; 16],
        new_status: PickupStatus,
    },
    AssignClergy {
        flare_id: [u8; 16],
        clergy_h3: String,
        eta_seconds: u16,
    },
    CompletePickup {
        flare_id: [u8; 16],
        completion_proof: String,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum PickupStatus {
    Queued,
    Dispatched,
    EnRoute,
    Completed,
    Expired,
}

impl PickupStatus {
    pub fn can_transition_to(&self, next: &PickupStatus) -> bool {
        match (self, next) {
            (PickupStatus::Queued, PickupStatus::Dispatched) => true,
            (PickupStatus::Queued, PickupStatus::Expired) => true,
            (PickupStatus::Dispatched, PickupStatus::EnRoute) => true,
            (PickupStatus::Dispatched, PickupStatus::Expired) => true,
            (PickupStatus::EnRoute, PickupStatus::Completed) => true,
            (PickupStatus::EnRoute, PickupStatus::Expired) => true,
            _ => false,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Op {
    pub lamport: u64,
    pub peer_id: [u8; 32],
    pub op_type: OpType,
    pub signature: String,
}

impl Op {
    pub fn new(lamport: u64, peer_id: [u8; 32], op_type: OpType, sk: &crypto_core::ed25519::SecretKey) -> Self {
        let mut to_sign = Vec::new();
        to_sign.extend_from_slice(&lamport.to_le_bytes());
        to_sign.extend_from_slice(&peer_id);
        let op_bytes = format!("{:?}", op_type).into_bytes();
        to_sign.extend_from_slice(&op_bytes);
        
        let signature_bytes = crypto_core::ed25519::sign(&to_sign, sk);
        
        Self {
            lamport,
            peer_id,
            op_type,
            signature: hex::encode(signature_bytes.0),
        }
    }
    
    pub fn verify(&self, pk: &PublicKey) -> bool {
        let mut to_sign = Vec::new();
        to_sign.extend_from_slice(&self.lamport.to_le_bytes());
        to_sign.extend_from_slice(&self.peer_id);
        let op_bytes = format!("{:?}", self.op_type).into_bytes();
        to_sign.extend_from_slice(&op_bytes);
        
        let sig_bytes_vec = match hex::decode(&self.signature) {
            Ok(bytes) => bytes,
            Err(_) => return false,
        };
        
        if sig_bytes_vec.len() != 64 {
            return false;
        }
        
        let mut sig_array = [0u8; 64];
        sig_array.copy_from_slice(&sig_bytes_vec);
        let sig_bytes = crypto_core::ed25519::SignatureBytes(sig_array);
        crypto_core::ed25519::verify(&to_sign, &sig_bytes, pk)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crypto_core::ed25519::generate_keypair;
    
    #[test]
    fn test_op_sign_verify() {
        let (pk, sk) = generate_keypair();
        let peer_id = [1u8; 32];
        let op = Op::new(42, peer_id, OpType::InsertPickup {
            flare_id: [0u8; 16],
            location_h3: "89283082873ffff".to_string(),
            timestamp_ms: 1234567890,
        }, &sk);
        
        assert!(op.verify(&pk));
    }
}