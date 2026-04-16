//! Backend Server Entry Point

use axum::{
    routing::{get, post, put, delete},
    Router,
};
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use std::net::SocketAddr;
use tracing_subscriber;

mod handlers;
mod auth;
mod middleware;
mod models;

// Import handlers functions directly from the handlers module
use handlers::{
    get_all_branches, get_nearby_branches,
    pull_changes, push_changes,
    submit_flare, get_flare_status,
    find_nearby_branches,
    get_me, issue_token_handler,
    login, register_member, verify_otp,
    create_branch,
    update_branch, update_service_times,
    get_photos, add_photo, delete_photo,
    get_pickup_points, create_pickup_point, update_pickup_point, delete_pickup_point,
    get_events, create_event, delete_event,
    get_alerts, create_alert, delete_alert,
    bootstrap_admin, create_regional_admin, create_branch_clergy, list_clergy,
};

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter("backend_api=debug,tower_http=debug")
        .init();
    
    // Initialize database
    let db_pool = sqlite_embedded::init_database("data/logistics.db")
        .expect("Failed to open database");
    sqlite_embedded::run_migrations(&db_pool)
        .expect("Failed to run migrations");
    
    // Build router
    let app = Router::new()
        // ============================================================
        // ADMIN ENDPOINTS (Protected - Role Based)
        // ============================================================
        .route("/v1/admin/bootstrap", post(bootstrap_admin))
        .route("/v1/admin/create-regional", post(create_regional_admin))
        .route("/v1/admin/create-clergy", post(create_branch_clergy))
        .route("/v1/admin/clergy", get(list_clergy))
        
        // ============================================================
        // AUTHENTICATION ENDPOINTS
        // ============================================================
        .route("/v1/auth/login", post(login))
        .route("/v1/auth/register", post(register_member))
        .route("/v1/auth/verify", post(verify_otp))
        .route("/v1/auth/me", get(get_me))
        .route("/v1/auth/token/issue", post(issue_token_handler))
        
        // ============================================================
        // PUBLIC BRANCH ENDPOINTS (NO AUTH REQUIRED)
        // ============================================================
        .route("/v1/branches", get(get_all_branches))
        .route("/v1/branches", post(create_branch))
        .route("/v1/branches/nearby", post(get_nearby_branches))
        
        // ============================================================
        // SYNC ENDPOINTS
        // ============================================================
        .route("/v1/sync/pull", post(pull_changes))
        .route("/v1/sync/push", post(push_changes))
        
        // ============================================================
        // FLARE ENDPOINTS
        // ============================================================
        .route("/v1/flare/submit", post(submit_flare))
        .route("/v1/flare/status/:flare_id", get(get_flare_status))
        
        // ============================================================
        // PROXIMITY ENDPOINTS
        // ============================================================
        .route("/v1/location/proximity", post(find_nearby_branches))
        
        // ============================================================
        // CLERGY LOGIN ENDPOINT (legacy, kept for compatibility)
        // ============================================================
        .route("/v1/clergy/login", post(login))
        
        // ============================================================
        // CLERGY MANAGEMENT ENDPOINTS - Branch Details
        // ============================================================
        .route("/v1/clergy/branch/:branch_id", put(update_branch))
        
        // ============================================================
        // CLERGY MANAGEMENT ENDPOINTS - Service Times
        // ============================================================
        .route("/v1/clergy/branch/:branch_id/service-times", put(update_service_times))
        
        // ============================================================
        // CLERGY MANAGEMENT ENDPOINTS - Photos
        // ============================================================
        .route("/v1/clergy/photos/:branch_id", get(get_photos))
        .route("/v1/clergy/photos/:branch_id", post(add_photo))
        .route("/v1/clergy/photos/:branch_id/:photo_url", delete(delete_photo))
        
        // ============================================================
        // CLERGY MANAGEMENT ENDPOINTS - Pickup Points
        // ============================================================
        .route("/v1/clergy/pickup-points/:branch_id", get(get_pickup_points))
        .route("/v1/clergy/pickup-points/:branch_id", post(create_pickup_point))
        .route("/v1/clergy/pickup-points/:branch_id/:point_id", put(update_pickup_point))
        .route("/v1/clergy/pickup-points/:branch_id/:point_id", delete(delete_pickup_point))
        
        // ============================================================
        // CLERGY MANAGEMENT ENDPOINTS - Events
        // ============================================================
        .route("/v1/clergy/events/:branch_id", get(get_events))
        .route("/v1/clergy/events/:branch_id", post(create_event))
        .route("/v1/clergy/events/:branch_id/:event_id", delete(delete_event))
        
        // ============================================================
        // CLERGY MANAGEMENT ENDPOINTS - Alerts
        // ============================================================
        .route("/v1/clergy/alerts/:branch_id", get(get_alerts))
        .route("/v1/clergy/alerts/:branch_id", post(create_alert))
        .route("/v1/clergy/alerts/:branch_id/:alert_id", delete(delete_alert))
        
        // ============================================================
        // HEALTH CHECK
        // ============================================================
        .route("/health", get(|| async { "OK" }))
        
        // Middleware
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(db_pool);
    
    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    tracing::info!("Server listening on {}", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}