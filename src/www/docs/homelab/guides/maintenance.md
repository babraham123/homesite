# Maintenance

TODO: fill in

## Update the configurations
- Render and upload the configs
```bash
tools/deploy_src.sh
```
- Re-install the relevant services
```bash
ssh jdoe@secsvcs.janedoe.com
# TODO: re-install cmd
```

The rest of the commands take place on PVE1
```bash
ssh jdoe@pve1.janedoe.com
sudo su
```

## Update secrets
```bash
/root/homelab-rendered/src/pve1/secret_update.sh secsvcs
```

If a new secret was added
```bash
ssh jdoe@secsvcs.janedoe.com
sudo podman secret create "SECRET_NAME" /root/placeholder.txt
```

## Refresh certificates
You should receive email notifications several weeks in advance of certificate expiration.

Once every 2 months
```bash
/root/homelab-rendered/src/certificates/acme_transfer.sh
```

Once a year
```bash
/root/homelab-rendered/src/certificates/self_signed_cert_gen.sh
```
