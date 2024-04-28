#!/bin/bash
#
# GLPI install script
# Author: PapyPoc
# Version: 1.1.0
#

function warn(){
    echo -e '\e[31m'"$1"'\e[0m';
}
function info(){
    echo -e '\e[36m'"$1"'\e[0m';
}

function check_root(){
        # Vérification des privilèges root
        if [[ "$(id -u)" -ne 0 ]]; then
                warn "Ce script doit étre exécuté en tant que root" >&2
                exit 1
        else
                info "Privilège Root: OK"
        fi
}

function check_install(){
        rep="/var/www/html/glpi"
        # Vérifie si le répertoire existe
        if [ -d "$rep" ]; then
                warn "Le site est déjà installé."
                info "Voulez-vous mettre à jour GLPI (O/N): "
                read -r MaJ
                case "$MaJ" in
                        "O" | "o")
                                update
                                exit 0;;
                        "N" | "n")
                                info "Sortie du programme."
                                exit 0;;
                        *)
                                warn "Action non reconnue. Sortie du programme."
                                exit 0;;
                esac
        else
                install
        fi
}

function check_distro(){
        # Constante pour les versions de Debian acceptables
        DEBIAN_VERSIONS=("11" "12")
        # Constante pour les versions d'Ubuntu acceptables
        UBUNTU_VERSIONS=("23.10")
        # Vérifie si c'est une distribution Debian ou Ubuntu
        if [ -f /etc/os-release ]; then
        # Source le fichier /etc/os-release pour obtenir les informations de la distribution
        # shellcheck disable=SC1091
        . /etc/os-release # . /etc/os-release
        # Vérifie si la distribution est basée sur Debian ou Ubuntu
                if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
                        if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION_ID "* || " ${UBUNTU_VERSIONS[*]} " == *" $VERSION_ID "* ]]; then
                                info "La version de votre systeme d'exploitation ($ID $VERSION_ID) est compatible."
                        else
                                warn "La version de votre système d'exploitation ($ID $VERSION_ID) n'est pas considérée comme compatible."
                                warn "Voulez-vous toujours forcer l'installation ? Attention, si vous choisissez de forcer le script, c'est à vos risques et périls."
                                info "Etes-vous sûr de vouloir continuer ? [yes/no]"
                                read -r response
                                if [ "$response" == "yes" ]; then
                                        info "Continuing..."
                                elif [ "$response" == "no" ]; then
                                        info "Exiting..."
                                        exit 1
                                else
                                        warn "Réponse non valide. Quitter..."
                                        exit 1
                                fi
                        fi
                fi
        else
        warn "Il s'agit d'une autre distribution que Debian ou Ubuntu qui n'est pas compatible."
        exit 1
        fi
}

function update_distro(){
        info "Recherche des mise à jour"
        apt-get update > /dev/null 2>&1
        info "Application des mise à jour"
        apt-get upgrade -y > /dev/null 2>&1
}

