# Installation et mise à jour de GLPI en automatique sur Débian et Red Hat

 ![GLPI](https://glpi-project.org/wp-content/uploads/2022/01/hero-img-2.png)

## À propos de ce script

Ce script a été écrit pour installer rapidement la dernière version de GLPI sur les serveurs Ubuntu, Debian, Alma Linux, Centos, Rocky Linux et Red Hat.

## Distribution et serveur Web

>[!IMPORTANT]
>
>| OS | VERSION | COMPATIBILITÉ | SERVEUR WEB |
>|:--:|:--:|:--:|:--:|
>|Debian|11|✅|Apache|
>|Debian|12|✅|Apache|
>|Ubuntu|23.10|✅|Apache|
>|Ubuntu|24.10|⚠️ A tester|Apache|
>|Alma Linux|9.5|✅|Engine X (Nginx)|
>|Centos|9|✅|Engine X (Nginx)|
>|Rocky Linux|9.5|✅|Engine X (Nginx)|
>|Red Hat|9.5|✅|Engine X (Nginx)|

Le script fera la mise à jour du système hôte et installera le serveur Web, MariaDB, PHP et les dépendances, téléchargera et installera la dernière version depuis le [Dépôt Officiel de GLPI](https://github.com/glpi-project/glpi) et configurera la base de données pour vous.

Une fois le script exécuté, la seule chose que vous aurez à faire sera de vous connecter à GLPI.

L'installation de GLPI se fait sans SSL. Si vous avez besoin d'ouvrir l'accès à GLPI depuis l'extérieur et/ou d'un certificat SSL, je vous recommande d'utiliser un reverse proxy.

## Comptes par défaut
| Identifiant | Mot de passe | Rôle |
|:--:|:--:|:--:|
|glpi|Défini à l'installation|compte administrateur|
|post-only|Défini à l'installation|compte post-only|
|tech|Défini à l'installation|compte technicien|
|normal|Défini à l'installation|compte normal|

## Lire la documentation

Sachez que je n'ai aucun lien avec l'équipe qui développe GLPI et/ou TecLib.
Si vous rencontrez un problème avec ce script sur une des distributions compatibles, vous pouvez créer une requète, je vous aiderai avec plaisir.
Si vous rencontrez un problème avec GLPI et/ou avez besoin de plus d'informations sur son fonctionnement, je vous recommande de lire les documentations :

[Documentation Administrateurs de GLPI](https://glpi-install.readthedocs.io/), [Documentation Utilisateurs de GLPI](https://glpi-user-documentation.readthedocs.io/)

## Comment utiliser

GLPI s'installe en lançant la commande suivante dans votre terminal.

>[!IMPORTANT]
>⚠️ Il est fortement recommandé d'exécuter ce script sur une nouvelle installation ou sur une installation faite avec ce script.
>
>⚠️ S'assurer qu'il n'y a plus le script dans le répertoire ```/root```, sinon ```rm /root/glpi-install.sh```
>
>⚠️ 'Wget' doit etre installé sur votre système ```apt install wget -y``` ou ```dnf install wget -y```
>
>⚠️ Vous devez etre connecté en compte 'root' pour ce faire taper dans la console ```su -``` saisir votre mot de passe root et relancer la commande suivante.

```bash
wget -N https://raw.githubusercontent.com/Papy-Poc/glpi_install/refs/heads/main/glpi-install.sh && chmod 700 glpi-install.sh && ./glpi-install.sh
```
