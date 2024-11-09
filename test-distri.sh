#!/bin/bash

# Nom de la distribution
distri=$(grep -oP '(?<=ID=").*(?=")' /etc/os-release | sed -n '1p')
# Version
version=$(grep -oP '(?<=VERSION=").*(?=")' /etc/os-release | sed -n '2p')

if [[ "$distri" == "ubuntu" && "$version" == "23.10" ]]; then
    echo "Distribution : $distri $version"
elif [[ "$distri" == "ubuntu" && "$version" == "24.10" ]]; then
    echo "Distribution : $distri $version"
elif [[ "$distri" == "debian" && "$version" =~ ^11\..* ]]; then
    echo "Distribution : $distri $version"
elif [[ "$distri" == "debian" && "$version" =~ ^12\..* ]]; then
    echo "Distribution : $distri $version"
elif [[ "$distri" == "almalinux" && "$version" =~ ^9\..* ]]; then
    echo "Distribution : $distri $version"
elif [[ "$distri" == "centos" && "$version" =~ ^9\..* ]]; then
    echo "Distribution : $distri $version"
elif [[ "$distri" == "rocky linux" && "$version" =~ ^9\..* ]]; then
    echo "Distribution : $distri $version"
else
  echo "Distribution non prise en charge : $distri_name $version"
fi


24.10
