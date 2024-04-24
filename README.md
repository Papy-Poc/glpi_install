# Installation de GLPI en automatique
 ![GLPI](https://glpi-project.org/wp-content/uploads/2022/01/hero-img-2.png)
## À propos de ce script

Ce script a été écrit pour installer rapidement la dernière version de GLPI (actuellement 10.0.12) sur les serveurs Ubuntu et Debian.

Le script installera Apache, MariaDB, PHP et les dépendances, téléchargera et installera la dernière version depuis le [Dépôt Officiel de GLPI](https://github.com/glpi-project/glpi) et configurera la base de données pour vous.
Une fois le script exécuté, la seule chose que vous aurez à faire sera de vous connecter à GLPI.

L'installation de GLPI se fait sans SSL. Si vous avez besoin d'ouvrir l'accès à GLPI depuis l'extérieur et/ou d'un certificat SSL, je vous recommande d'utiliser un reverse proxy.

⚠️ Il est fortement recommandé d'exécuter ce script sur une nouvelle installation.

### Comptes par défaut

| Identifiant | Mot de passe | Rôle |
|--|--|--|
| glpi | Défini à l'installation | Compte administrateur |

### Lire la documentation
Sachez que je n'ai aucun lien avec l'équipe qui développe GLPI et/ou TecLib.
Si vous rencontrez un problème avec ce script sur l'une des distributions compatibles, vous pouvez créer un problème, je vous aiderai avec plaisir.
Si vous rencontrez un problème avec GLPI et/ou avez besoin de plus d'informations sur son fonctionnement, je vous recommande de lire la documentation :

[Documentation Administrateurs de GLPI](https://glpi-install.readthedocs.io/), [Documentation Utilisateurs de GLPI](https://glpi-user-documentation.readthedocs.io/)

## Compatibilité
Comme ce script utilise apt, il ne fonctionne actuellement que sur les distributions basées sur Debian.
Ce script a été testé sur les distributions suivantes :
| OS | VERSION | COMPATIBILITÉ |
|--|--|--|
| Debian | 10 | ⚠️ Jamais testé, si vous choisissez de forcer le script, c'est à vos risques et périls. |
| Debian | 11 | ✅ |
| Debian | 12 | ✅ |
| Ubuntu | 22.04 | ⚠️ Testé, ne fonctionne pas |
| Ubuntu | 23.10 | ✅ |


## Comment utiliser
GLPI_install_script s'installe en lançant les commandes suivantes dans votre terminal. Vous pouvez l'installer via la ligne de commande avec wget.

    wget https://raw.githubusercontent.com/Papy-Poc/glpi_install/main/glpi-install.sh && chmod 777 glpi-install.sh && ./glpi-install.sh
