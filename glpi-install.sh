#!/bin/bash
#
# GLPI install script
# Author: PapyPoc & Poupix
# Version: 1.3.0
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
function check_distro(){
    # Constante pour les versions de Debian acceptables
    DEBIAN_VERSIONS=("11" "12")
    # Constante pour les versions d'Ubuntu acceptables
    UBUNTU_VERSIONS=("23.10" "24.10")
    # Constante pour les versions d'Almalinux acceptables
    ALMA_VERSIONS=("9")
    # Constante pour les versions de Centos acceptables
    CENTOS_VERSIONS=("9")
    # Constante pour les versions de Rocky Linux acceptables
    ROCKY_VERSIONS=("9.4")
    # Vérifie si c'est une distribution Debian ou Ubuntu
    if [ -f /etc/os-release ]; then
    # Source le fichier /etc/os-release pour obtenir les informations de la distribution
    # shellcheck disable=SC1091
    . /etc/os-release # Récupere les variables d'environnement
    # Vérifie si la distribution est basée sur Debian, Ubuntu, Alma Linux, Centos ou Rocky Linux
        if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
            if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION_ID "* || " ${UBUNTU_VERSIONS[*]} " == *" $VERSION_ID "* || " ${ALMA_VERSIONS[*]} " == *" $VERSION_ID "* || " ${CENTOS_VERSIONS[*]} " == *" $VERSION_ID "* || " ${ROCKY_VERSIONS[*]} " == *" $VERSION_ID "* ]]; then
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
function check_install(){
    # Vérifie si le répertoire existe
    if [ -d "$1" ]; then
            output=$(php "$rep_glpi"bin/console -V 2>&1)
            sleep 2
            glpi_cli_version=$(sed -n 's/.*GLPI CLI \([^ ]*\).*/\1/p' <<< "$output")
            warn "Le site est déjà installé. Version ""$glpi_cli_version"
            new_version=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.name')
            info "Nouvelle version trouver : GLPI version $new_version"
            if [ "$glpi_cli_version" == "$new_version" ]; then
                    info "Vous avez déjà la dernière version de GLPI. Mise à jour annuler"
                    sleep 5
                    exit 0;
            else
                    info "Voulez-vous mettre à jour GLPI (O/N): "
                    read -r MaJ
                    case "$MaJ" in
                            "O" | "o")
                                    update
                                    exit 0;;
                            "N" | "n")
                                    info "Sortie du programme."
                                    efface_script
                                    exit 0;;
                            *)
                                    warn "Action non reconnue. Sortie du programme."
                                    efface_script
                                    exit 0;;
                    esac
            fi
    else
            info "Nouvelle installation de GLPI"
            install
    fi
}
function update_distro(){
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        info "Application des mise à jour"
        apt-get upgrade -y > /dev/null 2>&1
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        info "Application des mise à jour"
        trace "dnf upgrade -y" > /dev/null 2>&1
    fi
}
function network_info(){
    INTERFACE=$(ip route | awk 'NR==1 {print $5}')
    IPADRESS=$(ip addr show "$INTERFACE" | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
    # HOST=$(hostname)
}
function install_packages(){
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        sleep 1
        info "Installation des service lamp..."
        apt-get install -y --no-install-recommends apache2 mariadb-server perl curl jq php > /dev/null 2>&1
        info "Installation des extensions de php"
        apt install -y --no-install-recommends php-mysql php-mbstring php-curl php-gd php-xml php-intl php-ldap php-apcu php-xmlrpc php-zip php-bz2 php-intl > /dev/null 2>&1
        info "Activation de MariaDB"
        systemctl enable mariadb > /dev/null 2>&1
        info "Activation d'Apache"
        systemctl enable apache2 > /dev/null 2>&1
        info "Redémarage d'Apache"
        systemctl restart apache2 > /dev/null 2>&1
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        sleep 1
        info "Installation des service lemp..."
    # Modification du package "php" en "php-fpm"
        trace "dnf install -y nginx mariadb-server perl curl jq php-fpm epel-release" > /dev/null 2>&1
        info "Installation des extensions de php"
    # Modification du package "php-mysql" en "php-mysqlnd"
        trace "dnf install -y php-mysqlnd php-mbstring php-curl php-gd php-xml php-intl php-ldap php-apcu php-zip php-bz2 php-intl" > /dev/null 2>&1
  
    # Ouverture des ports 80 et 443 dans le firewall des distro RedHat
        firewall-cmd --permanent --zone=public --add-service=http > /dev/null 2>&1
        firewall-cmd --permanent --zone=public --add-service=https > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
   
    # Démarrage des services MariaDB et Nginx        
        info "Activation de MariaDB"
        systemctl enable mariadb > /dev/null 2>&1
        info "Démarage de MariaDB"
        systemctl start mariadb > /dev/null 2>&1
        info "Activation d'(e)Nginx"
        systemctl enable nginx > /dev/null 2>&1
        info "Démarage d'(e)Nginx"
        systemctl start nginx > /dev/null 2>&1
       fi
}
function mariadb_configure(){
    info "Configuration de MariaDB"
    sleep 1
    SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
    SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    ADMINGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    POSTGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    TECHGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    NORMGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    systemctl start mariadb > /dev/null 2>&1
    (echo ""; echo "y"; echo "y"; echo "$SLQROOTPWD"; echo "$SLQROOTPWD"; echo "y"; echo "y"; echo "y"; echo "y") | trace "mysql_secure_installation" > /dev/null 2>&1
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
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        # Initialize time zones datas
        info "Configuration de TimeZone"
        trace "mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p"$SLQROOTPWD" mysql" > /dev/null 2>&1
        # Ask tz
        echo "Europe/Paris" | trace "dpkg-reconfigure -f noninteractive tzdata" > /dev/null 2>&1
        systemctl restart mariadb
        sleep 1
        mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'" > /dev/null 2>&1
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        # Initialize time zones datas
        info "Configuration de TimeZone"
        trace "mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p"$SLQROOTPWD" mysql" > /dev/null 2>&1
        # A REMPLACER
        # echo "Europe/Paris" | trace "dpkg-reconfigure -f noninteractive tzdata" > /dev/null 2>&1
        systemctl restart mariadb
        sleep 1
    fi
}
function install_glpi(){
    info "Téléchargement et installation de la dernière version de GLPI..."
    new_version=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.name')
    info "GLPI version $new_version"
    # Get download link for the latest release
    DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
    wget -O /tmp/glpi-latest.tgz "$DOWNLOADLINK" > /dev/null 2>&1
    trace "tar xzf /tmp/glpi-latest.tgz -C /var/www/html/"
    chown -R www-data:www-data "$rep_glpi"
    chmod -R 755 "$rep_glpi"
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        systemctl restart apache2
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        systemctl restart nginx
    fi
}
function setup_db(){
    info "Configuration de GLPI..."
    # Problème ici sous Alma
    ######################################################################################################
    ######################################################################################################
    ######################################################################################################
    ######################################################################################################
    
    
    php "$rep_glpi"bin/console db:install --db-name=glpi --db-user=glpi_user --db-host="localhost" --db-port=3306 --db-password="$SQLGLPIPWD" --default-language="fr_FR" --no-interaction --force --quiet
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
    mv "$rep_glpi"config/*.* /etc/glpi/
    mv "$rep_glpi"files /var/lib/glpi/
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        chown -R www-data:www-data  /etc/glpi
        chmod -R 775 /etc/glpi
        sleep 1
        mkdir /var/log/glpi
        chown -R www-data:www-data  /var/log/glpi
        chmod -R 775 /var/log/glpi
        sleep 1
        # Add permissions
        chown -R www-data:www-data "$rep_glpi"
        chmod -R 775 "$rep_glpi"
        sleep 1
        # Setup vhost
         cat > /etc/apache2/sites-available/glpi.conf << EOF
<VirtualHost *:80>
    ServerName glpi.lan
    DocumentRoot /var/www/glpi/public
    <Directory /var/www/glpi/public>
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
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        chown -R nginx:nginx  /etc/glpi
        chmod -R 775 /etc/glpi
        sleep 1
        mkdir /var/log/glpi
        chown -R nginx:nginx  /var/log/glpi
        chmod -R 775 /var/log/glpi
        sleep 1
        # Add permissions
        chown -R nginx:nginx "$rep_glpi"
        chmod -R 775 "$rep_glpi"
        sleep 1
        mv /etc/nginx/nginx.conf /etc/nginx.conf.bak
        cat > /etc/nginx/nginx.conf << EOF
events {
    worker_connections  1024;
}
http {
    server {
        listen 80;
        server_name glpi.localhost;
        root /var/www/glpi/public;
        location / {
            try_files $uri /index.php$is_args$args;
        }
        location ~ ^/index\.php$ {
            # the following line needs to be adapted, as it changes depending on OS distributions and PHP versions
            fastcgi_pass unix:/run/php/php-fpm.sock;
            fastcgi_split_path_info ^(.+\.php)(/.*)$;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
}
EOF
        # Restart de Nginx
        systemctl restart nginx > /dev/null 2>&1
    fi
    # Setup Cron task
    echo "*/2 * * * * www-data /usr/bin/php '$rep_glpi'front/cron.php &>/dev/null" >> /etc/cron.d/glpi
}
function maj_user_glpi(){
        # Changer le mot de passe de l'admin glpi 
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; UPDATE glpi_users SET password = MD5('$ADMINGLPIPWD') WHERE name = 'glpi';" > /dev/null 2>&1
        # Changer le mot de passe de l'utilisateur post-only
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; UPDATE glpi_users SET password = MD5('$POSTGLPIPWD') WHERE name = 'post-only';" > /dev/null 2>&1
        # Changer le mot de passe de l'utilisateur tech
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; UPDATE glpi_users SET password = MD5('$TECHGLPIPWD') WHERE name = 'tech';" > /dev/null 2>&1
        # Changer le mot de passe de l'utilisateur normal
        mysql -u glpi_user -p"$SQLGLPIPWD" -e "USE glpi; UPDATE glpi_users SET password = MD5('$NORMGLPIPWD') WHERE name = 'normal';" > /dev/null 2>&1
}
function display_credentials(){
        info "===========================> Détail de l'installation de GLPI <=================================="
        warn "Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables."
        echo ""
        info "Les comptes utilisateurs par défaut sont :"
        info "UTILISATEUR  -  MOT DE PASSE       -  ACCES"
        info "glpi         -  $ADMINGLPIPWD       -  compte admin"
        info "post-only    -  $POSTGLPIPWD       -  compte post-only"
        info "tech         -  $TECHGLPIPWD       -  compte tech"
        info "normal       -  $NORMGLPIPWD       -  compte normal"
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
        cat > /root/sauve_mdp.txt <<EOF
==============================> GLPI installation details  <=====================================
Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables.

Les comptes utilisateurs par défaut sont :
UTILISATEUR       -  MOT DE PASSE       -  ACCES
info "glpi        -  $ADMINGLPIPWD       -  compte admin"
info "post-only   -  $POSTGLPIPWD       -  compte post-only"
info "tech        -  $TECHGLPIPWD       -  compte tech"
info "normal      -  $NORMGLPIPWD       -  compte normal"
        
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
        update_distro
        install_packages
        network_info
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
                warn "Mode maintenance activer"
                php /var/www/html/glpi/bin/console glpi:maintenance:enable  > /dev/null 2>&1
        elif [ "$1" == "0" ]; then
                info "Mode maintenance désactiver"
                php /var/www/html/glpi/bin/console glpi:maintenance:disable > /dev/null 2>&1
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
        mysqldump -u root -p"$PASSWORD" --databases glpi > "${rep_backup}${bdd_backup}" > /dev/null 2>&1
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
        cp -Rf "$rep_backup"backup_glpi/plugins "$rep_glpi" > /dev/null 2>&1
        cp -Rf "$rep_backup"backup_glpi/marketplace "$rep_glpi" > /dev/null 2>&1
        cat > "$rep_glpi"inc/downstream.php << EOF
        <?php
        define('GLPI_CONFIG_DIR', '/etc/glpi');
        if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
        require_once GLPI_CONFIG_DIR . '/local_define.php';
        }
EOF
        chown -R www-data:www-data "$rep_glpi" > /dev/null 2>&1
        info "Mise à jour de la base de donnée du site"
        php "$rep_glpi"/bin/console db:update --quiet --no-interaction --force  > /dev/null 2>&1
        info "Nettoyage de la mise à jour"
        rm -Rf "$rep_glpi"install > /dev/null 2>&1
        rm -Rf "$rep_backup"backup_glpi > /dev/null 2>&1
}
function update(){
        maintenance "1"
        backup_glpi
        install_glpi
        update_glpi
        maintenance "0"
        efface_script
}
function trace() {
    local COMMAND="$@"
    log INFO "Exécution de la commande : $COMMAND"
    eval "$COMMAND" 2>&1 | tee -a "$LOG_FILE"
    local STATUS=${PIPESTATUS[0]}
    if [ $STATUS -ne 0 ]; then
        log ERROR "La commande a échoué avec le code $STATUS"
    fi
}
LOG_FILE="/root/glpi-install.log"
rep_script="/root/glpi-install.sh"
rep_backup="/home/glpi_sauve/"
rep_glpi="/var/www/html/glpi/"
current_date_time=$(date +"%d-%m-%Y_%H-%M-%S")
bdd_backup="bdd_glpi-""$current_date_time"".sql"
clear
check_root
check_distro
check_install "$rep_glpi"
