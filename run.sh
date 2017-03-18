#!/bin/bash

# Run integrations locally

INTEGRATION_JAR=target/bundle/integration.jar
LOG_BASEDIR=target
JAVA_CMD_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,address=5000,suspend=n
YAML_TEMPLATE=./target/bundle/application.yaml.template

if [[ -d /opt/openshift ]]; then
  echo "run.sh - Running on Openshift"
  cd /opt/openshift
  mkdir ./certs
  cp -s /tmp/*.p12 ./certs
  INTEGRATION_JAR=integration.jar
  YAML_TEMPLATE=./application.yaml.template
  LOG_BASEDIR=.
  JAVA_CMD_OPTS="-Xmx350m"
fi

# Import environment variables
if [ -f ./env.sh ]; then
  . ./env.sh
fi

# Build the project and the spring boot bundle
if [[ "$RUN_SH_SKIP_BUILD" != "true" ]]; then
  mvn clean install -Prun,bundle
fi

# Inject environment variables in application.yaml
# TODO - use environment vars syntax in application.yaml and skip this step
echo "Generating application.yaml file"
rm -rf application.yaml
curl -s https://raw.githubusercontent.com/symphonyoss/contrib-toolbox/master/scripts/inject-vars.sh | bash -s -- $YAML_TEMPLATE application.yaml

# Cleanup tomcat folder from previous runs
rm -rf tomcat ; mkdir tomcat

# Install and start ngrok
echo "Installing ngrok"
curl -O https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
unzip -o ngrok-stable-linux-amd64.zip
chmod +x ngrok
echo "Running ngrok from folder $PWD"
./ngrok authtoken $NGROK_TOKEN
./ngrok http --subdomain hubspot.symphonyoss --log=stdout 8186 > ngrok.log &

echo "Checking that ngrok is running..."
sleep 3
ps auxwww | grep ngrok
echo "ngrok logs..."
cat ngrok.log

# Run the Spring Boot application
echo "Running Spring Boot app from folder $PWD:"
java -Dlog4j2.outputAllToConsole=true -Dlogs.basedir=$LOG_BASEDIR $JAVA_CMD_OPTS \
-jar $INTEGRATION_JAR \
--spring.profiles.active=$APP_ID \
--server.tomcat.basedir=$PWD/tomcat \
--server.address=0.0.0.0
