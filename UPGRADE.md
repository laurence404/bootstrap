Talos nodes need to be upgraded or rebooted at least once a year, so that [certificates are renewed](https://docs.siderolabs.com/talos/latest/security/cert-management)

## Upgrading Talos

```
talosctl -n $SERVER_IP --talosconfig=./talosconfig upgrade --image <image_from_terraform.tfvars>:vX.Y.Z
```
If you have a PodDisruptionBudget preventing eviction of any pods, this will take a take a while before eventually forcing eviction

## Upgrading Kubernetes

```
talosctl -n $SERVER_IP --talosconfig=./talosconfig upgrade-k8s --to X.Y.Z
```
* If it says the upgrade is not supported between versions, try upgrading [talosctl](https://docs.siderolabs.com/talos/latest/getting-started/talosctl)
* If the command times out part way through, re-run it
