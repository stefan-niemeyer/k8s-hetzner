# Setup for K8s Workshop

# Settings
Create a file 'settings.yaml' and set

```shell
settings:
  num_vms: 3
  group: "grp-a"
  servertype: "cpx21"
  image: "ubuntu-24.04"
  datacenter: "nbg1-dc3"
  vm_id_file: "${PROJECT_DIR}/.ssh/ssh-id"
  lab_user: "lab"
  lab_passwd: "My-1-Secret!"
  cloudflare_api_token: "myCloudflareToken"
# No server sharing
vm: []
# vm:
#   - servers:
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
