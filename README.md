# Vertical Pod Autoscaler


# Notice

This repository provides a modified configuration to install VPA 0.11. It is designed to work with Kubernetes versions between 1.22 and 1.24.

The project is based on: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler. All directory structure is inherited from the original project, with the addition of a Dockerfile and tui.sh. These new additions are designed to simplify the installation and usage of the VPA.

### Using the Docker Version
To use the Docker version, please run the following command in a directory on your local machine where you have write permissions:

```
docker run -it -v ~/.kube/config:/root/.kube/config -v $(pwd):/output registry.xx.com/repo/vpa:0.11
```

Please note, if your kubeconfig file is not stored in the default location, replace ~/.kube/config in the Docker run command with the location of your kubeconfig file.

### Features
The script provides a Terminal User Interface (TUI) that supports the following actions:

* `"VPA installation"`
* `"VPA removal"`
* `"Creation of a VPA rule for all deployments in specified namespaces"`
* `"Generation of a CSV report for all deployments with VPA rules"`
* `"Patching VPA admission webhook configuration to exclude system namespaces"`
"
