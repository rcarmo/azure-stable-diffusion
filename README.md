# azure-stable-diffusion

A quick hack to run Stable Diffusion on an Azure GPU Spot Instance.

## What

This is an Azure Resource Manager template that automatically deploys a GPU enabled spot atop Ubuntu 20.04. 

The template defaults to deploying NV6 Series VMs (`Standard_NV6` or, if you can get them, `Standard_NV6ads_A10_v5`) with the smallest possible managed SSD disk size (P4, 32GB). It also deploys (and mounts) an Azure File Share on the machine with (very) permissive access at `/srv`, which makes it quite easy to keep copies of your work between VM instantiations.

## Why

I was getting a little bored with the notebook workflow in [Google Collab][collab] and wanted access to a more persistent GPU setup without breaking the bank (hence spot instances, which I can run on demand in my personal subscription).

## Roadmap

* [ ] change instance type to `Spot` for lower cost
* [x] Install NVIDIA drivers and CUDA toolkit
* [x] remove unused packages from `cloud-config`
* [x] remove unnecessary commands from `Makefile`
* [x] remove unnecessary files from repo and trim history
* [x] fork from [`azure-k3s-cluster`][aks], new `README`

## `Makefile` commands

* `make keys` - generates an SSH key for provisioning
* `make deploy-storage` - deploys shared storage
* `make params` - generates ARM template parameters
* `make deploy-compute` - deploys VM
* `make view-deployment` - view deployment status
* `make watch-deployment` - watch deployment progress
* `make ssh` - opens an SSH session to `master0` and sets up TCP forwarding to `localhost`
* `make tail-cloud-init` - opens an SSH session and tails the `cloud-init` log
* `make list-endpoints` - list DNS aliases
* `make destroy-environment` - destroys the entire environment (should not be the default)
* `make destroy-compute` - destroys only the compute resources (should be the default if you want to save costs)
* `make destroy-storage` - destroys the storage (should be avoided)

## Recommended Sequence

    az login
    make keys
    make deploy-storage
    make params
    make deploy-compute
    make view-deployment
    # Go to the Azure portal and check the deployment progress
    
    # Clean up after we're done working for the day, to save costs (preserves storage)
    make destroy-compute
    
    # Clean up the whole thing (destroys storage as well)
    make destroy-environment

## Requirements

* [Python 3][p]
* The [Azure CLI][az] (`pip install -U -r requirements.txt` will install it)
* GNU `make` (you can just read through the `Makefile` and type the commands yourself)

## Internals

TODO

## NVIDIA Support

Although it is possible to run machines like `Standard_NV6ads_A10_v5` as spot instances, this should be considered experimental.

## Deployment Notes

> **Pro Tip:** You can set `STORAGE_ACCOUNT_GROUP` and `STORAGE_ACCOUNT_NAME` inside an `.env` file if you want to use a pre-existing storage account. As long as you use `make` to do everything, the value will be automatically overridden.

## Disclaimers

Keep in mind that this was written for conciseness and ease of experimentation -- this is not meant to be used as a production service.

[k3s]: https://github.com/rcarmo/azure-k3s-cluster
[d]: http://docker.com
[p]: http://python.org
[az]: https://github.com/Azure/azure-cli
[collab]: https://colab.research.google.com/