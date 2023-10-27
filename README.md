srl-tls-examples
================

This repo holds a Containerlab topology and a script to generate some certificates. The Containerlab topology contains two SRL nodes -- the first is setup for "normal" TLS and the second for mTLS. This repo is just meant to be used as reference and for kicking the tires with mTLS!

The `generate.sh` script can be ran to regenerate certificates, it will also update the SRL device startup configs for the Containerlab topology.

The generate script creates *two* Certificate Authorities -- a CA for "servers" and a second for "clients" -- this is done because it makes more sense to have a CA for each class of devices and also its a little more clear when testing things out.


# Helpful Links

- [SRLinux Docs - TLS-Profiles](https://documentation.nokia.com/srlinux/23-7/books/config-basics/management-servers.html#tls-profiles)
- [gNMIc Target Session Security](https://gnmic.openconfig.net/user_guide/targets/targets_session_sec/)


# Prerequisites

- [Containerlab](https://containerlab.dev/install/)
- [OpenSSL](https://www.openssl.org)
- [gNMIc](https://gnmic.openconfig.net/install/) (technically optional, but you probably want this!)


# Run Things

Optionally regenerate the certificates: `./generate.sh`.

Fire up the clab topology: `containerlab deploy -t clab/clab.yaml`

This will spin up the two SRL nodes already configured with the TLS profiles. Again, the first SRL node (srl1) is setup with a "normal" (non-mutual) TLS configuration, and the second node (srl2) is setup with mTLS.

Once the nodes are online you can test things out using gNMIc.

## Test "Normal" TLS

Test basic TLS with the srl1 node. This will validate that our client (gNMIc) is able to validate the authenticity of the server (srl1).

`gnmic --username admin --password 'NokiaSrl1!' --address 172.20.20.21 --tls-ca certificates/server/caCert.pem capabilities
`

We can also test that TLS is doing what we think it should be doing by *not* providing gNMIc with a certificate that can validate our servers authenticity (or more simply by not providing a certificate). Adding the `--debug` flag makes it much more clear what is going on as we can see the "not trusted" log message.

`gnmic --username admin --password 'NokiaSrl1!' --address 172.20.20.21 capabilities --debug`

We can also try to use the "client" Certificate Authority to see it will fail when our CA cant validate the server too:

`gnmic --username admin --password 'NokiaSrl1!' --address 172.20.20.21 --tls-ca certificates/client/caCert.pem capabilities --debug`


## Test mTLS

For mTLS things we'll instead target srl2 since its setup to authenticate clients (us, running gNMIc).

To start you can validate that things do not work with the command(s) from above since we are not presenting any certificate to the server (srl2). With the debug flag on (or looking at srl2 logs -- log in, go to bash, `tail -f /var/log/srlinux/debug/sr_gnmi_server.log`), you'll see handshake errors due to bad certificates.

`gnmic --username admin --password 'NokiaSrl1!' --address 172.20.20.22 capabilities --debug`

We can try to run a command like in the previous step where we are only telling gNMIc which CA to use to validate the *servers* identity as well -- this should fail too because while we can validate the server, the server can't validate us/the client in this state:

`gnmic --username admin --password 'NokiaSrl1!' --address 172.20.20.22 --tls-ca certificates/server/caCert.pem capabilities`

Now we can pass our certificate information to the server:

`gnmic --username admin --password 'NokiaSrl1!' --address 172.20.20.22 --tls-ca certificates/server/caCert.pem --tls-cert certificates/client/clientCert.pem --tls-key certificates/client/client.key capabilities
`

Note that we still need user/password because we `use-authentication true` in our gnmi-server config -- the `use-authentication true` is saying "hey authenticate the client (via username/password)" and the `authenticate-client true` command (in the TLS profile) is saying "hey validate the client" is giving us a legit certificate that is validated by what we have configured in the trust-anchor.


# Notes

If you need to change the Containerlab subnet for any reason, do that in the `clab/clab.yaml` file, and then update the `generate.sh` script to reflect the new address in the `server.cnf` file creation (IP SAN alt names for the "servers" (srl1/srl2)) section of the script!
