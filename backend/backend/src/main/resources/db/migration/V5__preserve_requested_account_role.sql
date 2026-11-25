-- Preserve the public account-type selection without granting those permissions at registration.
ALTER TABLE account_identity_registry
    ADD COLUMN requested_role VARCHAR(32) NOT NULL DEFAULT 'foodie';

UPDATE account_identity_registry r
JOIN clientes c ON c.id = r.identity_id
SET r.requested_role = 'restaurant_admin'
WHERE r.identity_type = 'client'
  AND c.rol = 'restaurant_admin';

UPDATE account_identity_registry
SET requested_role = 'employee'
WHERE identity_type = 'employee';
