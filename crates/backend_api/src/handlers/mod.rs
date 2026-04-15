//! Handlers module - defines all handler functions

// Declare the handler modules (these point to files in the same directory)
pub mod branches;
pub mod sync;
pub mod flare;
pub mod proximity;
pub mod clergy;

// Re-export the handler functions
pub use branches::*;
pub use sync::*;
pub use flare::*;
pub use proximity::*;
pub use clergy::*;

// Auth handlers - simplified version (login only)
pub use crate::auth::handlers::{
    login, get_me, issue_token_handler,
};