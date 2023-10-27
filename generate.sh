#!/bin/bash

set -euo pipefail

scriptDir=$(dirname -- "$( readlink -f -- "$0"; )";)
cd "$scriptDir"

dirs=(
	"certificates/client"
	"certificates/server"
)

commonSetup() {
	for dir in "${dirs[@]}"; do
		rm -rf "$dir"

		mkdir -p "$dir/certs"
		touch "$dir/index.txt"

		cp certificates/openssl.cnf "$dir/openssl.cnf"

		done
}

serverCAandCertificate() {
	cd "$scriptDir/certificates/server"

	cat << 'EOF' > "server.cnf"
subjectAltName = @alt_names

[alt_names]
IP.1 = 172.20.20.21
IP.2 = 172.20.20.22
EOF

	## create ca key and certificate signing request
	openssl req \
		-new \
		-sha256 \
		-nodes \
		-out caCsr.pem \
		-newkey rsa:2048 \
		-keyout ca.key \
		-subj /emailAddress=deviceCa@nokia.com/C=US/ST=WA/L=Seattle/O=IPD/OU=RD/CN=DeviceCertificateAuthority \
		-config openssl.cnf

	## self sign the certificate signing request
	openssl ca \
		-config openssl.cnf \
		-md sha256 \
		-out caCert.pem \
		-batch \
		-notext \
		-selfsign \
		-keyfile ca.key \
		-create_serial \
		-infiles caCsr.pem

	## create the server key and certificate signing request
	openssl req \
		-new \
		-sha256 \
		-nodes \
		-out serverCsr.pem \
		-newkey rsa:2048 \
		-keyout server.key \
		-subj /emailAddress=server@nokia.com/C=US/ST=WA/L=Seattle/O=IPD/OU=RD/CN=ServerCert \
		-config openssl.cnf
	## sign the certificate signing requset with the ca
	openssl ca \
		-config openssl.cnf \
		-md sha256 \
		-out serverCert.pem \
		-batch \
		-extfile server.cnf \
		-keyfile ca.key \
		-infiles serverCsr.pem

	## update the srl1 startup config
	cat << EOF > ../../clab/configs/srl1.cfg
set / system gnmi-server
set / system gnmi-server admin-state enable
set / system gnmi-server rate-limit 65000
set / system gnmi-server trace-options [ request response common ]
set / system gnmi-server network-instance mgmt
set / system gnmi-server network-instance mgmt admin-state enable
set / system gnmi-server network-instance mgmt use-authentication true
set / system gnmi-server network-instance mgmt tls-profile tls
set / system gnmi-server network-instance mgmt default-tls-profile false
set / system gnmi-server network-instance mgmt port 57400
set / system tls server-profile tls key "$(cat server.key)"
set / system tls server-profile tls certificate "$(cat serverCert.pem)"
EOF

}

clientCAandCertificate() {
	cd "$scriptDir/certificates/client"

	## create ca key and certificate signing request
	openssl req \
		-new \
		-sha256 \
		-nodes \
		-out caCsr.pem \
		-newkey rsa:2048 \
		-keyout ca.key \
		-subj /emailAddress=deviceCa@nokia.com/C=US/ST=WA/L=Seattle/O=IPD/OU=RD/CN=ClientCertificateAuthority \
		-config openssl.cnf

	## self sign the certificate signing request
	openssl ca \
		-config openssl.cnf \
		-md sha256 \
		-out caCert.pem \
		-batch \
		-notext \
		-selfsign \
		-keyfile ca.key \
		-create_serial \
		-infiles caCsr.pem

	## create the server key and certificate signing request
	openssl req \
		-new \
		-sha256 \
		-nodes \
		-out clientCsr.pem \
		-newkey rsa:2048 \
		-keyout client.key \
		-subj /emailAddress=server@nokia.com/C=US/ST=WA/L=Seattle/O=IPD/OU=RD/CN=ClientCert \
		-config openssl.cnf
	## sign the certificate signing requset with the ca
	openssl ca \
		-config openssl.cnf \
		-md sha256 \
		-out clientCert.pem \
		-batch \
		-keyfile ca.key \
		-infiles clientCsr.pem

	## update the srl2 startup config
	cat << EOF > ../../clab/configs/srl2.cfg
set / system gnmi-server
set / system gnmi-server admin-state enable
set / system gnmi-server rate-limit 65000
set / system gnmi-server trace-options [ request response common ]
set / system gnmi-server network-instance mgmt
set / system gnmi-server network-instance mgmt admin-state enable
set / system gnmi-server network-instance mgmt use-authentication true
set / system gnmi-server network-instance mgmt tls-profile tls
set / system gnmi-server network-instance mgmt default-tls-profile false
set / system gnmi-server network-instance mgmt port 57400
set / system tls server-profile tls key "$(cat ../../certificates/server/server.key)"
set / system tls server-profile tls certificate "$(cat ../../certificates/server/serverCert.pem)"
set / system tls server-profile tls trust-anchor "$(cat caCert.pem)"
set / system tls server-profile tls authenticate-client true
EOF

}

commonSetup
serverCAandCertificate
clientCAandCertificate
