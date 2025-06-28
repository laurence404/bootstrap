# Prerequisites

* Hardware supported by [Kairos](https://kairos.io/) with a minimum of 4GB RAM e.g.
  * Raspberry Pi 4 - minimum 16GB storage
  * x86 PC - minimum 35GB storage
  * virtual machine - minimum 35GB storage
* GitHub account
* Cloudflare free plan account

# Steps

## 1. Prepare cloud-config
Use [kairos/cloud-config.yaml](kairos/cloud-config.yaml) as a template and set a password and add your SSH public key.

## 2. Install Kairos
Download the Alpine flavour ISO from [here](https://kairos.io/docs/getting-started/)

### Raspberry Pi

For Raspberry Pi, burn to SD card and add `cloud-config.yaml` following [these instructions](https://kairos.io/docs/installation/raspberry/). If using WiFi, [add this config](https://kairos.io/docs/examples/wifi/). Note: adding ssh_authorized_keys from github didn't work for me - use full key instead.

### x86 PC or VM

For mini PC, burn to a USB and boot. For a VM run something like:
```
virt-install --name kairos-$(uuidgen | cut -d- -f1) --memory 4096 --vcpus 2 --disk size=35 --cdrom kairos-alpine-3.19-standard-amd64-generic-v3.3.3-k3sv1.32.2+k3s1.iso --os-variant alpinelinux3.19 --network bridge:virbr0
```
Once booted, use the address displayed on screen to connect to the [web UI](https://kairos.io/docs/installation/webui/), upload the `cloud-config.yaml` and apply.

## 3. Import cluster into local kubeconfig

So you can access the cluster from your machine with tools such as `kubectl` and can apply config with terraform, you'll need to import the cluster config. The following assumes you don't already have a context called kairos:

```
SERVER_IP=xxx.xxx.xxx.xxx
ssh kairos@${SERVER_IP} "sudo cat /etc/rancher/k3s/k3s.yaml" | sed s/default/kairos/ > kubeconfig-kairos.yaml
kubectl --kubeconfig kubeconfig-kairos.yaml config set-cluster kairos --server=https://${SERVER_IP}:6443
cp ~/.kube/config ~/.kube/config.bak
KUBECONFIG=~/.kube/config.bak:$PWD/kubeconfig-kairos.yaml kubectl config view --merge --flatten > ~/.kube/config
rm kubeconfig-kairos.yaml
kubectl config use-context kairos
```

Check it works by running (you should see some argocd pods):
```
kubectl get pods --all-namespaces
```

## 4. Get a domain

Easiest to buy a domain through the Cloudflare dashboard and they don't add markup. Cheapest are [6-9 digit .xyz](https://en.m.wikipedia.org/wiki/.xyz#1.111B_Class) domains at $0.83 per year

[Other registrars](https://spaceship.com) offer discounted first year but may charge more at renewal. This will then need to be onboarded to Cloudflare which may take a few hours.

## 5. Enable Cloudflare Zero Trust

Click "Zero Trust" on the Cloudflare dashboard, choose a team name (e.g. your domain name without the suffix) and agreed to $0 plan (requires billing details). Make a note of the team domain for later when creating the GitHub oauth integration.

## 6. Prepare terraform config

Or if you don't want to use terraform, see [manual instructions](INSTALL-MANUAL.md).

Checkout a copy of this repo if you've not already done so, and create `tf/terraform.tfvars`

```
# View Global API Key - https://dash.cloudflare.com/profile/api-tokens
cloudflare_api_key         = ""
# Email of Cloudflare account
cloudflare_account_email   = ""
# Cloudflare account ID, see https://developers.cloudflare.com/fundamentals/setup/find-account-and-zone-ids/#users-with-a-single-account
cloudflare_account_id      = ""
# The domain you've bought or onboarded to Cloudflare
domain                     = ""
# The private IP of your server ($SERVER_IP)
local_ip                   = ""
# Manually add GitHub oauth app - see https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app
# Homepage URL will be from Step 5 e.g. https://<something>.cloudflareaccess.com
# Authorization callback URL e.g. https://<something>.cloudflareaccess.com/cdn-cgi/access/callback
github_oauth_client_id     = ""
# You'll need to click "Generate a new client secret"
github_oauth_client_secret = ""
# The github users that are allowed to access your apps
allowed_email_addresses    = ["abc@example.com"]
# The name of the kubectl context configured above
kubernetes_context         = "kairos"
# Generate Token (classic) with "repo" "admin:org" - https://github.com/settings/tokens
github_token               = ""
# The name of the repo to create for your gitops repo
github_repo                = "gitops"
# (Optional) - redirect requests to https://yourdomain.com to here
apex_redirect_url          = "https://github.com/octocat/$1"
# (Optional) if you want Dependabot to keep your apps up to date in gitops, will need an account at https://hub.docker.com and generate a token at https://app.docker.com/settings/personal-access-tokens
dockerhub_username         = ""
dockerhub_pat              = ""
# (Optional) Default PSS profile - https://kubernetes.io/docs/concepts/security/pod-security-standards/). If unset will use privileged for maximum compatibility, but for security should be restricted (if some namespaces need a different profile, can be set in gitops - see cattle-system/templates/namespace.yaml)
default_pss_profile        = "restricted"
```

## 7. Apply terraform below

You'll need Terraform of OpenTofu installed, then run:
```
cd tf
tofu init
tofu apply --auto-approve
```

> [!WARNING]  
> This repo uses the Cloudflare provider v5 to enable features not available in previous versions - however despite being GA there are still a [number of issues](https://github.com/cloudflare/terraform-provider-cloudflare/issues/5573) with it you might come across when reapplying subsequent times (although reappying shouldn't be necessary)

## 8. Test

Get ArgoCD admin password (or use a GUI like Headlamp):
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Check cloudflared is running:
```
kubectl -n cloudflared -l app=cloudflared logs
```

Check hello world cloudflared service is working: https://hello.yourdomain.com You should be redirected via github to authenticate, which the first time will need you to authorise sharing your email etc with Cloudflare.

Check ArgoCD is accessible via cloudflared: https://argocd.yourdomain.com

Check ArgoCD is showing healthy apps

After a minute check local domain (should have a valid LetsEncrypt certificate): https://whoami.local.yourdomain.com. If this doesn't work, check if your router filters DNS responses containing RFC1918 private IPs.