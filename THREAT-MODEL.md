These are some risks that have been considered

# Avoidable

## ToS violation

If you violate the [Cloudflare terms of service](https://www.cloudflare.com/terms/) your account may be terminated, or you'll be asked to upgrade to a paid service. An important term is you're not allowed to:
> serve video or a disproportionate percentage of pictures, audio files, or other large files

For this use case it's recommended to use the `*.local.yourdomain.com` endpoint when streaming to keep the traffic within your local network. When you're away from the home network, limit consumption of large files (many apps have options to only automatically sync when connected to your home network).

Having said that, from a quick internet search, it seems many people have been hosting media servers behind Cloudflare for personal use for many years without issue. If you don't use an excessive amount of bandwidth you'll probably be fine.

Obviously pirated content is also against the ToS.

# Possible

In approximate order of likelihood, but YMMV.

## Misconfiguration

Cloud is complicated and easy to misconfigure - [even](https://blog.qualys.com/vulnerabilities-threat-research/2023/12/18/hidden-risks-of-amazon-s3-misconfigurations) [big](https://unit42.paloaltonetworks.com/large-scale-cloud-extortion-operation/) [companies](https://thehackernews.com/2022/10/microsoft-confirms-server.html) make mistakes. Have you set the firewall correctly? Has something else disabled it without you noticing?

It's not just ensuring you don't ever misconfigure, but also any [charts](https://techcommunity.microsoft.com/blog/microsoftdefendercloudblog/the-risk-of-default-configuration-how-out-of-the-box-helm-charts-can-breach-your/4409560) you may use.

This guide uses Cloudflare to minimise the risk of misconfiguration - there should be no mistakes you can make within Kubernetes or Talos that will result in you exposing unauthenticated endpoints to the public Internet. This assumes that the Cloudflare configuration in this repo is sound - it should be simple enough to review.

## Slow patching

If you expose something publicly on the Internet and don't patch it, it will [get hacked](https://thehackernews.com/2023/03/lastpass-hack-engineers-failure-to.html) sooner or later. Everything public facing in this guide is handled by a Cloudflare or GitHub, so it's not your responsibility.

Even if you set alerts to wake you up in the middle of the night when a new security update is released, you'd still be slower due to embargoes that you'd not be part of. Or you might not even be able to patch because you're using a container whose author is slow to provide updates.

## Malicious helm chart or container

Updates will only be performed when you push a change to git or merge a dependabot PR. Where possible container digests should be pinned by digest (which dependabot will maintain) to avoid [issues](https://github.com/coreruleset/modsecurity-crs-docker/issues/87) with mutable tags, which could result in a similar compromise to the [tj-actions/changed-files incident](https://unit42.paloaltonetworks.com/github-actions-supply-chain-attack/).

Changes to helm charts are opaque version number changes - however if you disable auto sync in ArgoCD UI, then you'll have the opportunity to view the diff before applying - check for RoleBindings, resources being added to other namespaces etc. However there doesn't (yet) appear to be any public examples of this - in the meantime if you keep to popular and well maintained charts you should be fine.

Container updates are also opaque, suggest using a popular container with a good build process (e.g. [SLSA](https://slsa.dev) level 2 or above). There have been [public examples](https://unit42.paloaltonetworks.com/malicious-cryptojacking-images/) of containers on dockerhub containing crypto miners. Consider NetworkPolicy to segment workloads and disable egress if it's unnecessary.

Configuring restricted [pod security admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) by default on namespaces will generally prevent container breakout, unless you've fallen behind patching Talos (n-day), or a 0-day is used (very unlikely). 

## Physical theft

For example someone steals the server from your home, gaining access to personal data stored on it. Enable disk encryption (which is sealed by the TPM) to mitigate.

## Local attacker

If there are untrusted devices on your home LAN, or a compromised device, they can [connect directly](https://raesene.github.io/blog/2021/01/03/Kubernetes-is-a-router/) to any pod not protected with a NetworkPolicy. The example gitops repo included NetworkPolicy resources to protect against this.

# Unlikely

In no particular order

## Evil maid

Someone with physical access tampers with the server in order to later get remote access - enable disk encryption (which is sealed by the TPM) to mitigate.

## Cloud provider

The services provided by Cloudflare necessitate decryption and inspection of traffic (URLs and content) to and from your server. You'll have to accept their [commitments](https://blog.cloudflare.com/certifying-our-commitment-to-your-right-to-information-privacy/) at face value.

There is a risk that Cloudflare itself gets compromised, but this is small given the resources invested to protect it. Also your homelab would be one of the less interesting things on Cloudflare!

## Authentication provider

Cloudflare Zero Trust is configured to authenticate users via GitHub. There is a risk than users could have their accounts compromised, which in turn gives access to content you're hosting. It's recommended they use phishing resistant MFA, such as passkeys on their account. This risk is arguably less than hosting your own authentication mechanism with MFA as you'd need to expose that to the public Internet - GitHub are less likely to suffer misconfigurations and will patch quicker (see above).

There is a risk that GitHub itself gets compromised, but this is small given the resources invested to protect it. Also your homelab would be one of the less interesting things on GitHub!

## Termination of Cloudflare free plan

This guide relies upon the [Cloudflare free plan](https://www.cloudflare.com/plans/free/), which they state they'll [always offer](https://webmasters.stackexchange.com/questions/88659/how-can-cloudflare-offer-a-free-cdn-with-unlimited-bandwidth).