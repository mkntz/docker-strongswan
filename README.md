# Supported tags and respective `Dockerfile` links

- [`5.9.14-r3`, `5.9`, `5`, `latest`](https://github.com/mkntz/docker-strongswan/blob/master/Dockerfile)

# Quick reference

- **Maintained by**: [Makan Taghizadeh](https://github.com/mkntz/docker-strongswan)
- **Where to get help**: [GitHub Issues](https://github.com/mkntz/docker-strongswan/issues)
- **Where to file issues**: [https://github.com/mkntz/docker-strongswan/issues](https://github.com/mkntz/docker-strongswan/issues?q=)

# Quick reference (cont.)

- **Supported architectures**: (`amd64`, `arm64`)
- **Published image artifact details**: [repo-info repo's `docker-strongswan/` directory](https://github.com/mkntz/docker-strongswan)
- **Source of this description**: [GitHub repo](https://github.com/mkntz/docker-strongswan)

# What is strongSwan?

strongSwan is an open-source IPsec-based VPN solution for Linux. It supports both the classic `ipsec.conf` configuration and the modern `swanctl` configuration. strongSwan is known for its security, performance, and flexibility, making it ideal for deploying IKEv2 VPN servers.

For more information, please visit [www.strongswan.org](https://www.strongswan.org/).

# How to use this image

## Start a `strongswan` server instance

Starting a strongSwan instance requires configuration files to be mounted. At minimum, you need `ipsec.conf` and `ipsec.secrets`:

```console
$ docker run --detach \
  --name strongswan \
  --cap-add=NET_ADMIN \
  --network=host \
  --volume /path/to/ipsec.conf:/etc/ipsec.conf:ro \
  --volume /path/to/ipsec.secrets:/etc/ipsec.secrets:ro \
  mkntz/strongswan
```

## Configuration

The image is configured via bind mounts. Mount your strongSwan configuration files into the container:

| Volume | Description |
|--------|-------------|
| `/etc/ipsec.conf` | IPsec configuration (classic) |
| `/etc/ipsec.secrets` | IPsec secrets (passwords, keys) |
| `/etc/swanctl` | SwanCTL configuration directory |
| `/etc/ipsec.d` | Certificates and private keys |

### Required Files

At minimum, you need:
- `/etc/ipsec.conf` - Main IPsec configuration
- `/etc/ipsec.secrets` - Secrets for authentication

For IKEv2 with certificates:
- `/etc/ipsec.d/` - Directory containing `ca`, `certs`, `private`, `crls` subdirectories

## Container shell access and viewing logs

The `docker exec` command allows you to run commands inside a Docker container:

```console
$ docker exec -it strongswan sh
```

The log is available through Docker's container log:

```console
$ docker logs strongswan
```

## Kernel requirements

The host machine must have the IPsec kernel modules loaded:

```bash
modprobe af_key
modprobe esp
modprobe xfrmi
```

Configure the kernel for IPsec:

```bash
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.accept_redirects=0
sysctl -w net.ipv4.conf.all.send_redirects=0
sysctl -w net.ipv4.conf.default.accept_redirects=0
sysctl -w net.ipv4.conf.default.send_redirects=0
```

## Docker capabilities

The container requires `NET_ADMIN` capability and should run in host network mode:

```bash
docker run --cap-add=NET_ADMIN --network=host ...
```

# Examples

> [!NOTE]
> The following configuration examples are provided for demonstration purposes only to illustrate how to mount configuration files into the container. They may not be complete or production-ready. Please consult the [strongSwan documentation](https://www.strongswan.org/documentation.html) for accurate and secure configurations.

## IKEv2 VPN server

### 1. Generate certificates

```bash
# Generate CA
strongswan pki --gen --type ca --outform pem > ca.pem
strongswan pki --self --ca --lifetime 3650 --in ca.pem --type rsa --dn "CN=VPN CA" --outform pem > ca-cert.pem

# Generate server certificate
strongswan pki --gen --type rsa --outform pem > server-key.pem
strongswan pki --pub --in server-key.pem --type rsa | \
  strongswan pki --issue --lifetime 3650 --cakey ca.pem --ca-cert ca-cert.pem \
  --dn "CN=your-server-ip" --san your-server-ip --outform pem > server-cert.pem

# Generate client certificate
strongswan pki --gen --type rsa --outform pem > client-key.pem
strongswan pki --pub --in client-key.pem --type rsa | \
  strongswan pki --issue --lifetime 3650 --cakey ca.pem --ca-cert ca-cert.pem \
  --dn "CN=client" --outform pem > client-cert.pem

# Convert client cert + key to PKCS#12 for Windows/macOS
openssl pkcs12 -export -in client-cert.pem -inkey client-key.pem -certfile ca-cert.pem -out client.p12
```

### 2. Directory structure

```
/etc/strongswan/
├── ipsec.conf
├── ipsec.secrets
└── ipsec.d/
    ├── ca-cert.pem
    ├── private/
    │   └── server-key.pem
    └── certs/
        └── server-cert.pem
```

### 3. ipsec.conf

```ini
config setup
    charondebug="ike 2, knl 1, net 1, esp 1, dmn 1, mgr 1"

conn %default
    auto=add
    type=server
    keyexchange=ikev2
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftsubnet=0.0.0.0/0
    leftcert=server-cert.pem
    right=%any
    rightsubnet=10.0.0.0/24
    rightauth=pubkey

conn ikev2-pubkey
    rightauth=pubkey
    leftsendcert=always
    eap_identity=%any
```

### 4. ipsec.secrets

```ini
: RSA server-key.pem
: PSK "your-psk-secret"
username : EAP "your-password"
```

### 5. Run with configuration

```bash
docker run --detach \
  --name strongswan \
  --cap-add=NET_ADMIN \
  --network=host \
  --volume /etc/strongswan/ipsec.conf:/etc/ipsec.conf:ro \
  --volume /etc/strongswan/ipsec.secrets:/etc/ipsec.secrets:ro \
  --volume /etc/strongswan/ipsec.d:/etc/ipsec.d:ro \
  mkntz/strongswan
```

## via `docker compose`

Example `compose.yaml`:

```yaml
services:
  strongswan:
    image: mkntz/strongswan
    container_name: strongswan
    cap_add:
      - NET_ADMIN
    network_mode: host
    volumes:
      - ./ipsec.conf:/etc/ipsec.conf:ro
      - ./ipsec.secrets:/etc/ipsec.secrets:ro
      - ./ipsec.d:/etc/ipsec.d:ro
    restart: unless-stopped
```

Run `docker compose up -d`, wait for it to initialize completely.

# Caveats

## Host network mode required

strongSwan requires the container to run in host network mode (`--network=host`) for proper IPsec packet handling. This means the container shares the host's network namespace directly.

## NET_ADMIN capability required

The container requires the `NET_ADMIN` capability to manage network interfaces and routing. Without it, strongSwan cannot create IPsec SAs or manage IP addresses.

```bash
docker run --cap-add=NET_ADMIN --network=host ...
```

## Kernel modules

The host machine must have IPsec kernel modules loaded (`af_key`, `esp`, `xfrmi`). On some systems, you may need to load these manually or ensure they are loaded at boot.

## Firewall considerations

When running a VPN server in Docker, ensure your host firewall allows:
- UDP port 500 (IKE)
- UDP port 4500 (NAT-T)
- ESP protocol (50)

# License

View [license information](LICENSE) for the software contained in this image.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
