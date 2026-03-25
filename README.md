# Setup for K8s Workshop

# Settings
Create a file 'settings.yaml' and set

```shell
settings:
  num_vms: 3
  group: "grp-a"
  servertype: "cpx32"         # hcloud server-type list / cpx32 = 4 VCPUs, 8 GB RAM, 160 GB SSD
  image: "ubuntu-24.04"       # hcloud image list
  location: "nbg1"            # hcloud location list
  usage: "k8s-vm"
  worker_selector: "usage=k8s-vm"
  guacamole_selector: "usage=guacamole"
  vm_id_file: "${PROJECT_DIR}/.ssh/ssh-id"
  lab_user: "lab"
  lab_passwd: "My-1-Secret!"
  guac_admin: "myguacadmin"
  guac_passwd: "My-1-Guac-Admin-Secret!"
  cloudflare_api_token: "myCloudflareToken"
  cloudflare_email: "cloudflare@example.com"
# No server sharing
vm: []
# vm:
#   - servers:
 #    - name: guac
#       servertype: cx23
#       usage: guacamole
#     - name: vm-test-e-vm-a
#       servertype: cxp31       # use different server type for this instance
#       image: ubuntu-22.04     # use different image for this instance
#       users:
#         - name: user-a-1
#         - name: user-a-2
#     - name: vm-test-e-vm-b
#       users:
#         - name: user-b-1
#         - name: user-b-2
#         - name: user-b-3
```
# Create Resources
The script `setup.sh` creates the server and the DNS records in Cloudflare.

```shell
./setup.sh
```
# Delete Resources
The script `clean.sh` deletes all resources created by `setup.sh`.