function network_info(){
        INTERFACE=$(ip route | awk 'NR==1 {print $5}')
        IPADRESS=$(ip addr show "$INTERFACE" | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
        # HOST=$(hostname)
}

function install_packages(){
        sleep 1
        info "Installation des service lamp..."
        apt-get install -y --no-install-recommends apache2 mariadb-server perl curl jq php > /dev/null 2>&1
        info "Installation des extensions de php"
        apt install -y --no-install-recommends php-mysql php-mbstring php-curl php-gd php-xml php-intl php-ldap php-apcu php-xmlrpc php-zip php-bz2 > /dev/null 2>&1
        info "Activation de MariaDB"
        systemctl enable mariadb > /dev/null 2>&1
        info "Activation d'Apache"
        systemctl enable apache2 > /dev/null 2>&1
        info "Redémarage d'Apache"
        systemctl restart apache2 > /dev/null 2>&1
}

function mariadb_configure(){
        info "Configuration de MariaDB"
        sleep 1
        SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
        SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
        ADMINGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
        systemctl start mariadb > /dev/null 2>&1
        (echo ""; echo "y"; echo "y"; echo "$SLQROOTPWD"; echo "$SLQROOTPWD"; echo "y"; echo "y"; echo "y"; echo "y") | mysql_secure_installation > /dev/null 2>&1
        sleep 1
        mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';" > /dev/null 2>&1
        # Create a new database
        mysql -e "CREATE DATABASE glpi;" > /dev/null 2>&1
        # Create a new user
        mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD';" > /dev/null 2>&1
        # Grant privileges to the new user for the new database
        mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost';" > /dev/null 2>&1
        # Reload privileges
        mysql -e "FLUSH PRIVILEGES;" > /dev/null 2>&1

        # Initialize time zones datas
        info "Configuration de TimeZone"
        mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p"$SLQROOTPWD" mysql > /dev/null 2>&1
        # Ask tz
        echo "Europe/Paris" | dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1
        systemctl restart mariadb
        sleep 1
        mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'" > /dev/null 2>&1
}

function install_glpi(){
        info "Téléchargement et installation de la dernière version de GLPI..."
        # Get download link for the latest release
        DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
        wget -O /tmp/glpi-latest.tgz "$DOWNLOADLINK" > /dev/null 2>&1
        tar xzf /tmp/glpi-latest.tgz -C /var/www/html/
        chown -R www-data:www-data /var/www/html/glpi/
        chmod -R 755 /var/www/html/glpi/
        systemctl restart apache2
}

function setup_db(){
        info "Configuration de GLPI..."
        php /var/www/html/glpi/bin/console db:install --db-name=glpi --db-user=glpi_user --db-host="localhost" --db-port=3306 --db-password="$SQLGLPIPWD" --default-language="fr_FR" --no-interaction --force
        rm -rf /var/www/html/glpi/install
        sleep 5
        mkdir /etc/glpi
        cat > /etc/glpi/local_define.php << EOF
        <?php
        define('GLPI_VAR_DIR', '/var/lib/glpi');
        define('GLPI_LOG_DIR', '/var/log/glpi');
EOF
        sleep 1
        cat > /var/www/html/glpi/inc/downstream.php << EOF
        <?php
        define('GLPI_CONFIG_DIR', '/etc/glpi');
        if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
        require_once GLPI_CONFIG_DIR . '/local_define.php';
        }
EOF
        mv /var/www/html/glpi/config/*.* /etc/glpi/
        mv /var/www/html/glpi/files /var/lib/glpi/
        chown -R www-data:www-data  /etc/glpi
        chmod -R 775 /etc/glpi
        sleep 1
        mkdir /var/log/glpi
        chown -R www-data:www-data  /var/log/glpi
        chmod -R 775 /var/log/glpi
        sleep 1
        # Add permissions
        chown -R www-data:www-data /var/www/html
        chmod -R 775 /var/www/html
        sleep 1
        # Setup vhost
        cat > /etc/apache2/sites-available/glpi.conf << EOF
        <VirtualHost *:80>
                DocumentRoot /var/www/html/glpi/public
                <Directory /var/www/html/glpi/public>
                        Require all granted
                        RewriteEngine On
                        RewriteCond %{HTTP:Authorization} ^(.+)$
                        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
                        RewriteCond %{REQUEST_FILENAME} !-f
                        RewriteRule ^(.*)$ index.php [QSA,L]
                </Directory>
                ErrorLog /var/log/glpi/error.log
                CustomLog /var/log/glpi/access.log combined
        </VirtualHost>
EOF
        phpversion=$(php -v | grep -i '(cli)' | awk '{print $2}' | cut -c 1,2,3)
        sed -i 's/^\(;\?\)\(session.cookie_httponly\).*/\2 =on/' /etc/php/"$phpversion"/apache2/php.ini
        sleep 1
        # Disable Apache Web Server Signature
        echo "ServerSignature Off" >> /etc/apache2/apache2.conf
        echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
        # Activation du module rewrite d'apache
        a2enmod rewrite > /dev/null 2>&1
        # Déactivation du site par défaut et activation site glpi
        a2dissite 000-default.conf > /dev/null 2>&1
        a2ensite glpi.conf > /dev/null 2>&1
        # Restart d'apache
        systemctl restart apache2 > /dev/null 2>&1
        # Setup Cron task
        echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi
}

function maj_user_glpi(){
        # Changer le mot de passe de l'admin glpi 
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; UPDATE glpi_users SET password = MD5('$ADMINGLPIPWD') WHERE name = 'glpi';" > /dev/null 2>&1
        # Efface utilisateur post-only
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; DELETE FROM glpi_users WHERE name = 'post-only';" > /dev/null 2>&1
        # Efface utilisateur tech
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; DELETE FROM glpi_users WHERE name = 'tech';" > /dev/null 2>&1
        # Efface utilisateur normal
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; DELETE FROM glpi_users WHERE name = 'normal';" > /dev/null 2>&1
}

