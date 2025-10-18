Upgrading talos:

```
talosctl -n $SERVER_IP --talosconfig=./talosconfig upgrade --image <image_from_terraform.tfvars>:vX.Y.Z
```

Upgrading Kubernetes:

```
talosctl -n $SERVER_IP --talosconfig=./talosconfig upgrade-k8s --to X.Y.Z
```
