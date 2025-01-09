#!/bin/bash

# Définir le mot de passe sudo
APP_SUDO='APP_SUDO'

# Fonction pour exécuter des commandes avec sudo
sudo_cmd() {
  echo "$APP_SUDO" | sudo -S $@
}

# Étape 1: Arrêter les services Docker
echo "Arrêt des services Docker..."
docker-compose -f ./docker/services.yml down

# Étape 2: Arrêter les fichiers JAR
echo "Arrêt des fichiers JAR..."
JAR_PROCESSES=(
  "optimize-land-reg.jar"
  "afis-master.jar"
  "afis-service.jar"
)
for JAR in "${JAR_PROCESSES[@]}"; do
  PID=$(pgrep -f $JAR)
  if [ ! -z "$PID" ]; then
    echo "Arrêt de $JAR (PID: $PID)..."
    sudo_cmd kill $PID
  fi
done

# Étape 3: Redémarrer les services Docker
echo "Redémarrage des services Docker..."
docker-compose -f ./docker/services.yml up -d

# Étape 4: Relancer les fichiers JAR
echo "Relancement des fichiers JAR..."
java -jar ./optimize-land-reg.jar &
sleep 5
java -jar ./afis-master.jar &
sleep 5
java -jar ./afis-service.jar &
sleep 60

# Étape 5: Vérification des services
echo "Vérification des services..."
HEALTH_ENDPOINTS=(
  "http://localhost:8081/actuator/health"
  "http://localhost:8082/actuator/health"
  "http://localhost:8083/actuator/health"
)
ALL_SERVICES_UP=true
for ENDPOINT in "${HEALTH_ENDPOINTS[@]}"; do
  RESPONSE=$(curl -s $ENDPOINT | grep '"status":"UP"')
  if [ -z "$RESPONSE" ]; then
    ALL_SERVICES_UP=false
    echo "Service à l'endpoint $ENDPOINT n'est pas UP."
  else
    echo "Service à l'endpoint $ENDPOINT est UP."
  fi
done

# Étape 6: Afficher le statut final
if $ALL_SERVICES_UP; then
  echo "Tous les services ont été redémarrés avec succès et sont opérationnels."
else
  echo "Une ou plusieurs erreurs détectées lors du redémarrage des services."
fi
