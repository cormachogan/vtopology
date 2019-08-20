# vtopology

krew plugin (using a combination of bash and Powershell/PowerCLI) for displaying vSphere topology from kubectl

For moreinformation about krew, go here: https://github.com/kubernetes-sigs/krew/blob/master/README.md

For PowerShell and PowerCLI deployment instructions, go here:
https://blog.inkubate.io/install-powershell-and-powercli-on-ubuntu-16-04/


For deployment instructions, download the yaml and gz archivem and install with krew as follows:
```
kubectl krew  install --manifest=vtopology.yaml --archive=vtopology.tar.gz
Installing plugin: vtopology
CAVEATS:
\
 |  This plugin needs the following programs:
 |  * PowerShell and PowerCLI
/
Installed plugin: vtopology
```

Usage
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
  -d | --datastores
  -k | --k8svms
  -a | --all
  -h | --help

Advanced args
  -pv <pv_id>     - display vSphere storage details about a Persistent Volume
  -kn <node_name> - display vSphere VM details about a Kubernetes node
```

Sample outputs:
```
kubectl vtopology -vc 10.27.51.106 -u administrator@vsphere.local -p VMware123. -e

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
                        Total Memory (GB) :  127.908458709716796875
                        Memory Used (GB)  :  108.3525390625

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
                        Total Memory (GB) :  127.9084625244140625
                        Memory Used (GB)  :  108.5263671875

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
                        Total Memory (GB) :  127.9084625244140625
                        Memory Used (GB)  :  73.0107421875

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
                        Total Memory (GB) :  127.9084625244140625
                        Memory Used (GB)  :  54.6357421875


kubectl vtopology -vc 10.27.51.106 -u administrator@vsphere.local -p VMware123. -k

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
        Provisioned Space (GB) :  64.084197731688618659973144531
        Used Space (GB)        :  16.166228981688618659973144531


Kubernetes Node VM Name  :  k8s-worker1

        IP Address             :  10.27.51.40
        Power State            :  PoweredOn
        On ESXi host           :  esxi-dell-g.rainpole.com
        Folder                 :  ubuntu64Guest
        Hardware Version       :  vmx-15
        Number of CPU          :  4
        Cores per Socket       :  1
        Memory (GB)            :  4
        Provisioned Space (GB) :  66.084656844846904277801513672
        Used Space (GB)        :  14.947938094846904277801513672


Kubernetes Node VM Name  :  k8s-worker2

        IP Address             :  10.27.51.41
        Power State            :  PoweredOn
        On ESXi host           :  esxi-dell-h.rainpole.com
        Folder                 :  ubuntu64Guest
        Hardware Version       :  vmx-15
        Number of CPU          :  4
        Cores per Socket       :  1
        Memory (GB)            :  4
        Provisioned Space (GB) :  65.084641523659229278564453125
        Used Space (GB)        :  14.959641523659229278564453125
       

kubectl vtopology -vc 10.27.51.106 -u administrator@vsphere.local -p VMware123. -pv pvc-0cc1a552-c2a5-11e9-80e4-005056a239d9

*** This command is being run against the following Kubernetes configuration context:  kubernetes-admin@kubernetes


=== vSphere Datastore information for PV pvc-0cc1a552-c2a5-11e9-80e4-005056a239d9 ===

        Datastore Name     :  vsanDatastore
        Datastore State    :  Available
        Datastore Type     :  vsan
        Capacity (GB)      :  5961.625
        Free Space (GB)    :  3165.875


=== Virtual Machine Disk (VMDK) information for PV pvc-0cc1a552-c2a5-11e9-80e4-005056a239d9 ===

        VMDK Name          :  520a080ca1f54de2861cca3e0836b253.vmdk
        VMDK Type          :  Flat
        VMDK Capacity (GB) :  1
        VMDK Filename      :  [vsanDatastore] 33d05a5d-e436-3297-94f7-246e962f4910/520a080ca1f54de2861cca3e0836b253.vmdk


=== Storage Policy (SPBM) information for PV pvc-0cc1a552-c2a5-11e9-80e4-005056a239d9 ===

        Kubernetes VM/Node :  k8s-worker1
        Hard Disk Name     :  Hard disk 2
        Policy Name        :  Space-Efficient
        Policy Compliance  :  compliant
```
