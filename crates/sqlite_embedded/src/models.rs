//! Data models for database entities

use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

/// Pickup status (matches Person B's enum)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum PickupStatus {
    Queued,
    Dispatched,
    EnRoute,
    Completed,
    Expired,
}

impl From<PickupStatus> for &'static str {
    fn from(status: PickupStatus) -> &'static str {
        match status {
            PickupStatus::Queued => "queued",
            PickupStatus::Dispatched => "dispatched",
            PickupStatus::EnRoute => "en_route",
            PickupStatus::Completed => "completed",
            PickupStatus::Expired => "expired",
        }
    }
}

impl From<&str> for PickupStatus {
    fn from(s: &str) -> Self {
        match s {
            "dispatched" => PickupStatus::Dispatched,
            "en_route" => PickupStatus::EnRoute,
            "completed" => PickupStatus::Completed,
            "expired" => PickupStatus::Expired,
            _ => PickupStatus::Queued,
        }
    }
}

/// Pickup log record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PickupLog {
    pub id: Uuid,
    pub flare_id: Uuid,
    pub member_id: Uuid,
    pub assigned_branch_id: Option<Uuid>,
    pub request_h3_index: String,
    pub request_time: DateTime<Utc>,
    pub status: PickupStatus,
    pub eta_seconds: Option<u16>,
    pub clergy_contact_ephemeral: Option<Vec<u8>>,
    pub lamport_timestamp: u64,
    pub peer_id: [u8; 32],
}

/// Branch record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Branch {
    pub id: Uuid,
    pub branch_code: String,
    pub h3_index_9: String,
    pub parent_branch_id: Option<Uuid>,
    pub allowed_weekdays: Vec<String>,
    pub is_authenticated: bool,
    pub clergy_contact_encrypted: Option<Vec<u8>>,
}

/// Member record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Member {
    pub id: Uuid,
    pub canonical_id: String,
    pub public_key: Vec<u8>,
    pub hardware_attestation: Option<Vec<u8>>,
    pub biometric_hash: Option<Vec<u8>>,
    pub enrolled_at: DateTime<Utc>,
    pub is_active: bool,
    pub recovery_h3_index: Option<String>,
}