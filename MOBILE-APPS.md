## Non-web authentication 

Some mobile apps don't support a web based login flow, like github authentication, but do support client certificates (e.g. [Home Assistant](https://github.com/home-assistant/android/pull/2526), [Nextcloud](https://github.com/nextcloud/android/pull/12408)) or custom headers ([Immich](https://github.com/immich-app/immich/pull/10588)).

### Certificate authentication

In the Cloudflare dashboard for your domain, go to SSL/TLS then Client Certificates. Add the host `*.yourdomain.com`. Click "Create Certificate" - if you don't need to distinguish between certificates you can let Cloudflare create the certificate for you, else [create a CSR](https://developers.cloudflare.com/ssl/client-certificates/label-client-certificate/) with a CN of your choosing.

You'll need to convert the certificate to PFX before importing with a strong password to avoid Android rejecting it:
```shell
openssl pkcs12 -export -out cf.pfx -inkey cf.key -in cf.pem
```

### Custom headers

Create service tokens in Cloudflare Zero Trust -> Access.