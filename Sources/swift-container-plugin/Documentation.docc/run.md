# Run your service

Run the container you built on cloud infrastructure or locally on a desktop container runtime.
## Overview

Swift Container Plugin builds standards-compliant container images which can run in public or private cloud infrastructure, or locally on a desktop container runtime.

The following command uses `podman` to run the service locally, making it available on port 8080:

```
% podman run -p 8080:8080 registry.example.com/myservice@sha256:a3f75d0932d052dd9d448a1c9040b16f9f2c2ed9190317147dee95a218faf1df
Trying to pull registry.example.com/myservice@sha256:a3f75d0932d052dd9d448a1c9040b16f9f2c2ed9190317147dee95a218faf1df...
...
2024-05-26T22:57:50+0000 info HummingBird : [HummingbirdCore] Server started and listening on 0.0.0.0:8080
```

When the service has started, we can access it with a web browser or `curl`:
```
% curl localhost:8080
Hello World, from Hummingbird on Ubuntu 24.04.2 LTS
```