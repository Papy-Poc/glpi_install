 #!/bin/bash
#
# GLPI install script
#
# Author: PapyPoc
# Version: 1.0.0
#

function warn(){
    echo -e '\e[31m'$1'\e[0m';
}
function info(){
    echo -e '\e[36m'$1'\e[0m';
}

function check_root()
{
# Vérification des privilèges root
if [[ "$(id -u)" -ne 0 ]]
then
        warn "Ce script doit être exécuté en tant que root" >&2
  exit 1
else
        info "Privilège Root: OK"
fi
}

function check_distro()
{
info "Installation du paquet des release"
apt install -y lsb-release > /dev/null 2>&1
# Constante pour les versions de Debian acceptables
DEBIAN_VERSIONS=("11" "12")
# Constante pour les versions d'Ubuntu acceptables
UBUNTU_VERSIONS=("23.10")
# Récupération du nom de la distribution
DISTRO=$(lsb_release -is 2>/dev/null)
# Récupération de la version de la distribution
VERSION=$(lsb_release -rs 2>/dev/null)
# Vérifie si c'est une distribution Debian
if [ "$DISTRO" == "Debian" ]; then
        # Vérifie si la version de Debian est acceptable
        if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "La version de votre systeme d'exploitation ($DISTRO $VERSION) est compatible."
        else
                warn "La version de votre système d'exploitation ($DISTRO $VERSION) n'est pas considérée comme compatible."
                warn "Voulez-vous toujours forcer l'installation ? Attention, si vous choisissez de forcer le script, c'est à vos risques et périls."
                info "Êtes-vous sûr de vouloir continuer ? [yes/no]"
                read response
                if [ $response == "yes" ]; then
                info "Continuing..."
                elif [ $response == "no" ]; then
                info "Exiting..."
                exit 1
                else
                warn "Réponse non valide. Quitter..."
                exit 1
                fi
        fi

# Vérifie si c'est une distribution Ubuntu
elif [ "$DISTRO" == "Ubuntu" ]; then
        # Vérifie si la version d'Ubuntu est acceptable
        if [[ " ${UBUNTU_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "La version de votre système d'exploitation ($DISTRO $VERSION) est compatible."
        else
                warn "Your operating system version ($DISTRO $VERSION) is not noted as compatible."
                warn "Voulez-vous toujours forcer l'installation ? Attention, si vous choisissez de forcer le script, c'est à vos risques et périls."
                info "Êtes-vous sûr de vouloir continuer ? [yes/no]"
                read response
                if [ $response == "yes" ]; then
                info "Continuing..."
                elif [ $response == "no" ]; then
                info "Exiting..."
                exit 1
                else
                warn "Réponse non valide. Quitter..."
                exit 1
                fi
        fi
# Si c'est une autre distribution
else
        warn "Il s'agit d'une autre distribution que Debian ou Ubuntu qui n'est pas compatible."
        exit 1
fi
}

function network_info()
{
INTERFACE=$(ip route | awk 'NR==1 {print $5}')
IPADRESS=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)
}

function install_packages()
{
info "Installation des paquets..."
sleep 1
info "Recherche des mise à jour"
apt update > /dev/null 2>&1
info "Application des mise à jour"
apt upgrade -y > /dev/null 2>&1
info "Installation des service lamp..."
apt install -y --no-install-recommends apache2 mariadb-server perl curl jq php > /dev/null 2>&1
info "Installation des extensions de php"
apt install -y --no-install-recommends php-ldap php-imap php-apcu php-xmlrpc php-cas php-mysqli php-mbstring php-curl php-gd php-simplexml php-xml php-intl php-zip php-bz2 php-imap php-apcu php-ldap php8.2-fpm > /dev/null 2>&1
systemctl enable mariadb > /dev/null 2>&1
info "Activation d'Apache"
systemctl enable apache2 > /dev/null 2>&1
info "Redémarage d'Apache"
systemctl restart apache2 > /dev/null 2>&1
}

function mariadb_configure()
{
info "Configuration de MariaDB"
sleep 1
SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
systemctl start mariadb > /dev/null 2>&1
(echo ""; echo "y"; echo "y"; echo "$SLQROOTPWD"; echo "$SLQROOTPWD"; echo "y"; echo "y"; echo "y"; echo "y") | mysql_secure_installation > /dev/null 2>&1
sleep 1

# Remove the test database
mysql -e "DROP DATABASE IF EXISTS test" > /dev/null 2>&1
# Reload privileges
mysql -e "FLUSH PRIVILEGES" > /dev/null 2>&1
# Création de la Base De Données
mysql -e "CREATE DATABASE glpi" > /dev/null 2>&1
# Création de l'utilisateur
mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD'" > /dev/null 2>&1
# Permission de la BDD pour le compte glpi_user
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost'" > /dev/null 2>&1
# Reload privileges
mysql -e "FLUSH PRIVILEGES" > /dev/null 2>&1

# Initialize time zones datas
info "Configuration de TimeZone"
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p"$SLQROOTPWD" mysql > /dev/null 2>&1
#Ask tz
echo "Europe/Paris" | sudo dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1
systemctl restart mariadb
sleep 1
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'" > /dev/null 2>&1
}

function install_glpi()
{
info "Téléchargement et installation de la dernière version de GLPI..."
# Get download link for the latest release
DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK > /dev/null 2>&1
tar xzf /tmp/glpi-latest.tgz -C /var/www/html/
# Création répertoire pour les fichiers de logs
mkdir /var/www/html/glpi/logs
# Création répertoire pour les fichiers de configuration de GLPI
mkdir /etc/glpi
chown www-data /etc/glpi/
chmod 775 /etc/glpi
mv /var/www/glpi/config /etc/glpi
mkdir /var/lib/glpi
chown www-data /var/lib/glpi/
chmod 775 /var/lib/glpi/
mv /var/www/glpi/files /var/lib/glpi
mkdir /var/log/glpi
chown www-data /var/log/glpi
chmod 775 /var/log/glpi
# Création du fichier downstream.php
cat > /var/www/glpi/inc/downstream.php << EOF
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF
# Création du fichier local_define.php
cat > /etc/glpi/local_define.php << EOF
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi/files');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

#Disable Apache Web Server Signature
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

# Setup Cron task
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

function setup_db()
{
info "Mise en place de GLPI..."
cd /var/www/html/glpi
php bin/console db:install --db-name=glpi --db-user=glpi_user --db-host="localhost" --db-port=3306 --db-password=$SQLGLPIPWD --default-language="fr_FR" --no-interaction --force
rm -rf /var/www/html/glpi/install
}

function setup_apache-php()
{
info "Mise en place de Apache et PHP..."

# Add permissions
chown -R www-data:www-data /var/www/html
chmod 755 /var/www/html/glpi

# Setup vhost
cat > /etc/apache2/sites-available/glpi.conf << EOF
<VirtualHost *:80>
 ServerName glpi.lan

    DocumentRoot /var/www/glpi/public

    # If you want to place GLPI in a subfolder of your site (e.g. your virtual host is serving multiple applications),
    # you can use an Alias directive. If you do this, the DocumentRoot directive MUST NOT target the GLPI directory itself.
    # Alias "/glpi" "/var/www/glpi/public"

    <Directory /var/www/glpi/public>
        Require all granted
        RewriteEngine On
        # Redirect all requests to GLPI router, unless file exists.
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.2-fpm.sock|fcgi://localhost/"
    </FilesMatch>
</VirtualHost>
EOF

a2dissite 000-default.conf > /dev/null 2>&1
a2ensite glpi.conf > /dev/null 2>&1

#Activation du module rewrite d'apache
a2enmod rewrite > /dev/null 2>&1

# Sécurisation des cookie
phpversion=$(php -v | grep -i '(cli)' | awk '{print $2}' | cut -c 1,2,3)
sed -i '/^\s*;*\s*session\.cookie_secure\s*=.*/s/^;\(\s*session\.cookie_secure\s*=\s*\).*/\1 on/' /etc/php/$phpversion/fpm/php.ini
sed -i '/^\s*;*\s*session\.cookie_httponly\s*=.*/s/^;\(\s*session\.cookie_httponly\s*=\s*\).*/\1 on/' /etc/php/$phpversion/fpm/php.ini
sed -i '/^\s*;*\s*session\.cookie_samesite\s*=.*/s/^;\(\s*session\.cookie_samesite\s*=\s*\).*/\1 Lax/' /etc/php/$phpversion/fpm/php.ini
systemctl restart php$phpversion-fpm.service
systemctl restart apache2 > /dev/null 2>&1
}

function display_credentials()
{
info "===========================> Détail de l'installation de GLPI <=================================="
warn "Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables."
info "==> GLPI :"
info "Les comptes utilisateurs par défaut sont :"
info "UTILISATEUR       -  MOT DE PASSE       -  ACCÈS"
info "glpi              -  glpi               -  compte admin,"
info "tech              -  tech               -  compte technicien,"
info "normal            -  normal             -  compte normal,"
info "post-only         -  postonly           -  compte post-simple."
echo ""
info "Vous pouvez accéder à la page web de GLPI à partir d'une adresse IP ou d'un nom d'hôte :"
info "http://$IPADRESS" 
echo ""
info "==> Database:"
info "Mot de passe root: $SLQROOTPWD"
info "Mot de passe glpi_user: $SQLGLPIPWD"
info "Nom de la base de donné GLPI: glpi"
info "<===============================================================================================>"
echo ""
info "Si vous rencontrez un problème avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues"
}

function write_credentials()
{
cat <<EOF > $HOME/sauve_mdp.txt
==============================> GLPI installation details  <=====================================
Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables.
==> GLPI :
Les comptes utilisateurs par défaut sont :
UTILISATEUR       -  MOT DE PASSE       -  ACCÈS
glpi              -  glpi               -  compte admin
tech              -  tech               -  compte technicien
normal            -  normal             -  compte normal
post-only         -  postonly           -  compte post-simple

Vous pouvez accéder à la page web de GLPI à partir d'une adresse IP ou d'un nom d'hôte :
http://$IPADRESS 

==> Database:
Mot de passe root: $SLQROOTPWD
Mot de passe glpi_user: $SQLGLPIPWD
Nom de la base de donné GLPI: glpi
<===============================================================================================>

Si vous rencontrez un problème avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues
EOF
chmod 700 $HOME/sauve_mdp.txt
echo ""
warn "Fichier de sauvegarde des mots de passe enregistrer dans /home"
echo ""
}

clear
check_root
check_distro
network_info
install_packages
mariadb_configure
install_glpi
setup_db
setup_apache-php
display_credentials
write_credentials