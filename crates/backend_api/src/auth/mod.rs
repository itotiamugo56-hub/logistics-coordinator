pub mod jwt;
pub mod roles;
pub mod delegation;
pub mod handlers;  // Add this line

// Re-export commonly used types
pub use jwt::{
    issue_token, issue_temp_token, validate_token, validate_token_offline,
    TokenClaims, TokenConstraints, VerificationStatus, AuthError, token_lifetime,
};
pub use roles::Role;
pub use delegation::{DelegationProof, build_delegation_chain, verify_delegation_chain};