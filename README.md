# Installation et mise à jour de GLPI en automatique

 ![GLPI](https://glpi-project.org/wp-content/uploads/2022/01/hero-img-2.png)

## À propos de ce script

Ce script a été écrit pour installer rapidement la dernière version de GLPI sur les serveurs Ubuntu, Debian, Alma Linux, Centos et Rocky Linux.

### Distribution et serveur Web

| Distribution | Serveur Web |
|:--:|:--:|
|Ubuntu|Apache|
|Débian|Apache|
|Alma Linux|Nginx|
|Centos|Nginx|
|Rocky Linux|Nginx|

Le script fera la mise à jour du système hôte et installera le serveur Web, MariaDB, PHP et les dépendances, téléchargera et installera la dernière version depuis le [Dépôt Officiel de GLPI](https://github.com/glpi-project/glpi) et configurera la base de données pour vous.
Une fois le script exécuté, la seule chose que vous aurez à faire sera de vous connecter à GLPI.

L'installation de GLPI se fait sans SSL. Si vous avez besoin d'ouvrir l'accès à GLPI depuis l'extérieur et/ou d'un certificat SSL, je vous recommande d'utiliser un reverse proxy.

>[!IMPORTANT]
>⚠️ Il est fortement recommandé d'exécuter ce script sur une nouvelle installation ou sur une installation faite avec ce script.

### Comptes par défaut

| Identifiant | Mot de passe | Rôle |
|--|--|--|
|glpi|Défini à l'installation|compte administrateur|
|post-only|Défini à l'installation|compte post-only|
|tech|Défini à l'installation|compte technicien|
|normal|Défini à l'installation|compte normal|

### Lire la documentation

Sachez que je n'ai aucun lien avec l'équipe qui développe GLPI et/ou TecLib.
Si vous rencontrez un problème avec ce script sur une des distributions compatibles, vous pouvez créer une requète, je vous aiderai avec plaisir.
Si vous rencontrez un problème avec GLPI et/ou avez besoin de plus d'informations sur son fonctionnement, je vous recommande de lire les documentations :

[Documentation Administrateurs de GLPI](https://glpi-install.readthedocs.io/), [Documentation Utilisateurs de GLPI](https://glpi-user-documentation.readthedocs.io/)

>[!IMPORTANT]
>
>| OS | VERSION| COMPATIBILITÉ|
>|--|--|--|
>|Debian|11|✅|
>|Debian|12|✅|
>|Ubuntu|23.10|✅|
>|Ubuntu|24.10|⚠️ A tester|
>|Alma Linux|9.4|⚠️ En cours de développement|
>|Alma Linux|9.5|⚠️ En cours de développement|
>|Centos|9|⚠️ A tester|
>|Rocky Linux|9.5|⚠️ A tester|

## Comment utiliser

GLPI s'installe en lançant la commande suivante dans votre terminal.

>[!IMPORTANT]
>⚠️ S'assurer qu'il n'y a plus le script dans le répertoire ```/root```, sinon ```rm /root/glpi-install.sh```

```bash
wget -N https://raw.githubusercontent.com/Papy-Poc/glpi_install/refs/heads/RedHat/glpi-install.sh && chmod 700 glpi-install.sh && ./glpi-install.sh
```
