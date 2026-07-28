#!/bin/bash
# ================================================================
#  Ayudante (root): arranca MariaDB y crea el usuario admin
#  para phpMyAdmin (usuario: cursalia / contraseña: cursalia)
# ================================================================
systemctl enable --now mariadb 2>/dev/null || service mariadb start 2>/dev/null
sleep 2
mysql -u root <<'SQL'
CREATE USER IF NOT EXISTS 'cursalia'@'localhost' IDENTIFIED BY 'cursalia';
GRANT ALL PRIVILEGES ON *.* TO 'cursalia'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
echo "Base de datos lista. Usuario: cursalia"
