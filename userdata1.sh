#!/bin/bash
apt update -y
apt install -y apache2

INSTANCE_ID=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/id -H "Metadata-Flavor: Google")

cat <<EOF > /var/www/html/index.html
<h1>Terraform Project Server 2</h1>
<h2>Instance ID: $INSTANCE_ID</h2>
<p>Welcome to CloudChamp's Channel</p>
EOF

systemctl restart apache2
systemctl enable apache2
