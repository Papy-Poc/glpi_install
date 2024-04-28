# Instalation et mise à jour de GLPI en automatique
 ![GLPI](https://glpi-project.org/wp-content/uploads/2022/01/hero-img-2.png)
## A propos de ce script

Ce script a été écrit pour installer rapidement la dernière version de GLPI (actuellement 10.0.12) sur les serveurs Ubuntu et Debian.

Le script installera Apache, MariaDB, PHP et les dépendances, téléchargera et installera la dernière version depuis le [Official GLPI repo] (https://github.com/glpi-project/glpi) et configurera la base de données pour vous.
Une fois le script exécuté, la seule chose que vous aurez à faire sera de vous connecter à GLPI.

L'installation de GLPI se fait sans SSL. Si vous avez besoin d'ouvrir l'accès à GLPI depuis l'extérieur et/ou d'un certificat SSL, je vous recommande d'utiliser un reverse proxy.

>[!IMPORTANT]
>⚠️ Il est fortement recommandé d'exécuter ce script sur une nouvelle installation ou sur une installation faite avec ce script.

### Comptes par défaut

| Login | Mot de passe | Rôle |
|--|--|--|
glpi|glpi|compte administrateur
tech|tech|compte technique
normal|normal|compte normal
post-only|postonly|compte post-only

### Lire la documentation
Sachez que je n'ai aucun lien avec l'équipe qui développe GLPI et/ou TecLib.
Si vous rencontrez un problème avec ce script sur une des distributions compatibles, vous pouvez créer une requète, je vous aiderai avec plaisir.
Si vous rencontrez un problème avec GLPI et/ou avez besoin de plus d'informations sur son fonctionnement, je vous recommande de lire les documentations :

[GLPI Administrators Docs](https://glpi-install.readthedocs.io/),   [GLPI Users Docs](https://glpi-user-documentation.readthedocs.io/)

## Compatibilité
Comme ce script utilise apt, il ne fonctionne actuellement que sur les distributions basées sur debian.
>[!IMPORTANT]
>| OS | VERSION| COMPATIBILITÉ|
>|--|--|--|
>|Debian|10|⚠️ Jamais testé, si vous choisissez de forcer le script, c'est à vos risques et périls. |
>|Debian|11|✅|
>|Debian|12|✅|
>|Ubuntu|22.04|⚠️ Tester, ne marche pas|
>|Ubuntu|23.10|✅|

## Comment utiliser
GLPI_install_script s'installe en lançant l'une des commandes suivantes dans votre terminal. Vous pouvez l'installer via la ligne de commande avec curl ou wget.

>[!IMPORTANT]
>⚠️ S'assurer qu'il n'y a plus le script dans le répertoire ```/root```, sinon ```rm /root/glpi-install.sh```

```bash
wget https://raw.githubusercontent.com/PapyPoc/glpi_install/dev/glpi-install.sh && chmod 777 glpi-install.sh && ./glpi-install.sh
```
