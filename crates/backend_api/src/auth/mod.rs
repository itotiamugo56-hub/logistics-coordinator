pub mod jwt;
pub mod roles;
pub mod delegation;
pub mod handlers;

// Re-export commonly used types
pub use jwt::{
    issue_token, issue_temp_token, validate_token, validate_token_offline,
    TokenClaims, TokenConstraints, VerificationStatus, AuthError, token_lifetime,
};
pub use roles::Role;
pub use delegation::{DelegationProof, build_delegation_chain, verify_delegation_chain};

// Re-export handler functions
pub use handlers::{
    login, register_member, verify_otp, get_me, issue_token_handler,
};