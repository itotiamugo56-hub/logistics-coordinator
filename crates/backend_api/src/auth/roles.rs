//! Role definitions and permission checks

use serde::{Serialize, Deserialize};
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Role {
    GlobalAdmin = 0,    // System root
    RegionalAdmin = 1,  // Region manager
    BranchPastor = 2,   // Branch owner
    BranchStaff = 3,    // Branch employee
    VerifiedMember = 4, // Authenticated member
    // Usher is an alias - we handle it in From impl, not as separate discriminant
}

impl Role {
    pub fn level(&self) -> u8 {
        *self as u8
    }
    
    pub fn can_delegate_to(&self) -> Vec<Role> {
        match self {
            Role::GlobalAdmin => vec![Role::RegionalAdmin, Role::BranchPastor],
            Role::RegionalAdmin => vec![Role::BranchPastor],
            Role::BranchPastor => vec![Role::BranchStaff, Role::VerifiedMember],
            Role::BranchStaff => vec![Role::VerifiedMember],
            Role::VerifiedMember => vec![],
        }
    }
    
    pub fn requires_hardware_auth(&self) -> bool {
        matches!(self, Role::GlobalAdmin | Role::RegionalAdmin | Role::BranchPastor)
    }
    
    pub fn token_lifetime_seconds(&self) -> i64 {
        match self {
            Role::GlobalAdmin => 604800,     // 7 days
            Role::RegionalAdmin => 604800,   // 7 days
            Role::BranchPastor => 259200,    // 3 days
            Role::BranchStaff => 86400,      // 1 day
            Role::VerifiedMember => 43200,   // 12 hours
        }
    }
}

impl fmt::Display for Role {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Role::GlobalAdmin => "GlobalAdmin",
            Role::RegionalAdmin => "RegionalAdmin",
            Role::BranchPastor => "BranchPastor",
            Role::BranchStaff => "BranchStaff",
            Role::VerifiedMember => "VerifiedMember",
        };
        write!(f, "{}", s)
    }
}

impl From<&str> for Role {
    fn from(s: &str) -> Self {
        match s {
            "GlobalAdmin" => Role::GlobalAdmin,
            "RegionalAdmin" => Role::RegionalAdmin,
            "BranchPastor" => Role::BranchPastor,
            "BranchStaff" => Role::BranchStaff,
            "VerifiedMember" => Role::VerifiedMember,
            "Usher" => Role::VerifiedMember,  // Usher maps to VerifiedMember
            _ => Role::VerifiedMember,
        }
    }
}

/// Check if a role meets or exceeds the required role
pub fn check_role_sufficient(actual: Role, required: Role) -> bool {
    actual.level() <= required.level()  // Lower number = higher privilege
}