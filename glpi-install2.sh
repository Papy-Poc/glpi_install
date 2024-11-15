#!/bin/bash
#
# GLPI install script
# Author: PapyPoc & Poupix
# Version: 1.3.0
#
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
    ALMA_VERSIONS=("9.4")
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
        if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
            output=$(php $rep_glpi/bin/console -V 2>&1)
            glpi_cli_version=$(sed -n 's/.*GLPI CLI \([^ ]*\).*/\1/p' <<< "$output")
            # Obtenir la dernière version de GLPI depuis l'API GitHub
            new_version=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.name')
            info "Nouvelle version trouvée : GLPI version $new_version"
            if [ -d $rep_glpi ]; then
                warn "Le site est déjà installé. Version $glpi_cli_version"
                if [ "$glpi_cli_version" == "$new_version" ]; then
                    info "Vous avez déjà la dernière version de GLPI. Mise à jour annulée"
                    sleep 5
                    exit 0
                else
                    info "Voulez-vous mettre à jour GLPI (O/N) : "
                    read -r MaJ
                    case "$MaJ" in
                        "O" | "o")
                            update
                            exit 0
                            ;;
                        "N" | "n")
                            info "Sortie du programme."
                            efface_script
                            exit 0
                            ;;
                        *)
                            warn "Action non reconnue. Sortie du programme."
                            efface_script
                            exit 0
                            ;;
                    esac
                fi
            else 
                info "Nouvelle installation de GLPI version $new_version"
                install
            fi
        elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
            output=$(php $rep_glpi/bin/console -V 2>&1)
            glpi_cli_version=$(sed -n 's/.*GLPI CLI \([^ ]*\).*/\1/p' <<< "$output")
            # Obtenir la dernière version de GLPI depuis l'API GitHub
            new_version=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.name')
            info "Nouvelle version trouvée : GLPI version $new_version"
            if [ -d $rep_glpi ]; then
                warn "Le site est déjà installé. Version $glpi_cli_version"
                if [ "$glpi_cli_version" == "$new_version" ]; then
                    info "Vous avez déjà la dernière version de GLPI. Mise à jour annulée"
                    sleep 5
                    exit 0
                else
                    info "Voulez-vous mettre à jour GLPI (O/N) : "
                    read -r MaJ
                    case "$MaJ" in
                        "O" | "o")
                            update
                            exit 0
                            ;;
                        "N" | "n")
                            info "Sortie du programme."
                            exit 0
                            ;;
                        *)
                            warn "Action non reconnue. Sortie du programme."
                            exit 0
                            ;;
                    esac
                fi
            else 
                info "Nouvelle installation de GLPI version $new_version"
                install
            fi
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
}
function update_distro(){
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        info "Application des mise à jour"
        apt-get upgrade -y > /dev/null 2>&1
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        info "Application des mise à jour"
        dnf upgrade -y > /dev/null 2>&1
    fi
}
function install_packages(){
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        sleep 1
        info "Installation des service LAMP..."
        apt-get install -y --no-install-recommends apache2 mariadb-server perl curl jq php > /dev/null 2>&1
        info "Installation des extensions de PHP"
        apt install -y --no-install-recommends php-mysql php-mbstring php-curl php-gd php-xml php-intl php-ldap php-apcu php-xmlrpc php-zip php-bz2 php-intl > /dev/null 2>&1
        info "Activation de MariaDB"
        systemctl enable mariadb > /dev/null 2>&1
        info "Activation d'Apache"
        systemctl enable apache2 > /dev/null 2>&1
        info "Redémarage d'Apache"
        systemctl restart apache2 > /dev/null 2>&1
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        info "Ajout et activation du repositorie php:remi-8.3"
        dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm > /dev/null 2>&1
        dnf module enable php:remi-8.3 -y > /dev/null 2>&1
        sleep 1
        info "Installation des services LEMP..."
    # Modification du package "php" en "php-fpm"
        dnf install -y nginx mariadb-server perl curl jq php-fpm epel-release php > /dev/null 2>&1
        info "Installation des extensions de PHP"
    # Modification du package "php-mysql" en "php-mysqlnd"
        dnf install -y php-mysqlnd php-mbstring php-curl php-gd php-xml php-intl php-ldap php-apcu php-zip php-bz2 php-intl > /dev/null 2>&1
        info "Ouverture des ports 80 et 443 sur le parefeu"
    # Ouverture des ports 80 et 443 dans le firewall des distro RedHat
        firewall-cmd --permanent --zone=public --add-service=http > /dev/null 2>&1
        firewall-cmd --permanent --zone=public --add-service=https > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
    # Modifcation du fichier PHP-FPM pour Nginx,remplacement de Apache par Nginx
        sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf > /dev/null 2>&1
        sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf > /dev/null 2>&1
        
        info "Activation et démarrage des service LEMP"
    # Démarrage des services MariaDB, Nginx et Php-Fpm        
        info "Activation et démarrage de MariaDB"
        systemctl enable --now mariadb > /dev/null 2>&1
        #info "Démarage de MariaDB"
        #systemctl start mariadb > /dev/null 2>&1
        info "Activation et démarrage d'(e)Nginx"
        systemctl enable --now nginx > /dev/null 2>&1
        #info "Démarage d'(e)Nginx"
        #systemctl start nginx > /dev/null 2>&1
        info "Activation et démarrage de Php-Fpm"
        systemctl enable --now php-fpm > /dev/null 2>&1
       fi
}
function network_info(){
    INTERFACE=$(ip route | awk 'NR==1 {print $5}')
    IPADRESS=$(ip addr show "$INTERFACE" | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
    HOST=$(hostname)
}
function mariadb_configure(){
    info "Configuration de MariaDB"
    sleep 1
    export SQLROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
    export SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    export ADMINGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    export POSTGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    export TECHGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    export NORMGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
    systemctl start mariadb > /dev/null 2>&1
    mysql -u root <<-EOF
        ALTER USER 'root'@'localhost' IDENTIFIED BY '$SQLROOTPWD';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        FLUSH PRIVILEGES;
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';
        CREATE DATABASE glpi;
        CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD';
        GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost';
        FLUSH PRIVILEGES;
EOF
    sleep 5
    # Initialize time zones datas
    info "Configuration de TimeZone"
    warn $SQLROOTPWD
    mysql -u root -p"$SQLROOTPWD" <<-EOF
        USE mysql;
        GRANT SELECT ON time_zone_name TO 'glpi_user'@'localhost';
        FLUSH PRIVILEGES;
EOF
    sleep 5
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        echo "Europe/Paris" | dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        timedatectl set-timezone "Europe/Paris" > /dev/null 2>&1
    fi
    systemctl restart mariadb
    sleep 1
}
function install_glpi(){
    info "Téléchargement et installation de la dernière version de GLPI..."
    new_version=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.name')
    info "GLPI version $new_version"
    # Get download link for the latest release
    DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
    wget -O /tmp/glpi-latest.tgz "$DOWNLOADLINK" > /dev/null 2>&1
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        tar xzf /tmp/glpi-latest.tgz -C /var/www/html/ > /dev/null 2>&1
        rm -f /tmp/glpi-latest.tgz
        chown -R www-data:www-data "$rep_glpi"
        chmod -R 755 "$rep_glpi"
        systemctl restart apache2
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        tar xzf /tmp/glpi-latest.tgz -C /var/www/html/ > /dev/null 2>&1
        rm -f /tmp/glpi-latest.tgz
        chown -R nginx:nginx "$rep_glpi"
        chmod -R 755 "$rep_glpi"
        systemctl restart nginx
    fi
}
function setup_db(){
    info "Configuration de GLPI..."
    # Problème ici sous Alma
    ######################################################################################################

    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        php "$rep_glpi"bin/console db:install --db-name=glpi --db-user=glpi_user --db-host="localhost" --db-port=3306 --db-password="$SQLGLPIPWD" --default-language="fr_FR" --no-interaction --force --quiet
        rm -f /var/www/html/glpi/install/install.php
        sleep 5
        mkdir -p /etc/glpi
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
        mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -p$SQLROOTPWD -u root mysql
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        php "$rep_glpi"bin/console db:install --db-name=glpi --db-user=glpi_user --db-host="localhost" --db-port=3306 --db-password="$SQLGLPIPWD" --default-language="fr_FR" --no-interaction --force --quiet
        rm -f "$rep_glpi"install/install.php
        sleep 5
        mkdir -p /etc/glpi
        mkdir -p /var/log/glpi
        cat > /etc/glpi/local_define.php <<EOF
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
        mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -p$SQLROOTPWD -u root mysql
        sleep 1
    fi
    
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        chown -R www-data:www-data /etc/glpi
        chmod -R 775 /etc/glpi
        sleep 1
        mkdir -p /var/log/glpi
        chown -R www-data:www-data /var/log/glpi
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
        sed -i 's/^\(;\?\)\(session.cookie_secure\).*/\2 =on/' /etc/php/"$phpversion"/apache2/php.ini
        sed -i 's/^\(;\?\)\(session.cookie_samesite\).*/\2 =Lax/' /etc/php/"$phpversion"/apache2/php.ini
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
        echo "*/2 * * * * www-data /usr/bin/php '$rep_glpi'front/cron.php &>/dev/null" >> /etc/cron.d/glpi
    elif [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rockylinux" ]]; then
        #chown -R nginx:nginx /etc/glpi
        #chmod -R 775 /etc/glpi
        #sleep 1
        mkdir -p "$rep_data_glpi"
        chown -R nginx:nginx /var/log/glpi
        chmod -R 775 /var/log/glpi
        chown -R nginx:nginx /var/log/nginx
        chmod -R 775 /var/log/nginx
        sleep 1
        # Add permissions
        chown -R nginx:nginx "$rep_glpi"
        chmod -R 755 "$rep_glpi"
        chown -R nginx:nginx "$rep_data_glpi"
        chmod -R 755 "$rep_data_glpi"

        sleep 1
        mv "$rep_glpi"config/*.* "$rep_data_glpi"
        mv "$rep_glpi"files "$rep_data_glpi"
        ln -s "$rep_data_glpi"files "$rep_glpi"files
        ln -s "$rep_data_glpi"config "$rep_glpi"config
        # Setup server
        # Configuration SELinux
        info "Configuration de SELinux pour GLPI"
        semanage fcontext -a -t httpd_sys_content_t "$rep_glpi(/.*)?" > /dev/null 2>&1
        semanage fcontext -a -t httpd_sys_script_rw_t "$rep_data_glpi/config(/.*)?" > /dev/null 2>&1
        semanage fcontext -a -t httpd_sys_script_rw_t "$rep_data_glpi/files(/.*)?" > /dev/null 2>&1
        restorecon -Rv "$rep_glpi" 
        restorecon -Rv "$rep_data_glpi"
        sleep 1
        info "Configuration de Nginx avec les recommandations de sécurité"
        cat > /etc/nginx/conf.d/glpi.conf << EOF
server {
    listen 80;
    server_name glpi.lan;

    root $rep_glpi/public;

     # Bloquer l'accès direct aux dossiers sensibles
    location ~ ^/(config|files)/ {
        deny all;
        return 404;
    }

    # Configuration principale
    location / {
        try_files \$uri /index.php\$is_args\$args;
    }

    # Exécution de PHP
    location ~ ^/index\.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    # Cache pour les fichiers statiques
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|woff|ttf|svg)$ {
        expires max;
        log_not_found off;
    }
}
EOF
        sed -i 's/^\(;\?\)\(session.cookie_httponly\).*/\2 = 1/' /etc/php.ini
        #sed -i 's/^\(;\?\)\(session.cookie_secure\).*/\2 = on/' /etc/php.ini
        sed -i 's/^\(;\?\)\(session.cookie_secure\).*/\2 = 0/' /etc/php.ini
        sed -i 's/^\(;\?\)\(session.cookie_samesite\).*/\2 = "Lax"/' /etc/php.ini
        sleep 1
        # Supression du dossier d'installation de glpi
        rm -rf /var/www/html/glpi/install
        #Autorisation accès par SELinux à la lecture des fichiers GLPI dans le dossier
        #sed -i 's/^\(;\?\)\(SELINUX\).*/\2 = disabled/' /etc/selinux/config
        #setenforce 0
        # Restart de Nginx
        systemctl restart nginx > /dev/null 2>&1
        # Setup Cron task
        echo "*/2 * * * * nginx /usr/bin/php '${rep_glpi}front/cron.php' &>/dev/null" | tee /etc/cron.d/glpi > /dev/null
    fi
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
        info "http://$HOST"
        echo ""
        info "==> Database:"
        info "Mot de passe root: $SQLROOTPWD"
        info "Mot de passe glpi_user: $SQLGLPIPWD"
        info "Nom de la base de données GLPI: glpi"
        info "<============================================================================================================================>"
        echo ""
        info "Si vous rencontrez un problème avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues"
}
function write_credentials(){
        cat > /root/sauve_mdp.txt <<EOF
===========================================> GLPI installation details  <===============================================
Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables.

Les comptes utilisateurs par défaut sont :
UTILISATEUR       -  MOT DE PASSE       -  ACCES
info "glpi        -  $ADMINGLPIPWD       -  compte admin"
info "post-only   -  $POSTGLPIPWD       -  compte post-only"
info "tech        -  $TECHGLPIPWD       -  compte tech"
info "normal      -  $NORMGLPIPWD       -  compte normal"
        
Vous pouvez accéder à la page web de GLPI à partir d'une adresse IP ou d'un nom d'hôte :
http://$IPADRESS
http://$HOST

==> Database:
Mot de passe root: $SQLROOTPWD
Mot de passe glpi_user: $SQLGLPIPWD
Nom de la base de données GLPI: glpi
==========================================> Tips pour Nginx sur distro RedHat <=============================================
Si la page dans le navigateur ne s'ouvre pas, pas de panique penser a vérifier 
    -si l'ouverture du firewall est OK
     firewall-cmd --list-all (normalement c'est prévu dans le script)
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
    -si SELinux n'est pas en mode restrictif
        getenforce (Permissive, Disabled, Enforcing), 
        Autre que disabled, le desactiver provisoirement >>> setenforce 0
        Désactivation complète DECONSEILLE >> vim /etc/selinux/config
        Trouver la ligne avec SELINUX=enforcing ou permissive remplacer par disabled
<=============================================================================================================================>

Si vous rencontrez un probléme avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues
EOF
        chmod 700 /root/sauve_mdp.txt
        echo ""
        warn "Fichier de sauve_mdp.txt enregistrer dans /home"
        echo ""
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
        info "La base de donnée a été sauvergardé avec succès."
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
        php "$rep_glpi"/bin/console db:update --quiet --no-interaction --force > /dev/null 2>&1
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
LOG_FILE="/root/glpi-install.log"
rep_script="/root/glpi-install.sh"
rep_backup="/home/glpi_sauve/"
export rep_glpi="/var/www/html/glpi/"
export rep_data_glpi="/var/lib/glpi/"
#export rep_glpi_nginx="/usr/share/nginx/html/glpi/"
current_date_time=$(date +"%d-%m-%Y_%H-%M-%S")
bdd_backup="bdd_glpi-""$current_date_time"".sql"
clear
check_root
check_distro
check_install
