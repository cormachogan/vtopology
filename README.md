# vtopology

## Introduction

vtopology is a combination of bash and Powershell/PowerCLI for displaying vSphere topology from kubectl. The idea is that you should be able to map Kubernetes objects (e.g. nodes, PVs) to vSphere objects (e.g. virtual machines, VMDKs). Once installed, users can run vtopology and display underlying vSphere infrastructure components to see how their Kubernetes cluster is consuming vSphere resources.

The script can be run as a stanalone powershell script or run as a krew plugin. Running as a krew plugin means that users can run the tool via a 'kubectl vtopology' command.
For more information about how to install krew, go here: https://github.com/kubernetes-sigs/krew/blob/master/README.md.
Alternatively, simply extract the tar/gzip bundle and type 'pwsh ./vtopology.ps1 -h' for help on how to run the tool.

Both PowerShell and PowerCLI are required for this tool to work. For PowerShell and PowerCLI deployment instructions on Ubuntu, go here:
https://blog.inkubate.io/install-powershell-and-powercli-on-ubuntu-16-04/ (you will need to modify the instructions slightly to point to the correct repository for your OS version - I have used the same steps to deploy Ubuntu 17.04)

This tool has been tested and validated on Ubuntu 17.04. It has also been tested and validated on MacOS (Darwin) but the shell interpreter path to PowerShell (line 1 of vtopology.ps1 script) needs to be changed accordingly. On my MacOS environment, pwsh was found is /usr/local/bin. Once vtopology is installed by krew, it can be found in ~/.krew/store/vtopology.


## vtopology Deployment instructions for krew

Download both the yaml and gz archives and install vToplogy with krew as follows:

```
$ kubectl krew  install --manifest=vtopology.yaml --archive=vtopology.tar.gz
Installing plugin: vtopology
CAVEATS:
\
 |  This plugin needs the following programs:
 |  * PowerShell and PowerCLI
/
Installed plugin: vtopology
```

## Usage:
```
Usage: kubectl vtopology <connect-args> <args>

  where connect-args (optionally) includes the following:
 -vc | --vcenter
  -u | --username
  -p | --password

  and where args is one of the following:
  -e | --hosts
  -v | --vms
  -n | --networks
  -o | --orphanpvs
  -t | --tags
  -d | --datastores
  -k | --k8svms
  -s | --spbm
  -a | --all
  -h | --help

Advanced args
  -pv <pv_id>     - display vSphere storage details about a Persistent Volume
  -kn <node_name> - display vSphere VM details about a Kubernetes node
  -sp <policy>    - display details about a storage policy
  -sv <service>   - disply details about a service

Note this tool requires PowerShell with PowerCLI, kubectl and awk
```

