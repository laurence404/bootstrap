# Prerequisites

* Hardware supported by [Talos](https://www.talos.dev) with a minimum of 4GB RAM and 10GB storage and an Ethernet connection e.g.
  * Raspberry Pi 4
  * x86 PC 
  * virtual machine
* GitHub account
* Cloudflare free plan account

# Steps

## 1. Install `talosctl`

See [guide](https://www.talos.dev/v1.11/talos-guides/install/talosctl/)

## 2. Install talos

Follow relevant instructions below which will bring up talos in maintenance mode, ready to be bootstrapped with terraform. You should be able to run `talosctl` to interrogate the machine before installation, such as listing disks:

```
talosctl -n 192.168.xxx.xxx get disks --insecure
```

### Raspberry Pi

See [guide](https://www.talos.dev/v1.11/talos-guides/install/single-board-computers/rpi_generic/)

### x86 PC

See [guide](https://www.talos.dev/v1.11/talos-guides/install/bare-metal-platforms/iso/). For secureboot, see this [guide](https://www.talos.dev/v1.11/talos-guides/install/bare-metal-platforms/secureboot/). On some systems you'll need to clear the secureboot keys to enter setup mode, or manually add from `loader/keys/auto`.

If you need an image with customised kernel arguments or additional modules (e.g. i915 drivers) generate one at the [Image factory](https://factory.talos.dev/).

### VM

Download [iso](https://github.com/siderolabs/talos/releases) and run: 

```
virt-install --name talos-$(uuidgen | cut -d- -f1) --memory 4096 --vcpus 2 --disk size=50 --cdrom ~/Downloads/metal-amd64.iso --os-variant alpinelinux3.19 --network bridge:virbr0
```

## 3. Get a domain

Easiest to buy a domain through the Cloudflare dashboard and they don't add markup. Cheapest are [6-9 digit .xyz](https://en.m.wikipedia.org/wiki/.xyz#1.111B_Class) domains at $0.83 per year

[Other registrars](https://spaceship.com) offer discounted first year but may charge more at renewal. This will then need to be onboarded to Cloudflare which may take a few hours.

## 4. Enable Cloudflare Zero Trust

Click "Zero Trust" on the Cloudflare dashboard, choose a team name (e.g. your domain name without the suffix) and agreed to $0 plan (requires billing details). Make a note of the team domain for later when creating the GitHub oauth integration.

## 5. Prepare terraform config

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
# The private IP of your server (shown on screen)
local_ip                   = ""
# Manually add GitHub oauth app - see https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app
# Homepage URL will be from Step 5 e.g. https://<something>.cloudflareaccess.com
# Authorization callback URL e.g. https://<something>.cloudflareaccess.com/cdn-cgi/access/callback
github_oauth_client_id     = ""
# You'll need to click "Generate a new client secret"
github_oauth_client_secret = ""
# The github users that are allowed to access your apps
allowed_email_addresses    = ["abc@example.com"]
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
# Obtain correct disk by running talosctl -n 192.168.xxx.xxx get disks --insecure (e.g. /dev/sda)
disk                       = ""
# Set to true to encrypt disks using secureboot & TPM
disk_encryption            = true
# (Optional) Override default for secureboot image, or customised image
image                      = "factory.talos.dev/installer-secureboot/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:v1.11.0"
```

## 6. Apply terraform below

You'll need Terraform or OpenTofu installed, then run:
```
cd tf
tofu init
tofu apply --auto-approve
```

## 7. Import cluster into local kubeconfig

So you can access the cluster locally with tools such as `kubectl`, talosctl will import the Kubernetes credentials into your local kubernetes config:
```
tofu output -raw talosconfig > talosconfig
talosctl -n 192.168.xxx.xxx --talosconfig=talosconfig kubeconfig
```

Check it works by running (you should see some argocd pods):
```
kubectl get pods --all-namespaces
```

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

## 9. Cleanup

You may wish to rotate your [Cloudflare Global API key](https://dash.cloudflare.com/profile/api-tokens), so as not to leave a powerful credential in your terraform config and state. If its necessary to run terraform again, the new key can be added to `terraform.tfvars`.