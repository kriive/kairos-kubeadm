# PoC Kairos with kubeadm
## Build the base image
For this demo we're using a simple Ubuntu 24.04 image.
We're installing the AppArmor tools and nothing more.

```
docker build --build-arg=VERSION=0.0.0 --build-arg=KUBEADM_VERSION=1.33.1 -t test-kairos:ubuntu .
```

This Dockerfile will Kairosify a Ubuntu image and it will install all the needed
tools that are needed in a kubernetes cluster, including their dependencies.

## Build the controlplane ISO!
Before running the following command, make sure to edit `config-init.yaml` with your own values.
I suggest you to edit the IP address of the controlplane to follow your own IP.

> [!WARN]
> The content of `cluster_token` is hashed and the actual `cluster_token` passed to kubeadm is derived by it.

```
docker run -v "$PWD"/config-init.yaml:/config.yaml \
                   -v "$PWD"/build:/tmp/auroraboot \
                   -v /var/run/docker.sock:/var/run/docker.sock \
                   --rm -ti kairos.docker.scarf.sh/kairos/auroraboot \
                   --set container_image=docker://test-kairos:ubuntu \
                   --set "disable_http_server=true" \
                   --set "disable_netboot=true" \
                   --cloud-config /config.yaml \
                   --set "state_dir=/tmp/auroraboot"
```

After the build is finished, you can boot the ISO and install Kairos.
After having installed it on disk, it will start by running kubeadm.

After a couple of minutes you'll have your control plane up and running, ready to be joined.

## Build the worker ISO!
Before running the following command, make sure to edit `config-worker.yaml` with your own values.
Make sure to copy the IP of the controlplane you set before.

> [!WARN]
> The content of `cluster_token` is hashed and the actual `cluster_token` passed to kubeadm is derived by it.
> Just copy the `cluster_token` of the control plane you set earlier.

```
docker run -v "$PWD"/config-worker.yaml:/config.yaml \
                   -v "$PWD"/build:/tmp/auroraboot \
                   -v /var/run/docker.sock:/var/run/docker.sock \
                   --rm -ti kairos.docker.scarf.sh/kairos/auroraboot \
                   --set container_image=docker://test-kairos:ubuntu \
                   --set "disable_http_server=true" \
                   --set "disable_netboot=true" \
                   --cloud-config /config.yaml \
                   --set "state_dir=/tmp/auroraboot"
```

After the build is finished you can boot the ISO and install Kairos.

