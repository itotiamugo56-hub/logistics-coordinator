//! Role definitions and permission checks
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Role {
    GlobalAdmin = 0,    // System root - can create anyone
    RegionalAdmin = 1,  // Region manager - can create branch clergy within region
    BranchClergy = 2,   // Branch pastor - can manage their branch
    VerifiedMember = 3, // Authenticated member - can send flares
}

impl Role {
    pub fn level(&self) -> u8 {
        *self as u8
    }
    
    pub fn can_create(&self, target: Role) -> bool {
        match self {
            Role::GlobalAdmin => true,  // Can create anyone
            Role::RegionalAdmin => matches!(target, Role::BranchClergy),  // Can only create branch clergy
            Role::BranchClergy => false,  // Cannot create anyone
            Role::VerifiedMember => false,  // Cannot create anyone
        }
    }
    
    // Legacy method for delegation chain compatibility
    pub fn can_delegate_to(&self) -> Vec<Role> {
        match self {
            Role::GlobalAdmin => vec![Role::RegionalAdmin, Role::BranchClergy],
            Role::RegionalAdmin => vec![Role::BranchClergy],
            Role::BranchClergy => vec![],
            Role::VerifiedMember => vec![],
        }
    }
    
    pub fn from_str(s: &str) -> Self {
        match s {
            "global_admin" => Role::GlobalAdmin,
            "regional_admin" => Role::RegionalAdmin,
            "branch_clergy" => Role::BranchClergy,
            "verified_member" => Role::VerifiedMember,
            _ => Role::VerifiedMember,
        }
    }
}

impl fmt::Display for Role {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Role::GlobalAdmin => "global_admin",
            Role::RegionalAdmin => "regional_admin",
            Role::BranchClergy => "branch_clergy",
            Role::VerifiedMember => "verified_member",
        };
        write!(f, "{}", s)
    }
}