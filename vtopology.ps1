#! /usr/bin/pwsh
#
# Simple kubectl plugin which will display some of the topology 
# information from a vsphere cluster, using PowerShell and PowerCLI
#
# Author: CJH - 20 August 2019
#
####################################################################################
#
# This tool requires PowerShell and PowerCLI
#
# It has been tested on Ubuntu 17.04
# 
# For instructions on deploying PowerShell and PowerCLI on Ubuntu, please see:
#
# https://blog.inkubate.io/install-powershell-and-powercli-on-ubuntu-16-04/
# - (although change the repo to 17.04)
#
# Note: I have been informed that this script will also run on Darwin, but 
# you will need to modiy the interpeter on line 1 of this script to point
# to the location of pwsh on your system
#
####################################################################################
#
# Changes
#
# 1.0.1	Add support for query tags (datastores, datacenters, clusters, hosts)
# 1.0.2 Display Storage Policies that could be used for StorageClasses in K8s
#
####################################################################################
#
# These can be set in the config to prevent various texts when launching PowerCLI
#
# Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
# Set-PowerCLIConfiguration -ParticipateInCEIP $false
#
####################################################################################
#

function usage()
{
        WRITE-HOST "Usage: kubectl vtopology <connect-args> <args>"
	WRITE-HOST
        WRITE-HOST "  where connect-args (optionally) includes the following:"
	WRITE-HOST " -vc | --vcenter"
	WRITE-HOST "  -u | --username"
	WRITE-HOST "  -p | --password"
	WRITE-HOST
        WRITE-HOST "  and where args is one of the following:"
        WRITE-HOST "  -e | --hosts"
        WRITE-HOST "  -v | --vms"
        WRITE-HOST "  -n | --networks"
        WRITE-HOST "  -d | --datastores"
        WRITE-HOST "  -k | --k8svms"
        WRITE-HOST "  -s | --spbm"
        WRITE-HOST "  -t | --tags"
        WRITE-HOST "  -a | --all"
        WRITE-HOST "  -h | --help"
        WRITE-HOST
        WRITE-HOST "Advanced args"
        WRITE-HOST "  -pv <pv_id>     - display vSphere storage details about a Persistent Volume"
        WRITE-HOST "  -kn <node_name> - display vSphere VM details about a Kubernetes node"
	WRITE-HOST "  -sp <policy>    - display details of storage policy"
        WRITE-HOST
        WRITE-HOST "Note this tool requires PowerShell with PowerCLI, as well as kubectl"
        WRITE-HOST
	exit
}

#
########################################################################
#
# Check dependencies, i.e. pwsh and kubectl
#
########################################################################
#

function check_deps()
{
	if (( Get-Command "pwsh" -ErrorAction SilentlyContinue ) -eq $null )
	{
                WRITE-HOST "Unable to find powershell (pwsh) - ensure it is installed, and added to your PATH"
                WRITE-HOST
		usage
        }

	if (( Get-Command "kubectl" -ErrorAction SilentlyContinue ) -eq $null )
	{
                WRITE-HOST "Unable to find kubectl - ensure it is installed, and added to your PATH"
                WRITE-HOST
		usage
        }
}

#
########################################################################
#
# Login to vCenter server with appropriate credentials
#
########################################################################
#

function vc_login()
{
	$vcenter_server = Read-Host -Prompt "Please enter your vCenter Server name/IP address"
	$v_username = Read-Host -Prompt "Please enter your Username"
	$secure_password = Read-Host -AsSecureString -Prompt "Please enter your Password"
#
# Convert the secure password back to plain text
#
	$tempstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure_password)
	$v_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($tempstr)

	return $vcenter_server, $v_username, $v_password
}



##########################################################
#
# Get ALL ESXi hosts and versions
#
##########################################################


