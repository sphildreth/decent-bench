SET NAMES utf8mb4;

CREATE TABLE `v25_native_features` (
  `id` INT NOT NULL,
  `status_enum` ENUM('draft','published') NOT NULL,
  `temporal_timestamptz` TIMESTAMPTZ,
  `temporal_date` DATE,
  `temporal_time` TIME,
  `interval_span` INTERVAL DAY TO SECOND,
  `ip_address` INET,
  `ip_network` CIDR,
  `mac_address` MACADDR,
  `geometry_hex` GEOMETRY,
  `branch_token` UUID,
  `branch_name` VARCHAR(64),
  `revenue` DECIMAL(10,2) NOT NULL
);

INSERT INTO `v25_native_features`
  (`id`, `status_enum`, `temporal_timestamptz`, `temporal_date`, `temporal_time`, `interval_span`, `ip_address`, `ip_network`, `mac_address`, `geometry_hex`, `branch_token`, `branch_name`, `revenue`)
VALUES
  (1, 'published', '2026-05-19 12:34:56+00', '2026-05-01', '09:30:00', '1 day', '192.168.1.15', '10.0.0.0/24', '08:00:27:13:69:77', 'POINT(1 2)', '550e8400-e29b-41d4-a716-446655440000', 'release', 1234.50);
