//! API request/response models

use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crdt_engine::{Op, VectorClock};

/// Token issuance request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenRequest {
    pub delegate_to_role: String,
    pub subject_member_id: Uuid,
    pub expires_in_seconds: u32,
    pub constraints: TokenConstraints,
    pub delegation_chain_proof: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenConstraints {
    pub allowed_branch_geohashes: Option<Vec<String>>,
    pub max_pickup_radius_km: Option<u32>,
    pub can_verify_members: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub token_jti: Uuid,
    pub expires_at: DateTime<Utc>,
    pub refresh_limit: u32,
}

/// Flare submission request (simplified for anonymous users)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlareSubmission {
    pub signal_flare_id: Option<Uuid>,
    pub request_location: GeoPoint,
    pub device_timestamp: Option<DateTime<Utc>>,
    pub geohash_10: String,
    pub biometric_proof: Option<String>,
    pub client_public_key: Option<String>,
}

/// Simplified flare submission for testing/anonymous users
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleFlareSubmission {
    pub lat: f64,
    pub lng: f64,
    pub geohash10: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoPoint {
    pub lat: f64,
    pub lng: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlareResponse {
    pub flare_id: Uuid,
    pub status: String,
    pub assigned_branch_id: Option<Uuid>,
    pub server_received_time: DateTime<Utc>,
    pub retry_queue_position: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub is_anonymous: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

/// Sync request/response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncPullRequest {
    pub vector_clock: VectorClock,
    pub last_sync_token: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncPushRequest {
    pub pending_ops: Vec<Op>,
    pub vector_clock: VectorClock,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResponse {
    pub accepted_ops: Vec<Uuid>,
    pub conflicts: Vec<Conflict>,
    pub new_vector_clock: VectorClock,
    pub sync_token: String,
    pub server_time: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Conflict {
    pub op_id: Uuid,
    pub resolution: String,
    pub server_state: serde_json::Value,
}

/// Proximity query
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProximityRequest {
    pub geohash_10: String,
    pub radius_km: f64,
    pub include_clergy_contact: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProximityResponse {
    pub branches: Vec<BranchSummary>,
    pub cache_ttl_seconds: u32,
    pub server_time: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BranchSummary {
    pub id: Uuid,
    pub branch_code: String,
    pub distance_meters: f64,
    pub geohash_12: String,
    pub h3_index: String,
    pub allowed_weekdays: Vec<String>,
    pub eta_seconds_offline_estimate: u32,
    pub clergy_contact: Option<String>,
}