function get_hosts([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	$AllDCs = Get-DataCenter
	
	foreach ($DC in $AllDCs)
	{
		Write-Host "Found DataCenter: " $DC.Name
		Write-Host
		$ALLClusters = Get-Cluster -Location $DC

		foreach ($Cluster in $AllClusters)
		{
			Write-Host "`tFound Cluster: " $Cluster.Name
			Write-Host

			$AllHosts = Get-VMHost -Location $Cluster

			foreach ($ESXiHost in $AllHosts)
			{
				Write-Host "`t`tFound ESXi HOST: " $ESXiHost.Name
				Write-Host
				Write-Host "`t`t`tVersion           : "$ESXiHost.Version
				Write-Host "`t`t`tBuild             : "$ESXiHost.Build
				Write-Host "`t`t`tConnection State  : "$ESXiHost.ConnectionState
				Write-Host "`t`t`tPower State       : "$ESXiHost.PowerState
				Write-Host "`t`t`tManufacturer      : "$ESXiHost.Manufacturer
				Write-Host "`t`t`tModel             : "$ESXiHost.Model
				Write-Host "`t`t`tNumber of CPU     : "$ESXiHost.NumCpu
				Write-Host "`t`t`tTotal CPU (MHz)   : "$ESXiHost.CpuTotalMhz
				Write-Host "`t`t`tCPU Used (MHz)    : "$ESXiHost.CpuUsageMhz
				Write-Host "`t`t`tTotal Memory (GB) : "$ESXiHost.memoryTotalGB
				Write-Host "`t`t`tMemory Used (GB)  : "$ESXiHost.MemoryUsageGB
				Write-Host
			}
		}
	}

	Disconnect-VIServer * -Confirm:$false
}

##########################################################
#
# Get ALL VMs
#
##########################################################


function get_vms([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	$AllDCs = Get-DataCenter
	
	foreach ($DC in $AllDCs)
	{
		Write-Host "Found DataCenter: " $DC.Name
		Write-Host
		$ALLClusters = Get-Cluster -Location $DC

		foreach ($Cluster in $AllClusters)
		{
			Write-Host "`tFound Cluster: " $Cluster.Name
			Write-Host

			$AllHosts = Get-VMHost -Location $Cluster

			foreach ($ESXiHost in $AllHosts)
			{
				Write-Host "`t`tFound ESXi HOST: " $ESXiHost.Name
				Write-Host

				$AllVirtualMachines = Get-VM -Location $ESXiHost

				foreach ( $VirtualMachine in $AllVirtualMachines )
				{ 
					Write-Host "`t`t`tFound VM: " $VirtualMachine.Name 
					Write-Host
					Write-Host "`t`t`t`tGuest Hostname         : "$VirtualMachine.Guest.Hostname
					Write-Host "`t`t`t`tGuest IP Address       : "$VirtualMachine.Guest.IPAddress
					Write-Host "`t`t`t`tGuest Operating System : "$VirtualMachine.Guest.OSFullName
					Write-Host "`t`t`t`tPower State            : "$VirtualMachine.PowerState
					Write-Host "`t`t`t`tFolder                 : "$VirtualMachine.Folder
					Write-Host "`t`t`t`tNumber of CPU          : "$VirtualMachine.NumCpu
					Write-Host "`t`t`t`tTotal Memory (GB)      : "$VirtualMachine.MemoryGB
					Write-Host "`t`t`t`tProvisioned Space (GB) : "$VirtualMachine.ProvisionedSpaceGB
					Write-Host "`t`t`t`tUsed Space (GB)        : "$VirtualMachine.UsedSpaceGB
					Write-Host
				}
			}
	
		}
	}
	Disconnect-VIServer * -Confirm:$false
}

##########################################################
#
# Get ALL Networks
#
##########################################################


function get_networks([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	$AllVDS = Get-VirtualSwitch
	
	foreach ($VDS in $AllVDS)
	{
		Write-Host
		Write-Host "Found Virtual Switch:" $VDS.Name "on ESXi host:" $VDS.VMHost.Name
		Write-Host
		
		$AllPGs = Get-VirtualPortGroup -VirtualSwitch $VDS 

		
		foreach ($PG in $AllPGs)
		{
			Write-Host "`tFound Port Group : " $PG.Name
			Write-Host "`t         VLAN ID : " $PG.VlanId
		}
	}

	Disconnect-VIServer * -Confirm:$false
}

##########################################################
#
# Get ALL Datastores
#
##########################################################


function get_datastores([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	$AllDCs = Get-DataCenter
	
	foreach ($DC in $AllDCs)
	{
		Write-Host "Found DataCenter: " $DC.Name
		Write-Host
		$ALLClusters = Get-Cluster -Location $DC

		foreach ($Cluster in $AllClusters)
		{
			Write-Host "`tFound Cluster: " $Cluster.Name
			Write-Host

		$AllDatastores = Get-Datastore -Location $DC

		foreach ($DataStore in $AllDatastores)
		{
			Write-Host
			Write-Host "Found Datastore:" $DataStore.Name
			Write-Host "`tState            : " $DataStore.state
			Write-Host "`tDatastore Type   : " $DataStore.type
			Write-Host "`tCapacity (GB)    : " $DataStore.CapacityGB
			Write-Host "`tFree Space (GB)  : " $DataStore.FreeSpaceGB

			$ConnectedHosts = Get-Datastore $DataStore | Get-VMHost

			Write-Host "`tConnected hosts :"
			foreach ($connhost in $ConnectedHosts)
			{
				Write-Host "`t`t" $connhost.Name
			}
			Write-Host
		}
	}
}

	Disconnect-VIServer * -Confirm:$false
}

#######################################################################
#
# Get individual Kubernetes Node info
#
#######################################################################


function get_k8s_node_info([string]$server, [string]$user, [string]$pwd, [string]$nodeid)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"
	#Write-Host "Debug GH: K8s node id $nodeid"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

#
#######################################################################
#
# There is no way to verify this is a virtual machine on vSphere
# We will just have to assume that it is
#
#######################################################################
#

        $IPAddress = & kubectl get nodes $nodeid  -o wide --no-headers | awk '{print $7}'

        #Write-Host "DEBUG: K8s Node External IP:    $IPAddress"

#
# -- slowest part of script - need to find a better way of finding the VM
#

	#$KVM = Get-VM -NoRecursion | where { $_.Guest.IPAddress -match $IPAddress } 
	$KVM = Get-VM -NoRecursion | where { $_.Guest.IPAddress -eq $IPAddress } 

	Write-Host
	Write-Host "Kubernetes Node Name     : " $nodeid
	Write-Host
	Write-Host "`tVirtual Machine Name   : " $KVM.Name
	Write-Host "`tIP Address             : " $IPAddress
	Write-Host "`tPower State            : " $KVM.PowerState
	Write-Host "`tOn ESXi host           : " $KVM.VMHost
	Write-Host "`tFolder                 : " $KVM.GuestId
	Write-Host "`tHardware Version       : " $KVM.HardwareVersion
	Write-Host "`tNumber of CPU          : " $KVM.NumCpu
	Write-Host "`tCores per Socket       : " $KVM.CoresPerSocket
	Write-Host "`tMemory (GB)            : " $KVM.MemoryGB
	Write-Host "`tProvisioned Space (GB) : " $KVM.ProvisionedSpaceGB
	Write-Host "`tUsed Space (GB)        : " $KVM.UsedSpaceGB
	Write-Host

	Disconnect-VIServer * -Confirm:$false
}


#
#######################################################################
#
# Get Storage Policies
# Added to v1.0.2
#
#######################################################################
#

function get_spbm([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	Write-Host "*** These are Storage Policies in use on the vSphere Infrastructure which could potentially be used for Kuberenetes StorageClasses"
	Write-Host "*** This script does not display policies that are defined but not used"
	Write-Host

	$AllPolicies = Get-SpbmEntityConfiguration | Select -u StoragePolicy

	foreach ($SPBM_Policy in $AllPolicies)
	{
		Write-Host "`tFound Policy:" $SPBM_Policy.StoragePolicy
	}
	Write-Host

}


#
#######################################################################
#
# Get vSphere Tags
# Added to v1.0.1
#
#######################################################################
#

function get_tags([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	$AllDCs = Get-DataCenter
	
	foreach ($DC in $AllDCs)
	{
		Write-Host
		Write-Host "`tFound DataCenter:" $DC.Name
		Write-Host
#
# Get all DataCenter tags
#	
		$ALLDCTAGS = Get-DataCenter $DC | Get-TagAssignment 

		if ($ALLDCTAGS)
		{
			foreach ($DCTAG in $ALLDCTAGS)
			{
				Write-Host "`t`tFound Tag:" $DCTAG.Tag
			}
		}
		else
		{	
			Write-Host "`t`tNo tags found for Datacenter" $DC.Name
		}
		Write-Host
#
# Get all Cluster tags
#	
		$ALLClusters = Get-Cluster -Location $DC

		foreach ($Cluster in $AllClusters)
		{
			Write-Host "`tFound Cluster" $Cluster.Name "in Datacenter" $DC.Name
			Write-Host
			
			$AllCLUSTAGS = Get-Cluster $Cluster | Get-TagAssignment
		
			if ($ALLCLUSTAGS)
			{
				foreach ($CLUSTAG in $ALLCLUSTAGS)
				{
					Write-Host "`t`tFound Tag:" $CLUSTAG.Tag
				}
			}
			else
			{
				Write-Host "`t`tNo tags found for Cluster" $Cluster.Name "in Datacenter" $DC.Name
			}
			Write-Host
		}
#
# Get all Datastore tags
#	
		$AllDatastores = Get-Datastore -Location $DC

		foreach ($DataStore in $AllDatastores)
		{
			Write-Host "`tFound Datastore:" $DataStore.Name "in DataCenter:" $DC.Name
			Write-Host
			$ALLDSTAGS = Get-Datastore $DataStore | Get-TagAssignment

			if ($ALLDSTAGS)
			{
				foreach ($DSTAG in $ALLDSTAGS)
				{
					Write-Host "`t`tFound Tag:" $DSTAG.Tag
				}
			}
			else
			{
				Write-Host "`t`tNo tags found for DataStore" $DataStore.Name "in Datacenter" $DC.Name
			}
			Write-Host
		}
	}

	Disconnect-VIServer * -Confirm:$false
}


#
#######################################################################
#
# Get ALL Kubernetes VMs
#
#######################################################################
#

function get_k8svms([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	$K8SVMIPS = & kubectl get nodes -o wide | /usr/bin/awk '{print $7}'

	foreach ($IPAddress in $K8SVMIPS)
	{
		if ($IPAddress -NotMatch "EXTERNAL")
		{
			#Write-Host "DEBUG: K8s node with EXTERNAL $IPAddress found"
#
# -- slowest part of script - need to find a better way of finding the VM
#
			#$K8SVMS = Get-VM -NoRecursion | where { $_.Guest.IPAddress -match $IPAddress } 
			$K8SVMS = Get-VM -NoRecursion | where { $_.Guest.IPAddress -eq $IPAddress } 

			foreach ($KVM in $K8SVMS)
			{
				Write-Host
				Write-Host "Kubernetes Node VM Name  : " $KVM.Name
				Write-Host
				Write-Host "`tIP Address             : " $IPAddress
				Write-Host "`tPower State            : " $KVM.PowerState
				Write-Host "`tOn ESXi host           : " $KVM.VMHost
				Write-Host "`tFolder                 : " $KVM.GuestId
				Write-Host "`tHardware Version       : " $KVM.HardwareVersion
				Write-Host "`tNumber of CPU          : " $KVM.NumCpu
				Write-Host "`tCores per Socket       : " $KVM.CoresPerSocket
				Write-Host "`tMemory (GB)            : " $KVM.MemoryGB
				Write-Host "`tProvisioned Space (GB) : " $KVM.ProvisionedSpaceGB
				Write-Host "`tUsed Space (GB)        : " $KVM.UsedSpaceGB
				Write-Host
			}
		}
	}

	Disconnect-VIServer * -Confirm:$false
}


#######################################################################
#
# Get individual SPBM Policy Info
# Added to v1.0.2
#
#######################################################################

function get_sp_info([string]$server, [string]$user, [string]$pwd, [string]$policyname)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

	WRITE-HOST "Display Detailed Policy attributes of:" $policyname
	WRITE-HOST

	$AllAttributes = Get-SpbmStoragePolicy $policyname 

	foreach ($Attribute in $AllAttributes)
	{
		WRITE-HOST "`tFound Policy Attribute :" $Attribute.AnyOfRuleSets
	}
	WRITE-HOST
}


#######################################################################
#
# Get individual Kubernetes Persistent Volume Info
#
#######################################################################

function get_pv_info([string]$server, [string]$user, [string]$pwd, [string]$pvid)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	$connected = Connect-VIServer $server -User $user -Password $pwd -force

#
#######################################################################
#
# First, verify this is a vSphere(VCP) or CSI volume
#
#######################################################################
#

        $is_vsphere = & kubectl describe pv $pvid | grep "    Type" | awk '{print $2}'

        if ( $is_vsphere -eq "vSphereVolume" )
	{
        	#Write-Host "DEBUG: VCP is_vsphere - $is_vsphere"
        	$pv_volpath = & kubectl describe pv "${pvid}" | grep "    VolumePath:" | awk '{print $3}'
        	$pv_datastore = & kubectl describe pv "${pvid}" | grep "    VolumePath:" | awk '{print $2}' | sed 's/[][]//g'
        	$pv_policy =  kubectl describe pv "${pvid}" | grep "    StoragePolicyName:" | awk '{print $2}'
	}
	elseif ( $is_vsphere -eq "CSI" )
	{
        	#Write-Host "DEBUG: CSI is_vsphere - $is_vsphere"
		$pv_volpath = Get-VDisk -Name ${pvid} | Format-List | grep "Filename      : " | awk '{print $4}'
		$pv_datastore = Get-VDisk -Name ${pvid} | Format-List | grep "Datastore     :" | awk '{print $3}'
		$tmp_Sc = & kubectl describe pv ${pvid} | grep "StorageClass" | awk '{print $2}'
		$pv_policy = & kubectl describe sc ${tmp_Sc} | grep Parameters | awk -F "storagepolicyname=" '{print $2}'
	}
        else
	{
		Write-Host
                Write-Host "Does not appear to be a PV using vSphere Cloud Provider (VCP) - Found: $is_vsphere"
		Write-Host
                exit
        }
        #Write-Host "DEBUG: PV = $pvid"
        #Write-Host "DEBUG: Path to VMDK = $pv_volpath"
        #Write-Host "DEBUG: Datastore = $pv_datastore"
        #Write-Host "DEBUG: StorageClass = $tmp_sc"
        #Write-Host "DEBUG: Policy = $pv_policy"

#
#######################################################################
#
# OK - its definetely a vSphere volume - lets dump some useful info
#
#######################################################################
#

#
#-- 1. Datastore info
#

	Write-Host
        Write-Host "=== vSphere Datastore information for PV $pvid ==="
	
	$vsphere_datastore = Get-Datastore -Name $pv_datastore 

	if ( $vsphere_datastore -eq $null )
	{
		Write-Host
		Write-Host "Unable to find vSphere datastore"
		Write-Host
		exit
	}
	else
	{

		Write-Host
		Write-Host "`tDatastore Name     : " $vsphere_datastore.Name
		Write-Host "`tDatastore State    : " $vsphere_datastore.State
		Write-Host "`tDatastore Type     : " $vsphere_datastore.Type
		Write-Host "`tCapacity (GB)      : " $vsphere_datastore.CapacityGB
		Write-Host "`tFree Space (GB)    : " $vsphere_datastore.FreeSpaceGB
		Write-Host
	}
#
#-- 2. VMDK info
#
	Write-Host
        Write-Host "=== Virtual Machine Disk (VMDK) information for PV $pvid ==="

	$pv_vmdk = Get-HardDisk -Datastore $pv_datastore -DatastorePath "[$pv_datastore] $pv_volpath" 

	if ( $pv_vmdk -eq $null )
	{
		Write-Host
		Write-Host "Unable to find VMDK"
		Write-Host
		exit
	}
	else
	{
		Write-Host
		Write-Host "`tVMDK Name          : " $pv_vmdk.Name
		Write-Host "`tVMDK Type          : " $pv_vmdk.DiskType
		Write-Host "`tVMDK Capacity (GB) : " $pv_vmdk.CapacityGB 
		Write-Host "`tVMDK Filename      : " $pv_vmdk.Filename
		Write-Host
	}

#
#-- 3. Policy Info
#

	Write-Host
        Write-Host "=== Storage Policy (SPBM) information for PV $pvid ==="

#######################################################################################
#
# Since retrieving policy information requires the VM Name, I need to find that
# The only way seems to be to dump all the VMDKs, and match them to my one
#
#-- This is another slow part of the script
#
#######################################################################################

	$ALLVMDKS = Get-VM | Get-HardDisk -DiskType Flat | Select *

	Foreach ($VMDK in $ALLVMDKS)
	{
		# Getting VMDK info

		if ( $VMDK.Filename -match $pv_volpath )
		{
			#Write-Host "Debug: VMDK Id is: " $VMDK.Id

			$PV_POLICY = Get-SpbmEntityConfiguration -HardDisk ( Get-HardDisk -VM $VMDK.Parent -Id $VMDK.Id )

			Write-Host
			Write-Host "`tKubernetes VM/Node : " $VMDK.Parent
			Write-Host "`tHard Disk Name     : " $PV_POLICY.Name 
			Write-Host "`tPolicy Name        : " $PV_POLICY.StoragePolicy
			Write-Host "`tPolicy Compliance  : " $PV_POLICY.ComplianceStatus 
			Write-Host
			exit
		}
	}

	Disconnect-VIServer * -Confirm:$false
}


#######################################################################
#
# Display Everything...
# Get the path to VMs, Networks, Hosts, Datastores and K8s nodes
#
#######################################################################


function get_all([string]$server, [string]$user, [string]$pwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $pwd"

	Write-Host "=== VMs ==="
	get_vms $vcenter_server $v_username $v_password
	Write-Host "=== Hosts ==="
	get_hosts $vcenter_server $v_username $v_password
	Write-Host "=== Datastoress ==="
	get_datastores $vcenter_server $v_username $v_password
	Write-Host "=== Networks ==="
	get_networks $vcenter_server $v_username $v_password
	Write-Host "=== Kubernetes VMs ==="
	get_k8svms $vcenter_server $v_username $v_password
	Write-Host "=== vSphere Tags ==="
	get_tags $vcenter_server $v_username $v_password
	Write-Host "=== Storage Policies ==="
	get_spbm $vcenter_server $v_username $v_password
}

######################################################################
#
# main() - start here
#
# Count arguments. If there are none, throw usage
# Verify that govc and kubectl are in the PATH
# Validate arguments. If unrecognised one, throw usage
#
######################################################################

if ( $Args.Count -eq 0 )
{
        usage
}
else
{
        check_deps

	if (( $Args.Count -eq 1 ) -or ( $Args.Count -eq 2 ))
	{
		Clear-Host

		Write-Host
		$Context = & kubectl config current-context
		Write-Host "*** This command is being run against the following Kubernetes configuration context: " $Context
		Write-Host

		
#
# If there are only 1 or 2 args, then we can assume that no credentials were passed
# Thus we need to first of all prompt for credentials (unless asking for help output)
#
       		switch -exact -casesensitive ($args[0]){
                	{$_ -in '-e', '--hosts'} { 
							$vcenter_server, $v_username, $v_password = vc_login
							get_hosts $vcenter_server $v_username $v_password ; break 
						}
			{$_ -in '-v', '--vms'} { 
							$vcenter_server, $v_username, $v_password = vc_login
							get_vms $vcenter_server $v_username $v_password ; break 
						}
                	{$_ -in '-n', '--networks'} 
						{ 
							$vcenter_server, $v_username, $v_password = vc_login
							get_networks $vcenter_server $v_username $v_password ; break 
						}
                	{$_ -in '-d', '--datastores'} 
						{ 
							$vcenter_server, $v_username, $v_password = vc_login
							get_datastores $vcenter_server $v_username $v_password ; break 
						}
                	{$_ -in '-k', '--k8svms'} 
						{ 
							$vcenter_server, $v_username, $v_password = vc_login
							get_k8svms $vcenter_server $v_username $v_password ; break 
						}
                	{$_ -in '-s', '--spbm'} 
						{ 
							$vcenter_server, $v_username, $v_password = vc_login
							get_spbm $vcenter_server $v_username $v_password ; break 
						}
                	{$_ -in '-t', '--tags'} 
						{ 
							$vcenter_server, $v_username, $v_password = vc_login
							get_tags $vcenter_server $v_username $v_password ; break 
						}
                	{$_ -in '-a', '--all'} 
						{ 
							$vcenter_server, $v_username, $v_password = vc_login
							get_all $vcenter_server $v_username $v_password ; break
						}
                	{$_ -in '-h', '--help'} { usage }
                	'-sp'{
                       	 		# Check that Policy Name was supplied
                       	 		if ( !$args[1] )
                       	 		{
                       	       			Write-Host "No Policy Name supplied - please provide the Policy Name after -sp"
                       	       			Write-Host "The Policy Names can be found by running this tool with the -s|--spbm option"
                       	       			Write-Host
					}
                       	 		else
					{ 
						$vcenter_server, $v_username, $v_password = vc_login
						get_sp_info $vcenter_server $v_username $v_password $args[1] ; break 
					}
				}
                	'-pv'{
                       	 		# Check that PV ID was supplied
                       	 		if ( !$args[1] )
                       	 		{
                       	       			Write-Host "No Persistent Volume ID supplied - please provide the PV ID after -pv"
                       	       			Write-Host "The PV ID can be found using kubectl get pv"
                       	       			Write-Host
					}
                       	 		else
					{ 
						$vcenter_server, $v_username, $v_password = vc_login
						get_pv_info $vcenter_server $v_username $v_password $args[1] ; break 
					}
				}
                	'-kn'{
                        		# Check that Node name was supplied
                        		if ( !$args[1] )
                        		{
                                		Write-Host "No Kubernetes Node name supplied - please provide the Node name after -kn"
                                		Write-Host "The Node name can be found using kubectl get nodes"
                                		Write-Host
					}
                        		else
					{ 
						$vcenter_server, $v_username, $v_password = vc_login
						get_k8s_node_info $vcenter_server $v_username $v_password $args[1] ; break 
					}
				}
                	default {
                       	 		usage
                		}
			}
			exit
	}
#
# If there are 7 or 8 args, then we can assume that no credentials were passed
#
	elseif (( $Args.Count -eq 7 ) -or ( $Args.Count -eq 8 ))
	{
		Clear-Host

		Write-Host
		$Context = & kubectl config current-context
		Write-Host "*** This command is being run against the following Kubernetes configuration context: " $Context
		Write-Host

#
# Get the vCenter server
#
		if (( $args[0] -eq '-vc') -or ( $args[0] -eq '--vcenter' ))
		{
			$vcenter_server = $args[1]
		}
		elseif (( $args[2] -eq '-vc') -or ( $args[2] -eq '--vcenter' ))
		{
			$vcenter_server = $args[3]
		}
		elseif (( $args[4] -eq '-vc') -or ( $args[4] -eq '--vcenter' ))
		{
			$vcenter_server = $args[5]
		}
		else
		{
                	Write-Host "The vCenter cannot be found in the arguments provided"
                        Write-Host
			usage
		}
#
# Get the vSphere username
#

		if (( $args[0] -eq '-u') -or ( $args[0] -eq '--username' ))
		{
			$v_username = $args[1]
		}
		elseif (( $args[2] -eq '-u') -or ( $args[2] -eq '--username' ))
		{
			$v_username = $args[3]
		}
		elseif (( $args[4] -eq '-u') -or ( $args[4] -eq '--username' ))
		{
			$v_username = $args[5]
		}
		else
		{
                	Write-Host "The vSphere username cannot be found in the arguments provided"
                        Write-Host
			usage
		}
#
# Get the vSphere password
#

		if (( $args[0] -eq '-p') -or ( $args[0] -eq '--password' ))
		{
			$v_password = $args[1]
		}
		elseif (( $args[2] -eq '-p') -or ( $args[2] -eq '--password' ))
		{
			$v_password = $args[3]
		}
		elseif (( $args[4] -eq '-p') -or ( $args[4] -eq '--password' ))
		{
			$v_password = $args[5]
		}
		else
		{
                	Write-Host "The vSphere password cannot be found in the arguments provided"
                        Write-Host
			usage
		}

		#Write-Host "Debug: vCenter Server $vcenter_server"
		#Write-Host "Debug: Username $v_username"
		#Write-Host "Debug: Password $v_password"


       		switch -exact -casesensitive ($args[6]){
                	{$_ -in '-e', '--hosts'} { get_hosts $vcenter_server $v_username $v_password ; break }
			{$_ -in '-v', '--vms'} { get_vms $vcenter_server $v_username $v_password ; break }
                	{$_ -in '-n', '--networks'} { get_networks $vcenter_server $v_username $v_password ; break }
                	{$_ -in '-d', '--datastores'} { get_datastores $vcenter_server $v_username $v_password ; break }
                	{$_ -in '-k', '--k8svms'} { get_k8svms $vcenter_server $v_username $v_password ; break }
                	{$_ -in '-s', '--spbm'} { get_spbm $vcenter_server $v_username $v_password ; break }
                	{$_ -in '-t', '--tags'} { get_tags $vcenter_server $v_username $v_password ; break }
                	{$_ -in '-a', '--all'} { get_all $vcenter_server $v_username $v_password ; break }
                	{$_ -in '-h', '--help'} { usage }
                	 '-sp'{
                       	 		# Check that Policy Name was supplied
                       	 		if ( !$args[7] )
                       	 		{
                       	       			Write-Host "No Policy Name supplied - please provide the Policy Name after -sp"
                       	       			Write-Host "The Policy Name can be found by running this tool with the -s|--spbm option"
                       	       			Write-Host
					}
                       	 		else
					{ 
						#Write-Host "Debug: SPBM - vCenter Server $vcenter_server $args[7]"
						get_sp_info $vcenter_server $v_username $v_password $args[7] ;break 
					}
			      }
                	 '-pv'{
                       	 		# Check that PV ID was supplied
                       	 		if ( !$args[7] )
                       	 		{
                       	       			Write-Host "No Persistent Volume ID supplied - please provide the PV ID after -pv"
                       	       			Write-Host "The PV ID can be found using kubectl get pv"
                       	       			Write-Host
					}
                       	 		else
					{ 
						#Write-Host "Debug: PV - vCenter Server $vcenter_server $args[7]"
						get_pv_info $vcenter_server $v_username $v_password $args[7] ;break 
					}
			      }
                	 '-kn'{
                        		# Check that Node name was supplied
                        		if ( !$args[1] )
                        		{
                                		Write-Host "No Kubernetes Node name supplied - please provide the Node name after -kn"
                                		Write-Host "The Node name can be found using kubectl get nodes"
                                		Write-Host
					}
                        		else
					{ 
						#Write-Host "Debug: KN - vCenter Server $vcenter_server $args[7]"
						get_k8s_node_info $vcenter_server $v_username $v_password $args[7] ;break 
					}
				}
                	default {
                       	 		usage
                		}
		}
		exit
	}
	else
	{
        	Write-Host "Incorrect number of arguments passed. Provide all credentials or no credentials"
               	Write-Host
		usage
	}
}

######################################################################
