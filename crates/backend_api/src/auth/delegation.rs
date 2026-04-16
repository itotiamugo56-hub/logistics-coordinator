//! Delegation chain validation

use serde::{Serialize, Deserialize};
use uuid::Uuid;
use crate::auth::roles::Role;
use super::jwt::AuthError;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DelegationProof {
    pub issuer_id: Uuid,
    pub issuer_role: Role,
    pub signature: Vec<u8>,
    pub timestamp: i64,
}

/// Verify the delegation chain in token claims
pub fn verify_delegation_chain(claims: &super::jwt::TokenClaims) -> Result<(), AuthError> {
    if claims.delegation_chain.is_empty() {
        return Ok(());
    }
    
    // Check chain length (max 5)
    if claims.delegation_chain.len() > 5 {
        return Err(AuthError::InvalidDelegation);
    }
    
    let mut previous_role: Option<Role> = None;
    
    for (_i, proof) in claims.delegation_chain.iter().enumerate() {
        // Verify role delegation is valid
        if let Some(prev_role) = previous_role {
            if !prev_role.can_delegate_to().contains(&proof.issuer_role) {
                return Err(AuthError::InvalidDelegation);
            }
        }
        
        previous_role = Some(proof.issuer_role);
    }
    
    // Verify final role matches claim
    if let Some(last) = claims.delegation_chain.last() {
        if !last.issuer_role.can_delegate_to().contains(&claims.role) {
            return Err(AuthError::InvalidDelegation);
        }
    }
    
    Ok(())
}

/// Build delegation chain from parent token
pub fn build_delegation_chain(parent_claims: &super::jwt::TokenClaims) -> Vec<DelegationProof> {
    let mut chain = parent_claims.delegation_chain.clone();
    
    chain.push(DelegationProof {
        issuer_id: parent_claims.sub,
        issuer_role: parent_claims.role,
        signature: vec![],  // Will be signed in production
        timestamp: chrono::Utc::now().timestamp(),
    });
    
    chain
}