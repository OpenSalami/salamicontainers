

## To build and run this image

```bash
# Build the monolithic Cinc Server image (from this directory)
podman build -t clinc-server:15-mono .

# Run it locally, exposing HTTPS on 8443
podman run --rm \
  -p 8443:443 \
  --name clinc-server-15-mono \
  clinc-server:15-mono
```

## To exec into the running container

```bash
podman exec -it clinc-server-15-mono bash
```