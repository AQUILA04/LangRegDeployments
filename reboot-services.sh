#!/bin/bash

# Définir le mot de passe sudo
APP_SUDO='APP_SUDO'

# Fonction pour exécuter des commandes avec sudo
sudo_cmd() {
  echo "$APP_SUDO" | sudo -S $@
}

# Étape 1: Arrêter les services Docker et les services Linux
echo "===> Arrêt des services Docker et des services Linux..."
docker-compose -f ./docker/services.yml down

SERVICES=(
  "./service/lang-reg.service"
  "./service/afis-master.service"
  "./service/afis-service.service"
)
for SERVICE in "${SERVICES[@]}"; do
  sudo_cmd systemctl stop $SERVICE
  sleep 10
done

# Étape 2: Redémarrer les services Docker et les services Linux
echo "===> Redémarrage des services Docker et des services Linux..."
docker-compose -f ./docker/services.yml up -d

for SERVICE in "${SERVICES[@]}"; do
  sudo_cmd systemctl restart $SERVICE
  sleep 30
done

# Étape 3: Vérification des services
echo "===> Vérification des services..."
HEALTH_ENDPOINTS=(
  "http://localhost:8081/actuator/health"
  "http://localhost:8082/management/health"
  "http://localhost:8083/management/health"
)
ALL_SERVICES_UP=true
for ENDPOINT in "${HEALTH_ENDPOINTS[@]}"; do
  RESPONSE=$(curl -s $ENDPOINT | grep '"status":"UP"')
  if [ -z "$RESPONSE" ]; then
    ALL_SERVICES_UP=false
    echo "===> Service à l'endpoint $ENDPOINT n'est pas UP."
  else
    echo "===> Service à l'endpoint $ENDPOINT est UP."
  fi
done

# Étape 4: Afficher le statut final
if $ALL_SERVICES_UP; then
  echo "===> Tous les services sont opérationnels."
else
  echo "===> Une ou plusieurs erreurs détectées dans les services."
fi
