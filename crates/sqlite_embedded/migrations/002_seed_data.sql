-- Insert a test branch
INSERT OR IGNORE INTO branches (
    id, name, address, latitude, longitude, senior_pastor, phone, email, service_times, created_at, updated_at
) VALUES (
    '11111111-1111-1111-1111-111111111111',
    'Nairobi Central',
    'Moi Avenue, Nairobi CBD',
    '-1.286389',
    '36.817223',
    'Pastor John Mwangi',
    '+254711222333',
    'central@repentance.org',
    '{"sunday": ["8:00 AM", "10:00 AM", "12:00 PM"]}',
    strftime('%s', 'now'),
    strftime('%s', 'now')
);

-- Insert a clergy user for testing
INSERT OR IGNORE INTO clergy_users (
    id, email, name, branch_id, created_at
) VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'clergy@branch.org',
    'Test Clergy',
    '11111111-1111-1111-1111-111111111111',
    strftime('%s', 'now')
);