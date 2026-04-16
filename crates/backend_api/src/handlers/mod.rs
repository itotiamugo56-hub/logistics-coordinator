//! Handlers module - defines all handler functions

// Declare the handler modules (these point to files in the same directory)
pub mod branches;
pub mod sync;
pub mod flare;
pub mod proximity;
pub mod clergy;
pub mod admin;

// Re-export the handler functions
pub use branches::*;
pub use sync::*;
pub use flare::*;
pub use proximity::*;
pub use clergy::*;

// Admin handler exports
pub use admin::{
    bootstrap_admin, create_regional_admin, create_branch_clergy, list_clergy,
};

// Auth handlers - re-exported from crate::auth
pub use crate::auth::{
    login, register_member, verify_otp, get_me, issue_token_handler,
};