## Sample outputs:
```
$ kubectl vtopology -vc 1.2.3.4 -u administrator@vsphere.local -p password -e

*** This command is being run against the following Kubernetes configuration context:  kubernetes-admin@kubernetes

Found DataCenter:  CH-Datacenter

        Found Cluster:  CH-Cluster

                Found ESXi HOST:  esxi-dell-e.rainpole.com

                        Version           :  6.7.0
                        Build             :  14320388
                        Connection State  :  Connected
                        Power State       :  PoweredOn
                        Manufacturer      :  Dell Inc.
                        Model             :  PowerEdge R630
                        Number of CPU     :  20
                        Total CPU (MHz)   :  43980
                        CPU Used (MHz)    :  13216
                        Total Memory (GB) :  127.90
                        Memory Used (GB)  :  108.35

                Found ESXi HOST:  esxi-dell-f.rainpole.com

                        Version           :  6.7.0
                        Build             :  14320388
                        Connection State  :  Connected
                        Power State       :  PoweredOn
                        Manufacturer      :  Dell Inc.
                        Model             :  PowerEdge R630
                        Number of CPU     :  20
                        Total CPU (MHz)   :  43980
                        CPU Used (MHz)    :  6142
                        Total Memory (GB) :  127.90
                        Memory Used (GB)  :  108.52

                Found ESXi HOST:  esxi-dell-g.rainpole.com

                        Version           :  6.7.0
                        Build             :  14320388
                        Connection State  :  Connected
                        Power State       :  PoweredOn
                        Manufacturer      :  Dell Inc.
                        Model             :  PowerEdge R630
                        Number of CPU     :  20
                        Total CPU (MHz)   :  43980
                        CPU Used (MHz)    :  1769
                        Total Memory (GB) :  127.95
                        Memory Used (GB)  :  73.01

                Found ESXi HOST:  esxi-dell-h.rainpole.com

                        Version           :  6.7.0
                        Build             :  14320388
                        Connection State  :  Connected
                        Power State       :  PoweredOn
                        Manufacturer      :  Dell Inc.
                        Model             :  PowerEdge R630
                        Number of CPU     :  20
                        Total CPU (MHz)   :  43980
                        CPU Used (MHz)    :  2812
                        Total Memory (GB) :  127.90
                        Memory Used (GB)  :  54.63

---

$ kubectl vtopology -vc 1.2.3.4 -u administrator@vsphere.local -p password -k

*** This command is being run against the following Kubernetes configuration context:  kubernetes-admin@kubernetes

Kubernetes Node VM Name  :  k8s-master

        IP Address             :  10.27.51.39
        Power State            :  PoweredOn
        On ESXi host           :  esxi-dell-h.rainpole.com
        Folder                 :  ubuntu64Guest
        Hardware Version       :  vmx-10
        Number of CPU          :  4
        Cores per Socket       :  1
        Memory (GB)            :  4
        Provisioned Space (GB) :  64.08
        Used Space (GB)        :  16.16


Kubernetes Node VM Name  :  k8s-worker1

        IP Address             :  10.27.51.40
        Power State            :  PoweredOn
        On ESXi host           :  esxi-dell-g.rainpole.com
        Folder                 :  ubuntu64Guest
        Hardware Version       :  vmx-15
        Number of CPU          :  4
        Cores per Socket       :  1
        Memory (GB)            :  4
        Provisioned Space (GB) :  66.08
        Used Space (GB)        :  14.94


Kubernetes Node VM Name  :  k8s-worker2

        IP Address             :  10.27.51.41
        Power State            :  PoweredOn
        On ESXi host           :  esxi-dell-h.rainpole.com
        Folder                 :  ubuntu64Guest
        Hardware Version       :  vmx-15
        Number of CPU          :  4
        Cores per Socket       :  1
        Memory (GB)            :  4
        Provisioned Space (GB) :  65.08
        Used Space (GB)        :  14.95
       
---

$ kubectl vtopology -vc 1.2.3.4 -u administrator@vsphere.local -p password -pv pvc-f721b470-d312-40a6-9f0b-a6f18f806b8f

*** This command is being run against the following Kubernetes configuration context:  kubernetes

*** To switch to another context, use the kubectl config use-context command ***


=== vSphere Datastore information for PV pvc-f721b470-d312-40a6-9f0b-a6f18f806b8f ===

        Datastore Name            :  vmfs-datastore
        Datastore State           :  Available
        Datastore Type            :  VMFS
        Datastore Capacity (GB)   :  511,999.25
        Datastore Free Space (GB) :  511,942.26


=== Virtual Machine Disk (VMDK) information for PV pvc-f721b470-d312-40a6-9f0b-a6f18f806b8f ===

        VMDK Name          :  2b40ba861a174415aacd0feed5ee73c2.vmdk
        VMDK Type          :  Flat
        VMDK Capacity (GB) :  1
        VMDK Filename      :  [vmfs-datastore] fcd/2b40ba861a174415aacd0feed5ee73c2.vmdk


=== Storage Policy (SPBM) information for PV pvc-f721b470-d312-40a6-9f0b-a6f18f806b8f ===

        Kubernetes VM/Node :  k8s-worker-02
        Hard Disk Name     :  Hard disk 2
        Policy Name        :  PureStorage
        Policy Compliance  :  compliant


=== Application (Pod) information for PV pvc-f721b470-d312-40a6-9f0b-a6f18f806b8f ===

        Persistent Volume       :  pvc-f721b470-d312-40a6-9f0b-a6f18f806b8f
        Persistent Volume Claim :  cassandra-csi-data-cassandra-1
        Used by Pod             :  cassandra-1
        Attached to K8s Node    :  k8s-worker-02
```
