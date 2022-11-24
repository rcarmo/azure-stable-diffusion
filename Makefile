# Set environment variables
export COMPUTE_GROUP?=gpu-compute
export STORAGE_GROUP?=gpu-storage
export LOCATION?=westeurope
export COMPUTE_COUNT?=3
export COMPUTE_SKU?=Standard_NV6
export COMPUTE_SKU?=Standard_NV6ads_A10_v5
export COMPUTE_PRIORITY?=Spot
export COMPUTE_INSTANCE?=gpu
export COMPUTE_FQDN=$(COMPUTE_GROUP)-$(COMPUTE_INSTANCE).$(LOCATION).cloudapp.azure.com
export VMSS_NAME=agents
export ADMIN_USERNAME?=me
export TIMESTAMP=`date "+%Y-%m-%d-%H-%M-%S"`
export FILE_SHARES=config data models
export STORAGE_ACCOUNT_NAME?=shared0$(shell echo $(COMPUTE_FQDN)|shasum|base64|tr '[:upper:]' '[:lower:]'|cut -c -16)
export SHARE_NAME?=data
export SSH_PORT?=2211
# This will set both your management and ingress NSGs to your public IP address 
# - since using "*" in an NSG may be disabled by policy
export APPLY_ORIGIN_NSG?=true
export SHELL=/bin/bash


# Permanent local overrides
-include .env

SSH_KEY_FILES:=$(ADMIN_USERNAME).pem $(ADMIN_USERNAME).pub
SSH_KEY:=$(ADMIN_USERNAME).pem

# Do not output warnings, do not validate or add remote host keys (useful when doing successive deployments or going through the load balancer)
SSH_TO_MASTER:=ssh -p $(SSH_PORT) -q -A -i keys/$(SSH_KEY) $(ADMIN_USERNAME)@$(COMPUTE_FQDN) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

# dump resource groups
list-resources:
	az group list --output table

# list image references
list-images:
	az vm image list --all --publisher Canonical --output table

# Dump list of location IDs
list-locations:
	az account list-locations --output table

list-sizes:
	az vm list-sizes --location=$(LOCATION) --output table

# Generate SSH keys for the cluster (optional)
keys:
	mkdir keys
	ssh-keygen -b 2048 -t rsa -f keys/$(ADMIN_USERNAME) -q -N ""
	mv keys/$(ADMIN_USERNAME) keys/$(ADMIN_USERNAME).pem
	chmod 0600 keys/*

# Generate the Azure Resource Template parameter files
params:
	$(eval STORAGE_ACCOUNT_KEY := $(shell az storage account keys list \
		--resource-group $(STORAGE_GROUP) \
	    	--account-name $(STORAGE_ACCOUNT_NAME) \
		--query "[0].value" \
		--output tsv | tr -d '"'))
	@mkdir parameters 2> /dev/null; STORAGE_ACCOUNT_KEY=$(STORAGE_ACCOUNT_KEY) python3 genparams.py > parameters/compute.json

# Cleanup parameters
clean:
	rm -rf parameters

deploy-storage:
	-az group create --name $(STORAGE_GROUP) --location $(LOCATION) --output table 
	-az storage account create \
		--name $(STORAGE_ACCOUNT_NAME) \
		--resource-group $(STORAGE_GROUP) \
		--location $(LOCATION) \
		--https-only \
		--output table
	$(foreach SHARE_NAME, $(FILE_SHARES), \
		az storage share create --account-name $(STORAGE_ACCOUNT_NAME) --name $(SHARE_NAME) --output tsv;)


# Create a resource group and deploy the cluster resources inside it
deploy-compute:
	-az group create --name $(COMPUTE_GROUP) --location $(LOCATION) --output table 
	az group deployment create \
		--template-file templates/compute.json \
		--parameters @parameters/compute.json \
		--resource-group $(COMPUTE_GROUP) \
		--name cli-$(LOCATION) \
		--output table \
		--no-wait

redeploy:
	-make destroy-compute
	make params
	while [[ $$(az group list | grep Deleting) =~ "Deleting" ]]; do sleep 30; done
	make deploy-compute

# create a set of SMB shares on the storage account
create-shares:
	$(eval STORAGE_ACCOUNT := $(shell az storage account list --resource-group ci-swarm-cluster --output tsv --query "[].name"))
	$(foreach SHARE_NAME, $(FILE_SHARES), \
		az storage share create --account-name $(STORAGE_ACCOUNT_NAME) --name $(SHARE_NAME) --output tsv;)

# Destroy the entire resource group and all cluster resources

destroy-environment:
	make destroy-compute
	make destroy-storage

destroy-compute:
	az group delete \
		--name $(COMPUTE_GROUP) \
		--no-wait

destroy-storage:
	az group delete \
		--name $(STORAGE_GROUP) \
		--no-wait

# SSH to node
ssh:
	-cat keys/$(ADMIN_USERNAME).pem | ssh-add -k -
	$(SSH_TO_MASTER) \
	-L 9080:localhost:80 \
	-L 9081:localhost:81 \
	-L 8080:localhost:8080 \
	-L 8888:localhost:8888 \
	-L 5000:localhost:5000

tail-cloud-init:
	-cat keys/$(ADMIN_USERNAME).pem | ssh-add -k -
	$(SSH_TO_MASTER) \
	sudo tail -f /var/log/cloud-init*

# View deployment details
view-deployment:
	az group deployment operation list \
		--resource-group $(COMPUTE_GROUP) \
		--name cli-$(LOCATION) \
		--query "[].{OperationID:operationId,Name:properties.targetResource.resourceName,Type:properties.targetResource.resourceType,State:properties.provisioningState,Status:properties.statusCode}" \
		--output table

# Watch deployment
watch-deployment:
	watch az resource list \
		--resource-group $(COMPUTE_GROUP) \
		--output table

# List endpoints
list-endpoints:
	az network public-ip list \
		--resource-group $(COMPUTE_GROUP) \
		--query '[].{dnsSettings:dnsSettings.fqdn}' \
		--output table

