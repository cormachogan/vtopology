# vtopology
kubelet plugin testing for displaying vSphere topology from kubectl

The bash script requires gpvc, the VMware govmomi API CLI

Usage: kubectl vtopology <arg>
  where arg is one of the following:
        -e | --hosts
        -v | --vms
        -n | --networks
        -d | --datastores
        -a | --all
        -h | --help

Note this tool requires VMware GO API CLI - govc
It can be found here: https://github.com/vmware/govmomi/releases
