#!/bin/bash
# ================================================================
#  Ayudante (root): prepara la base de datos para WordPress local
# ================================================================
systemctl enable --now mariadb 2>/dev/null || service mariadb start 2>/dev/null
sleep 2
mysql -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS wp_local CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wp_local'@'localhost' IDENTIFIED BY 'wp_local_pass';
GRANT ALL PRIVILEGES ON wp_local.* TO 'wp_local'@'localhost';
FLUSH PRIVILEGES;
SQL
echo "Base de datos lista."
