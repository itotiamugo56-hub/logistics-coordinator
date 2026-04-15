//! Middleware modules for request processing

pub mod auth;

// Re-export commonly used types
pub use auth::{AuthenticatedUser, OptionalAuthUser, RequireRole, RevocationList};