//! HTTP request handlers

pub mod sync;
pub mod flare;
pub mod proximity;
pub mod auth;
pub mod branches;
pub mod clergy;

pub use sync::{pull_changes, push_changes};
pub use flare::{submit_flare, get_flare_status};
pub use proximity::find_nearby_branches;
pub use auth::issue_token_handler;
pub use branches::{get_all_branches, get_nearby_branches};
pub use clergy::{
    get_pickup_points, create_pickup_point, update_pickup_point, delete_pickup_point,
    get_events, create_event, delete_event,
    get_alerts, create_alert, delete_alert,
    login,
};