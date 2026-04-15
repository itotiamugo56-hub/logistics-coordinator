//! Backend API for Zero-Trust Offline Logistics Platform

pub mod auth;
pub mod handlers;
pub mod middleware;
pub mod models;

// Re-export main types
pub use auth::{TokenClaims, Role, validate_token, issue_token};
pub use middleware::AuthenticatedUser;