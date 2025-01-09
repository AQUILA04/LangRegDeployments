#!/bin/bash

# Définir le mot de passe sudo
APP_SUDO='APP_SUDO'

# Fonction pour exécuter des commandes avec sudo
sudo_cmd() {
  echo "$APP_SUDO" | sudo -S $@
}

# Étape 1: Installer Docker et Docker Compose
echo "1: Installation de Docker et Docker Compose..."
sudo_cmd apt update
sudo_cmd apt install -y docker.io
sudo_cmd groupadd docker
sudo_cmd usermod -aG docker $USER
sudo_cmd systemctl start docker
sudo_cmd systemctl enable docker
sudo_cmd curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo_cmd chmod +x /usr/local/bin/docker-compose

# Étape 2: Démarrer les services avec Docker Compose
echo "2: Démarrage des services avec Docker Compose..."
docker-compose -f ./docker/services.yml up -d

# Étape 3: Installer PostgreSQL
echo "3: Installation de PostgreSQL..."
sudo_cmd apt install -y postgresql postgresql-contrib

# Étape 4: Créer la base de données
echo "4: Création de la base de onnées de LangReg..."
DB_NAME="olr_recette_db"
DB_USER="app"
DB_PASSWORD="L@ndRegAPP"
sudo_cmd -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo_cmd -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo_cmd -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Étape 5: Configurer pg_hba.conf et postgresql.conf
echo "5: Configuration de PostgreSQL..."
DB_IP=$(grep "server.ip" ./db/db.conf | cut -d '=' -f 2 | tr -d ' ')
PG_HBA="$(sudo_cmd find /etc -name pg_hba.conf)"
PG_CONF="$(sudo_cmd find /etc -name postgresql.conf)"
echo "host    all             all             $DB_IP/32            trust" | sudo_cmd tee -a $PG_HBA
sudo_cmd sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'" $PG_CONF
sudo_cmd systemctl restart postgresql

# Étape 6: Configurer les services Linux pour les fichiers JAR
echo "6: Configuration des services Linux pour les fichiers JAR..."
# Installer Java 17
sudo_cmd apt update
sudo_cmd apt install -y openjdk-17-jdk

# Vérifier l'installation
echo "Java version: $(java -version 2>&1)"

SERVICES=(
  "./service/lang-reg.service"
  "./service/afis-master.service"
  "./service/afis-service.service"
)
for SERVICE in "${SERVICES[@]}"; do
  sudo_cmd cp $SERVICE /etc/systemd/system/
  sudo_cmd systemctl daemon-reload
  sudo_cmd systemctl enable $(basename $SERVICE)
  sudo_cmd systemctl restart $(basename $SERVICE)
  sleep 30
done

# Étape 7: Vérification des services
echo "7: Vérification des services..."
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

# Étape 8: Afficher le statut final
if $ALL_SERVICES_UP; then
  echo "===> Tous les services sont opérationnels."
else
  echo "===> Une ou plusieurs erreurs détectées dans les services."
fi