function display_credentials(){
        info "===========================> Détail de l'installation de GLPI <=================================="
        warn "Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables."
        echo ""
        info "Les comptes utilisateurs par défaut sont :"
        info "UTILISATEUR       -  MOT DE PASSE       -  ACCES"
        info "glpi              -  $ADMINGLPIPWD      -  compte admin"
        echo ""
        info "Vous pouvez accéder à la page web de GLPI à partir d'une adresse IP ou d'un nom d'hôte :"
        info "http://$IPADRESS" 
        echo ""
        info "==> Database:"
        info "Mot de passe root: $SLQROOTPWD"
        info "Mot de passe glpi_user: $SQLGLPIPWD"
        info "Nom de la base de données GLPI: glpi"
        info "<===============================================================================================>"
        echo ""
        info "Si vous rencontrez un problème avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues"
}

function write_credentials(){
        cat <<EOF > /root/sauve_mdp.txt
        ==============================> GLPI installation details  <=====================================
        Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables.

        Les comptes utilisateurs par défaut sont :
        UTILISATEUR       -  MOT DE PASSE       -  ACCES
        glpi              -  $ADMINGLPIPWD      -  compte admin
        
        Vous pouvez accéder à la page web de GLPI à partir d'une adresse IP ou d'un nom d'hôte :
        http://$IPADRESS

        ==> Database:
        Mot de passe root: $SLQROOTPWD
        Mot de passe glpi_user: $SQLGLPIPWD
        Nom de la base de données GLPI: glpi
        <===============================================================================================>

        Si vous rencontrez un probléme avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues
EOF
        chmod 700 /root/sauve_mdp.txt
        echo ""
        warn "Fichier de sauve_mdp.txt enregistrer dans /home"
        echo ""
}

function efface_script(){
        # Vérifie si le répertoire existe
        if [ -e "$rep_script" ]; then
                warn "Le script est déjà présent."
                warn "Effacement en cours"
                rm -f "$rep_script"
        fi
}
function install(){
        clear
        check_root
        check_distro
        update_distro
        network_info
        install_packages
        mariadb_configure
        sleep 5
        install_glpi
        sleep 5
        setup_db
        sleep 5
        maj_user_glpi
        display_credentials
        write_credentials
        efface_script
}

function maintenance(){
        if [ "$1" == "1" ]; then
                php /var/www/html/glpi/bin/console glpi:maintenance:enable
        elif [ "$1" == "0" ]; then
                php /var/www/html/glpi/bin/console glpi:maintenance:disable
        fi
}

function backup_glpi(){
        # Vérifie si le répertoire existe
        if [ ! -d "$rep_backup" ]; then
                info "Création du  répertoire de sauvegarde avant mise à jour"
                mkdir "$rep_backup"
        fi
        # Sauvergarde de la bdd
        info "Dump de la base de donnée"
        PASSWORD=$(sed -n 's/.*Mot de passe root: \([^ ]*\).*/\1/p' /root/sauve_mdp.txt)
        mysqldump -u root -p"$PASSWORD" --databases glpi > "${rep_backup}${bdd_backup}"
        info "La base de donnée a été sauvergardé avec succè."
        # Sauvegarde des fichiers
        info "Sauvegarde des fichiers du sites"
        cp -Rf "$rep_glpi" "$rep_backup"backup_glpi
        info "Les fichiers du site GLPI ont été sauvegardés avec succès."
        info "Suppression des fichiers du site"
        rm -Rf "$rep_glpi"
}

function update_glpi(){
        info "Remise en place des dossiers marketplace"
        cp -Rf "$rep_backup"backup_glpi/plugins "$rep_glpi"
        cp -Rf "$rep_backup"backup_glpi/marketplace "$rep_glpi"
        cat > "$rep_glpi"inc/downstream.php << EOF
        <?php
        define('GLPI_CONFIG_DIR', '/etc/glpi');
        if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
        require_once GLPI_CONFIG_DIR . '/local_define.php';
        }
EOF
        chown -R www-data:www-data "$rep_glpi"
        info "Mise à jour de la base de donnée du site"
        php "$rep_glpi"/bin/console db:update --no-interaction --force
        info "Nettoyage de la mise à jour"
        rm -Rf "$rep_glpi"install
        rm -Rf "$rep_backup"backup_glpi
}

function update(){
        clear
        check_root
        maintenance "1"
        backup_glpi
        install_glpi
        update_glpi
        maintenance "0"
        efface_script
}

rep_script="/root/glpi-install.sh"
rep_backup="/home/glpi_sauve/"
rep_glpi="/var/www/html/glpi/"
current_date_time=$(date +"%d-%m-%Y_%H-%M-%S")
bdd_backup="bdd_glpi-""$current_date_time"".sql"
check_install
