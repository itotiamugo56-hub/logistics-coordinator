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


// Import handlers directly
use handlers::{
    branches, sync, flare, proximity, auth as auth_handlers, clergy
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
        // Public branch endpoints (NO AUTH REQUIRED)
        .route("/v1/branches", get(branches::get_all_branches))
        .route("/v1/branches", post(clergy::create_branch))
        .route("/v1/branches/nearby", post(branches::get_nearby_branches))
        // Sync endpoints
        .route("/v1/sync/pull", post(sync::pull_changes))
        .route("/v1/sync/push", post(sync::push_changes))
        // Flare endpoints
        .route("/v1/flare/submit", post(flare::submit_flare))
        .route("/v1/flare/status/:flare_id", get(flare::get_flare_status))
        // Proximity endpoints
        .route("/v1/location/proximity", post(proximity::find_nearby_branches))
        // Auth endpoints (using auth_handlers)
        .route("/v1/auth/token/issue", post(auth_handlers::issue_token_handler))
        // Clergy login endpoint
        .route("/v1/clergy/login", post(clergy::login))
        // Clergy management endpoints - Branch Details
        .route("/v1/clergy/branch/:branch_id", put(clergy::update_branch))
        // Clergy management endpoints - Service Times
        .route("/v1/clergy/branch/:branch_id/service-times", put(clergy::update_service_times))
        // Clergy management endpoints - Photos
        .route("/v1/clergy/photos/:branch_id", get(clergy::get_photos))
        .route("/v1/clergy/photos/:branch_id", post(clergy::add_photo))
        .route("/v1/clergy/photos/:branch_id/:photo_url", delete(clergy::delete_photo))
        // Clergy management endpoints - Pickup Points
        .route("/v1/clergy/pickup-points/:branch_id", get(clergy::get_pickup_points))
        .route("/v1/clergy/pickup-points/:branch_id", post(clergy::create_pickup_point))
        .route("/v1/clergy/pickup-points/:branch_id/:point_id", put(clergy::update_pickup_point))
        .route("/v1/clergy/pickup-points/:branch_id/:point_id", delete(clergy::delete_pickup_point))
        // Clergy management endpoints - Events
        .route("/v1/clergy/events/:branch_id", get(clergy::get_events))
        .route("/v1/clergy/events/:branch_id", post(clergy::create_event))
        .route("/v1/clergy/events/:branch_id/:event_id", delete(clergy::delete_event))
        // Clergy management endpoints - Alerts
        .route("/v1/clergy/alerts/:branch_id", get(clergy::get_alerts))
        .route("/v1/clergy/alerts/:branch_id", post(clergy::create_alert))
        .route("/v1/clergy/alerts/:branch_id/:alert_id", delete(clergy::delete_alert))
        // Health check
        .route("/health", get(|| async { "OK" }))
        // Middleware
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(db_pool);
    
    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    tracing::info!("Server listening on {}", addr);
    
    // axum 0.7 uses this API
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}