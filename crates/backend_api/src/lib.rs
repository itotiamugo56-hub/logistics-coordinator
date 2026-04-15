//! Backend API Library

// Declare the handlers submodule (this points to src/handlers/mod.rs)
pub mod handlers;
pub mod auth;
pub mod middleware;
pub mod models;

// Re-export main types
pub use auth::{TokenClaims, Role, validate_token, issue_token};
pub use middleware::AuthenticatedUser;