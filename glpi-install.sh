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
        info "Root privilege: OK"
fi
}
apt update 1>/dev/null && apt upgrade -y  1>/dev/null
apt install lsb-release -y  1>/dev/null
function check_distro()
{
# Constante pour les versions de Debian acceptables
DEBIAN_VERSIONS=("11" "12")

# Constante pour les versions d'Ubuntu acceptables
UBUNTU_VERSIONS=("22.04")

# Récupération du nom de la distribution
DISTRO=$(lsb_release -is 2>/dev/null)

# Récupération de la version de la distribution
VERSION=$(lsb_release -rs 2>/dev/null)

# Vérifie si c'est une distribution Debian
if [ "$DISTRO" == "Debian" ]; then
        # Vérifie si la version de Debian est acceptable
        if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "La version de votre système d'exploitation ($DISTRO $VERSION) est compatible."
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

function confirm_installation()
{
warn "Ce script va maintenant installer les paquets nécessaires à l'installation et à la configuration de GLPI."
info "Êtes-vous sûr de vouloir continuer ? [yes/no]"
read confirm
if [ $confirm == "yes" ]; then
        info "Continer..."
elif [ $confirm == "no" ]; then
        info "Sortir..."
        exit 1
else
        warn "Réponse non valide. Sortir..."
        exit 1
fi
}

function install_packages()
{
info "Installation des paquets..."
sleep 1
apt install -y --no-install-recommends apache2 mariadb-server perl curl jq php 1>/dev/null
info "Installing php extensions..."
apt install -y --no-install-recommends php-ldap php-imap php-apcu php-xmlrpc php-cas php-mysqli php-mbstring php-curl php-gd php-simplexml php-xml php-intl php-zip php-bz2 1>/dev/null
systemctl enable mariadb
phpversion=$(php -v | grep -i '(cli)' | awk '{print $2}' | cut -c 1,2,3)
sed -i 's/^;session.cookie_httponly =/session.cookie_httponly = On/g' /etc/php/$phpversion/cli/php.ini
systemctl enable apache2
}

function mariadb_configure()
{
info "Configuring MariaDB..."
sleep 1
SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
systemctl start mariadb
(echo ""; echo "y"; echo "y"; echo "$SLQROOTPWD"; echo "$SLQROOTPWD"; echo "y"; echo "y"; echo "y"; echo "y") | mysql_secure_installation
sleep 1

# Remove the test database
mysql -e "DROP DATABASE IF EXISTS test"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"
# Create a new database
mysql -e "CREATE DATABASE glpi"
# Create a new user
mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD'"
# Grant privileges to the new user for the new database
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost'"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"

# Initialize time zones datas
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p"$SLQROOTPWD" mysql
#Ask tz
dpkg-reconfigure tzdata
systemctl restart mariadb
sleep 1
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'"
}

function install_glpi()
{
info "Téléchargement et installation de la dernière version de GLPI..."
# Get download link for the latest release
DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK 2>/dev/null
tar xzf /tmp/glpi-latest.tgz -C /var/www/html/
mkdir /var/www/html/glpi/log

# Setup vhost
cat > /etc/apache2/sites-available/glpi.conf << EOF
<VirtualHost *:80>
 # Dossier Web Public
 DocumentRoot /var/www/html/glpi/public

 # Fichier à charger par défaut (ordre)
 <IfModule dir_module>
   DirectoryIndex index.php index.html
 </IfModule>

 # Alias
 Alias "/glpi" "/var/www/html/glpi/public"

 # Log
 ErrorLog /var/www/html/glpi/log/error.log
 CustomLog /var/www/html/glpi/log/access.log combined

 # Repertoire
 <Directory /var/www/html/glpi/public>
   Require all granted
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteRule ^(.*)$ index.php [QSA,L]
 </Directory>
</VirtualHost>
EOF

a2dissite 000-default.conf
a2ensite glpi.conf

#Disable Apache Web Server Signature
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

# Setup Cron task
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

#Activation du module rewrite d'apache
a2enmod rewrite && systemctl restart apache2
}

function setup_db()
{
info "Setting up GLPI..."
cd /var/www/html/glpi
php bin/console db:install --db-name=glpi --db-user=glpi_user --db-host="localhost" --db-port=3306 --db-password=$SQLGLPIPWD --default-language="fr_FR" --no-interaction --force
rm -rf /var/www/html/glpi/install

# Add permissions
chown -R www-data:www-data /var/www/html
chmod 755 /var/www/html/glpi
}

function display_credentials()
{
info "=======> GLPI installation details  <======="
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
info "http://$IPADRESS or http://$HOST" 
echo ""
info "==> Database:"
info "Mot de passe root: $SLQROOTPWD"
info "Mot de passe glpi_user: $SQLGLPIPWD"
info "Nom de la base de donné GLPI: glpi"
info "<==========================================>"
echo ""
info "Si vous rencontrez un problème avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues"
}

check_root
check_distro
confirm_installation
network_info
install_packages
mariadb_configure
install_glpi
setup_db
display_credentials