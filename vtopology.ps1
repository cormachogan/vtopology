#!/usr/bin/pwsh
#
# Script to display some of the topology information from a vsphere cluster, using 
# PowerShell and PowerCLI. Can be incorporated into krew for use directly with 
# kubectl
#
# Author: CJH - 20 August 2019
#
####################################################################################
#
# This tool requires PowerShell and PowerCLI
#
# It has been tested on Ubuntu 17.04 and macOS Catalina 10.15.5
# 
# For instructions on deploying PowerShell and PowerCLI on Ubuntu, please see:
# https://blog.inkubate.io/install-powershell-and-powercli-on-ubuntu-16-04/
# - (although change the repo to 17.04)
#
# For instructions on deploying PowerShell and PowerCLI on macOS, please see:
# https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7 
#
# Note: I have been informed that this script will also run on MacOS/Darwin, when
# launched via krew, but you will need to modiy the interpeter on line 1 of this 
# script to point to the location of pwsh on your system
#
####################################################################################
#
# Changes
#
# 1.0.1	Add support for query tags (datastores, datacenters, clusters, hosts)
# 1.0.2 Display Storage Policies that could be used for StorageClasses in K8s
# 1.0.3 Display if ESXi hosts are in a vSphere host group and if nodes are in a 
#       vSphere VM group (supported by Enterprise PKS for AZ mapping)
# 1.0.4 Add DC and Cluster information to K8s Node outputs
# 1.0.5 Report Pod (if any) using PV/PVC - help to find orphaned PVs
# 1.0.6 Option to report all disconnected/orphaned PVs
# 1.0.7 Add Namespace to PV output
# 1.0.8 Better error handling to ensure context and vCenter match
# 1.0.9 Add networking information for services
#
####################################################################################
#
# These can be set in the config to prevent various texts when launching PowerCLI
#
false = 0
# Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
# Set-PowerCLIConfiguration -ParticipateInCEIP $false
Set-PowerCLIConfiguration -DisplayDeprecationWarnings $false -confirm:$false > /dev/null 2>&1
#
####################################################################################
#

function usage()
{
	WRITE-HOST
	WRITE-HOST "*** vTopology version 1.0.9 ***"
	WRITE-HOST
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
	Write-HOST "  -o | --orphanpvs"
	WRITE-HOST "  -t | --tags"
    WRITE-HOST "  -d | --datastores"
    WRITE-HOST "  -k | --k8svms"
	WRITE-HOST "  -s | --spbm"
	WRITE-HOST "  -a | --all"
    WRITE-HOST
    WRITE-HOST "Advanced args"
    WRITE-HOST "  -pv <pv_id>     - display vSphere storage details about a Persistent Volume"
    WRITE-HOST "  -kn <node_name> - display vSphere VM details about a Kubernetes node"
	WRITE-HOST "  -sp <policy>    - display details about a storage policy"
	WRITE-HOST "  -sv <service>   - display details about a service"
    WRITE-HOST
    WRITE-HOST "Note this tool requires PowerShell with PowerCLI, kubectl and awk"
    WRITE-HOST
	exit
}

#
########################################################################
#
# Check dependencies, i.e. pwsh awk kubectl
#
########################################################################
#

function check_deps()
{
	if ( $null -eq ( Get-Command "pwsh" -ErrorAction SilentlyContinue ))
	{
                WRITE-HOST "Unable to find powershell (pwsh) - ensure it is installed, and added to your PATH"
                WRITE-HOST
		usage
        }

	if ( $null -eq ( Get-Command "awk" -ErrorAction SilentlyContinue ))
	{
                WRITE-HOST "Unable to find awk - ensure it is installed, and added to your PATH"
                WRITE-HOST
		usage
        }

	if ( $null -eq ( Get-Command "kubectl" -ErrorAction SilentlyContinue ))
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

#################################################	
#
# Convert the secure password back to plain text
#
#################################################

	$v_password = ConvertFrom-SecureString -SecureString $secure_password -AsPlainText

#	Write-Host "Debug Creds: vCenter Server $vcenter_server"
#	Write-Host "Debug Creds: vCenter username $v_username"
#	Write-Host "Debug Creds: vCenter password $v_password"

	return $vcenter_server, $v_username, $v_password
}



##########################################################
#
# Get ALL ESXi hosts and versions
#
##########################################################


function get_hosts([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

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
				Write-Host "`t`t`tvSphere Version   : "$ESXiHost.Version
				Write-Host "`t`t`tBuild Number      : "$ESXiHost.Build
				Write-Host "`t`t`tConnection State  : "$ESXiHost.ConnectionState
				Write-Host "`t`t`tPower State       : "$ESXiHost.PowerState
				Write-Host "`t`t`tManufacturer      : "$ESXiHost.Manufacturer
				Write-Host "`t`t`tModel             : "$ESXiHost.Model
				Write-Host "`t`t`tNumber of CPU     : "$ESXiHost.NumCpu
				Write-Host "`t`t`tTotal CPU (MHz)   : "$ESXiHost.CpuTotalMhz
				Write-Host "`t`t`tCPU Used (MHz)    : "$ESXiHost.CpuUsageMhz

#####################################################################################################################
#
#-- These values return far too many decimal places. This technique limits the value displayed to two decimal places
#
#####################################################################################################################

				$RoundedTotalMemory = "{0:N2}" -f $ESXiHost.memoryTotalGB
				Write-Host "`t`t`tTotal Memory (GB) : " $RoundedTotalMemory
				$RoundedMemoryUsed = "{0:N2}" -f $ESXiHost.MemoryUsageGB
				Write-Host "`t`t`tMemory Used (GB)  : " $RoundedMemoryUsed
				Write-Host

#################################
#
#-- 1.0.3 Host Group Information
#
#################################

				$hostGroupInfo = Get-DRSclusterGroup -VMHost $ESXiHost

				foreach ($hostgroup in $hostGroupInfo)
				{
					Write-Host "`t`tESXi HOST" $ESXiHost.Name "is part of Host Group" $hostgroup.Name
					Write-Host
				}
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

function get_vms([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

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

#####################################################################################################################
#
# These values return far too many decimal places. This technique limits the value displayed to two decimal places
#
#####################################################################################################################

					$RoundedProvisionedSpaceGB = "{0:N2}" -f $VirtualMachine.ProvisionedSpaceGB
					Write-Host "`t`t`t`tProvisioned Space (GB) : " $RoundedProvisionedSpaceGB
					$RoundedUsedSpaceGB = "{0:N2}" -f $VirtualMachine.UsedSpaceGB
					Write-Host "`t`t`t`tUsed Space (GB)        : " $RoundedUsedSpaceGB
					Write-Host

###################################
#
#-- 1.0.3 VM/Host Group Information
#
###################################

					$VMGroupInfo = Get-DRSclusterGroup -VM $VirtualMachine

					foreach ($vmgroup in $VMGroupInfo)
					{
						Write-Host "`t`t`tVirtual Machine" $VirtualMachine.Name "is part of VM/Host Group" $vmgroup.Name
						Write-Host
					}
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


function get_networks([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

	$AllVDS = Get-VirtualSwitch

	Write-Host "*** 1. vSphere Networking Information ***"
	Write-Host

	foreach ($VDS in $AllVDS)
	{
		Write-Host
		Write-Host "Found Virtual Switch:" $VDS.Name "on ESXi host:" $VDS.VMHost.Name
		Write-Host
		
		$AllPGs = Get-VirtualPortGroup -VirtualSwitch $VDS 

		
		foreach ($PG in $AllPGs)
		{
			Write-Host "`tFound Port Group : " $PG.Name
			Write-Host "`t         VLAN ID : " $PG.VLanId
		}
		Write-Host
	}


##########################################	
#
#-- 1.0.9 - Service Information
#
##########################################

Write-Host
Write-Host "*** 2. Kubernetes Networking Information ***"
Write-Host 

	$AllServices = & kubectl get svc --all-namespaces -o wide --no-headers 

	foreach ($service in $AllServices)
	{
		# Write-Host "Debug : Found Service : " $service
		$svc_details = $service -split "\s+"
		$svc_namespace = $svc_details[0]
		$svc_name =  $svc_details[1]
		$svc_type = $svc_details[2]
		$svc_ip = $svc_details[3]
		$svc_selector =  $svc_details[7]

#################################################################################################
#
# Display all services apart from the "kubernetes" and "vsphere-cloud-controller-manager" service
#
#################################################################################################

		if (($svc_name -ne "kubernetes") -and ($svc_name -ne "vsphere-cloud-controller-manager"))
		{
			Write-Host
			Write-Host "Service Name : " $svc_name
			Write-Host "`tNamespace          : " $svc_namespace
			Write-Host "`tService Type       : " $svc_type
			Write-Host "`tService Cluster-IP : " $svc_ip
			Write-Host "`tService Selector   : " $svc_selector
			Write-Host

###################################################################################################
#
# Display Pods which have a matching Service Selector (not handling Services without selectors yet)
#
###################################################################################################

			Write-Host "Pods with matching service "$svc_name.Trim()" and selector "$svc_selector.Trim()"`n"
			$pod_count = 0
			$pod_details = & kubectl get pods -n $svc_namespace --selector $svc_selector --no-headers
			foreach ($pod_match in $pod_details)
			{
				$pod_details_split = $pod_match -split "\s+"
				$pod_name = $pod_details_split[0]
				Write-Host "`tPod Name                        : "$pod_name

				$ext_pod_details = & kubectl get pods $pod_name -n $svc_namespace -o wide --no-headers
				$ext_pod_details_split = $ext_pod_details -split "\s+"
				$pod_ip = $ext_pod_details_split[5]
				$node_name = $ext_pod_details_split[6]
				Write-Host "`tPod IP Address                  : "$pod_ip
				Write-Host "`tK8s node where Pod is scheduled : "$node_name
				Write-Host
				$pod_count += 1
			}
			# Write-Host "DEBUG - Total Pods using $svc_selector is $pod_count"

#################################################################################################
# Endpoints track the IP Addresses of the objects the service send traffic to.	
# When a service selector matches a pod label, that IP Address is added to your endpoints
# Check that there a matching number of endpoints
#################################################################################################

			Write-Host
			Write-Host "Endpoints (IP Addresses) that implement this service`n"
			$endpoint_count = 0
			$endpoint_details = & kubectl get endpoints $svc_name -n $svc_namespace --no-headers -o jsonpath='{.subsets[*].addresses[*].ip}'
			
			$endpoint_match = $endpoint_details -split "\s+"

			foreach ($endpoint in $endpoint_match)
			{
				if ( $endpoint -ne "<none>" )
				{
					Write-Host "`tEndpoint for service $svc_name : " $endpoint
					$endpoint_count += 1
				}
			}
			Write-Host
			#Write-Host "DEBUG - Total Endpoints for $svc_name is $endpoint_count"

			if (($pod_count -eq $endpoint_count) -and ($pod_count -gt 0) -and ($endpoint_count -gt 0))
			{
				Write-Host "`tPod count $pod_count and Endpoint count $endpoint_count match - Service $svc_name is OK"
			}
			elseif (($pod_count -gt 0) -or ($endpoint_count -gt 0))
			{
				Write-Host "`tPod count $pod_count and Endpoint count $endpoint_count do not match - Service $svc_name is NOT OK"
			}
			Write-Host

#################################################################################################
#
# Display K8s node interface information
#
#################################################################################################

			Write-Host
			Write-Host "K8s Node Network Interface Information"
			Write-Host
			$endpoint_count = 0
			$nodename_details = & kubectl get endpoints $svc_name -n $svc_namespace --no-headers -o jsonpath='{.subsets[*].addresses[*].nodeName}'
			
			$nodename_match = $nodename_details -split "\s+"

			foreach ($nodename in $nodename_match)
			{
				$AllNWInfo = Get-VM -Name $nodename | Get-NetworkAdapter
				Write-Host "`tKubernetes Worker" $nodename "connected to network" $ALLNWInfo.NetworkName
			}
			Write-Host
			Write-Host "---"
		}
	}
	Disconnect-VIServer * -Confirm:$false
}

##########################################################
#
# Get ALL Datastores
#
##########################################################


function get_datastores([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

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

####################################################################################################################
#
# These values return far too many decimal places. This technique limits the value displayed to two decimal places
#
####################################################################################################################

				$RoundedCapacity = "{0:N2}" -f $DataStore.CapacityGB
				Write-Host "`tCapacity (GB)    : " $RoundedCapacity
				$RoundedFreeSpace = "{0:N2}" -f $DataStore.FreeSpaceGB
				Write-Host "`tFree Space (GB)  : " $RoundedFreeSpace

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
#-- v1.0.9 Get individual Kubernetes Service Info 
#
#######################################################################

function get_k8s_svc_info([string]$server, [string]$user, [string]$passwd, [string]$svc)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $passwd"
	#Write-Host "Debug : Service $svc"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null


Write-Host
Write-Host "*** Kubernetes Networking Information for Service $svc ***"
Write-Host 

	$AllServices = & kubectl get svc --all-namespaces -o wide --no-headers | grep $svc

	foreach ($service in $AllServices)
	{
		$svc_details = $service -split "\s+"
		$svc_namespace = $svc_details[0]
		$svc_name =  $svc_details[1]
		$svc_type = $svc_details[2]
		$svc_ip = $svc_details[3]
		$svc_selector =  $svc_details[7]

#################################################################################################
#
# Display all services apart from the "kubernetes" and "vsphere-cloud-controller-manager" service
#
#################################################################################################

		if (($svc_name -ne "kubernetes") -and ($svc_name -ne "vsphere-cloud-controller-manager"))
		{
			Write-Host
			Write-Host "Service Name : " $svc_name
			Write-Host "`tNamespace          : " $svc_namespace
			Write-Host "`tService Type       : " $svc_type
			Write-Host "`tService Cluster-IP : " $svc_ip
			Write-Host "`tService Selector   : " $svc_selector
			Write-Host

###################################################################################################
#
# Display Pods which have a matching Service Selector (not handling Services without selectors yet)
#
###################################################################################################

			Write-Host "Pods with matching selector "$svc_selector.Trim()"`n"
			$pod_count = 0
			$pod_details = & kubectl get pods -n $svc_namespace --selector $svc_selector --no-headers
			foreach ($pod_match in $pod_details)
			{
				$pod_details_split = $pod_match -split "\s+"
				$pod_name = $pod_details_split[0]
				Write-Host "`tPod Name                        : "$pod_name

				$ext_pod_details = & kubectl get pods $pod_name -n $svc_namespace -o wide --no-headers
				$ext_pod_details_split = $ext_pod_details -split "\s+"
				$pod_ip = $ext_pod_details_split[5]
				$node_name = $ext_pod_details_split[6]
				Write-Host "`tPod IP Address                  : "$pod_ip
				Write-Host "`tK8s node where Pod is scheduled : "$node_name
				Write-Host
				$pod_count += 1
			}
			
			#Write-Host "DEBUG - Total Pods using $svc_selector is $pod_count"

###################################################################################################
#
# Endpoints track the IP Addresses of the objects the service send traffic to.	
# When a service selector matches a pod label, that IP Address is added to your endpoints
#
# Check that there a matching number of endpoints
#
###################################################################################################

			Write-Host
			Write-Host "Endpoints (IP Addresses) that implement this service`n"
			$endpoint_count = 0
			$endpoint_details = & kubectl get endpoints $svc_name -n $svc_namespace --no-headers -o jsonpath='{.subsets[*].addresses[*].ip}'
			
			$endpoint_match = $endpoint_details -split "\s+"

			foreach ($endpoint in $endpoint_match)
			{
				if ( $endpoint -ne "<none>" )
				{
					Write-Host "`tEndpoint for service $svc_name : " $endpoint
					$endpoint_count += 1
				}
			}
			Write-Host
			# Write-Host "DEBUG - Total Endpoints for $svc_name is $endpoint_count"

			if (($pod_count -eq $endpoint_count) -and ($pod_count -gt 0) -and ($endpoint_count -gt 0))
			{
				Write-Host "`tPod count $pod_count and Endpoint count $endpoint_count match - Service $svc_name is OK"
			}
			elseif (($pod_count -gt 0) -or ($endpoint_count -gt 0))
			{
				Write-Host "`tPod count $pod_count and Endpoint count $endpoint_count do not match - Service $svc_name is NOT OK"
			}
			Write-Host

########################################
#
# Display K8s node interface information
#
########################################
		
			Write-Host
			Write-Host "K8s Node Network Interface Information"
			Write-Host
			$endpoint_count = 0
			$nodename_details = & kubectl get endpoints $svc_name -n $svc_namespace --no-headers -o jsonpath='{.subsets[*].addresses[*].nodeName}'
			
			$nodename_match = $nodename_details -split "\s+"

			foreach ($nodename in $nodename_match)
			{
				$AllNWInfo = Get-VM -Name $nodename | Get-NetworkAdapter
				Write-Host "`tKubernetes Worker" $nodename "connected to network" $ALLNWInfo.NetworkName
			}
			Write-Host
		}
	}

	Disconnect-VIServer * -Confirm:$false
}

#######################################################################
#
# Get individual Kubernetes Node info
#
#######################################################################

function get_k8s_node_info([string]$server, [string]$user, [string]$passwd, [string]$nodeid)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $passwd"
	#Write-Host "Debug GH: K8s node id $nodeid"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

#################################################################################################
#
# There is no way to verify this is a virtual machine on vSphere, as opposed to bare metal, etc.
# We will just have to assume that it is, and handle it if we can't find it
#
##################################################################################################

        $IPAddress = & kubectl get nodes $nodeid  -o wide --no-headers | awk '{print $7}'

        #Write-Host "DEBUG: K8s Node External IP:    $IPAddress"

#########################################################################
#
# -- slowest part of script - need to find a better way of finding the VM
#
#########################################################################

	#$KVM = Get-VM -NoRecursion | Where-Object { $_.Guest.IPAddress -match $IPAddress } 
	$KVM = Get-VM -NoRecursion | Where-Object { $_.Guest.IPAddress -eq $IPAddress } 

#########################################################################
#
#-- v1.0.8 Make sure we are on the correct VC for this K8s node
#
#########################################################################

	if ( $null -eq $KVM )
	{
		Write-Host
		Write-Host "Error: Unable to find Virtual Machine matching Kubernetes Node --- $nodeid --- with IP Address $IPAddress"
		Write-Host "Verify that Kubernetes cluster --- $context --- is running on infrastructure managed by vCenter $server"
		Write-Host
		exit
	}
	else
	{
		Write-Host
		Write-Host "Kubernetes Node Name     : " $nodeid
		Write-Host
		Write-Host "`tVirtual Machine Name   : " $KVM.Name
		Write-Host "`tIP Address             : " $IPAddress
		Write-Host "`tPower State            : " $KVM.PowerState
		Write-Host "`tOn ESXi host           : " $KVM.VMHost
	
		$KNodeDC = Get-Datacenter -VMHost $KVM.VMHost
		$KNodeCluster = Get-Cluster -VMHost $KVM.VMHost
	
		Write-Host "`tOn Cluster             : " $KNodeDC.Name
		Write-Host "`tOn Datacenter          : " $KNodeCluster.Name
		Write-Host "`tFolder                 : " $KVM.GuestId
		Write-Host "`tHardware Version       : " $KVM.HardwareVersion
		Write-Host "`tNumber of CPU          : " $KVM.NumCpu
		Write-Host "`tCores per Socket       : " $KVM.CoresPerSocket
		Write-Host "`tMemory (GB)            : " $KVM.MemoryGB

##################################################################################################################
#
# These values return far too many decimal places. This technique limits the value displayed to two decimal places
#
##################################################################################################################

		$RoundedProvisionedSpaceGB = "{0:N2}" -f $KVM.ProvisionedSpaceGB
		Write-Host "`tProvisioned Space (GB) : " $RoundedProvisionedSpaceGB

		$RoundedUsedSpaceGB = "{0:N2}" -f $KVM.UsedSpaceGB
		Write-Host "`tUsed Space (GB)        : " $RoundedUsedSpaceGB
		Write-Host

##################################################################################################################
#
#-- v1.0.3 VM/Host Group Information - possibly used as Availability Zones for a K8s cluster. Useful to show.
#
##################################################################################################################

		$KVMGroupInfo = Get-DRSclusterGroup -VM $KVM

		foreach ($kvmgroup in $KVMGroupInfo)
		{
			Write-Host "`tVirtual Machine" $KVM.Name "is part of VM/Host Group" $kvmgroup.Name
			Write-Host
		}
	}

	Disconnect-VIServer * -Confirm:$false
}

#
#######################################################################
#
#-- v1.0.2 Get Storage Policies
#
#######################################################################
#

function get_spbm([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

	Write-Host "*** These are the Storage Policies defined on vCenter $server ***"
	Write-Host "*** The policies could be used as Storage Classes by any K8s cluster running in this environment ***"
	Write-Host

	$AllPolicies = Get-SpbmStoragePolicy -Requirement -Server $server

	foreach ($SPBM_Policy in $AllPolicies)
	{
		Write-Host "`tFound Policy:" $SPBM_Policy.Name
	}
	Write-Host

}

#
#######################################################################
#
# Get Ophaned PVs - PVs not connected to any Pods/K8s worker nodes
# Added to v1.0.6
#
#######################################################################
#

function get_orphanpvs([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

###########################################################################################
#
#-- Determine if there are any PVs that are not attached to Pods (i.e. orphans)
#
###########################################################################################

	Write-Host
	Write-Host "=== Check for orphaned PVs not attached to Pods ==="

	$pv_list = & kubectl get pv --no-headers |  awk '{print $6}'

	$found_orphans = 0

	foreach ($claim in $pv_list)
	{

		#Write-Host
		#Write-Host "DEBUG : Persistent Volume Claim $claim"
		#Write-Host

		$claim_details = $claim -split "/"
		$pvc_namespace =  $claim_details[0]
		$pvc_pv =  $claim_details[1]

###########################################################################################
#
#-- Check that we an find the namespace and claim
#
###########################################################################################

		#Write-Host "DEBUG : Persistent Volume Namespace: $pvc_namespace"
		#Write-Host "DEBUG : Persistent Volume Claim: $pvc_pv"
		#Write-Host

		$isMounted = & kubectl describe pvc  $pvc_pv -n $pvc_namespace | grep "Mounted By:" | awk -F: '{print $2}'

###########################################################################################
#
#-- Clean up blank spaces
#
###########################################################################################

		$isMounted = $isMounted -replace '\s',''

###########################################################################################
#
#-- Check that we an find the Pod mounting the PV. <none> implies no Pod
#
###########################################################################################

		if ( $isMounted -ne "<none>" )
		{
			#Write-Host "DEBUG : Persistent Volume Pod: $isMounted"
			#Write-Host

###########################################################################################
#
#-- Display node where Pod is running
#
###########################################################################################

			$pod_node = & kubectl describe pod $isMounted -n $pvc_namespace | grep Node: | awk -F: '{print $2}'

###########################################################################################
#
#-- Clean up blank spaces
#
###########################################################################################

			$pod_node = $pod_node  -replace '\s',''

			#Write-Host "DEBUG : Persistent Volume Pod Node: $pod_node"
			#Write-Host

			$node_details = $pod_node -split "/"
			$pod_node_name =  $node_details[0]
			$pod_node_ip =  $node_details[1]

			#Write-Host
			#Write-Host "DEBUG: Persistent Volume Claim : " $pvc_pv
			#Write-Host "DEBUG: Namespace               : " $pvc_namespace
			#Write-Host "DEBUG: Used by Pod             : " $isMounted
			#Write-Host "DEBUG: Attached to K8s Node    : " $pod_node_name

###########################################################################################
#
#-- For PKS, K8s Node Name is different to VM Name. Handle that difference here
#
###########################################################################################

			$KVM = Get-VM -NoRecursion | Where-Object { $_.Guest.IPAddress -eq $pod_node_ip } 

			if ( $KVM.Name -ne $pod_node_name )
			{
				#Write-Host "DEBUG: Attached to VM          : " $KVM.Name
			}
			#Write-Host
		}
		else
		{
			Write-Host
			Write-Host "`tPVC $pvc_pv does not appear to be mounted by any Pod..."
			Write-Host
			$found_orphans = $found_orphans + 1
		}
	}

###############################################################################################
#
#--If we don't have any orphans, lets report that as well instead of just finishing silently
#
###############################################################################################
	
	if ( $found_orphans -eq 0 )
	{
		Write-Host
		Write-Host "`tNo orphaned PVs found in this cluster."
		Write-Host
	}	
	else
	{
		Write-Host
		Write-Host "`tA total of $found_orphans orphaned PVs were found in this cluster."
		Write-Host
	}

	Disconnect-VIServer * -Confirm:$false
}

#
#######################################################################
#
# Get vSphere Tags
# Added to v1.0.1
#
#######################################################################
#

function get_tags([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

	$AllDCs = Get-DataCenter
	
	foreach ($DC in $AllDCs)
	{
		Write-Host
		Write-Host "`tFound DataCenter:" $DC.Name
		Write-Host

################################
#
# Get all DataCenter tags
#	
################################

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

#################################
#
# Get all Cluster tags
#	
#################################

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

##############################
#
# Get all Datastore tags
#	
##############################

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

function get_k8svms([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

#########################################################################
#
#-- v1.0.8 - Make sure we are looking at the correct VC for our K8s context
#
#########################################################################

	$node_count = 0

	$K8SVMIPS = & kubectl get nodes -o wide | awk '{print $7}'

	foreach ($IPAddress in $K8SVMIPS)
	{
		if ($IPAddress -NotMatch "EXTERNAL")
		{
			#Write-Host "DEBUG: K8s node with EXTERNAL $IPAddress found"

#########################################################################
#
# -- slowest part of script - need to find a better way of finding the VM
#
#########################################################################

			$K8SVMS = Get-VM -NoRecursion | Where-Object { $_.Guest.IPAddress -eq $IPAddress } 


			foreach ($KVM in $K8SVMS)
			{
				Write-Host
				Write-Host "Kubernetes Node VM Name  : " $KVM.Name
				Write-Host
				Write-Host "`tIP Address             : " $IPAddress
				Write-Host "`tPower State            : " $KVM.PowerState
				Write-Host "`tOn ESXi host           : " $KVM.VMHost

				$KNodeDC = Get-Datacenter -VMHost $KVM.VMHost
				$KNodeCluster = Get-Cluster -VMHost $KVM.VMHost

				Write-Host "`tOn Cluster             : " $KNodeDC.Name
				Write-Host "`tOn Datacenter          : " $KNodeCluster.Name
				Write-Host "`tFolder                 : " $KVM.GuestId
				Write-Host "`tHardware Version       : " $KVM.HardwareVersion
				Write-Host "`tNumber of CPU          : " $KVM.NumCpu
				Write-Host "`tCores per Socket       : " $KVM.CoresPerSocket
				Write-Host "`tMemory (GB)            : " $KVM.MemoryGB

####################################################################################################################
#
# These values return far too many decimal places. This technique limits the value displayed to two decimal places
#
####################################################################################################################

				$RoundedProvisionedSpaceGB = "{0:N2}" -f $KVM.ProvisionedSpaceGB
				Write-Host "`tProvisioned Space (GB) : " $RoundedProvisionedSpaceGB
				$RoundedUsedSpaceGB = "{0:N2}" -f $KVM.UsedSpaceGB
				Write-Host "`tUsed Space (GB)        : " $RoundedUsedSpaceGB
				Write-Host

####################################################################################################################
#
#-- v1.0.3 VM/Host Group Information
#
####################################################################################################################

				$KVMGroupInfo = Get-DRSclusterGroup -VM $KVM

				foreach ($kvmgroup in $KVMGroupInfo)
				{
					Write-Host "`tVirtual Machine" $KVM.Name "is part of VM/Host Group" $kvmgroup.Name
					Write-Host
				}

				$node_count = $node_count + 1
			}
		}
	}

###############################################################################################
#
#-- v1.0.8 If we don't find any nodes, lets suggest that this is the wrong vCenter/Context
#
###############################################################################################
	
	if ( $node_count -eq 0 )
	{
		Write-Host "Error: No nodes were discovered"
		Write-Host "Verify that Kubernetes cluster --- $context --- is running on infrastructure managed by vCenter $server"
		Write-Host
	}	

	Disconnect-VIServer * -Confirm:$false
}


#######################################################################
#
# Get individual SPBM Policy Info
# Added to v1.0.2
#
#######################################################################

function get_sp_info([string]$server, [string]$user, [string]$passwd, [string]$policyname)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

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

function get_pv_info([string]$server, [string]$user, [string]$passwd, [string]$pvid)
{

	#Write-Host "Debug GH: vCenter Server $server"
	#Write-Host "Debug GH: vCenter username $user"
	#Write-Host "Debug GH: vCenter password $passwd"

	Connect-VIServer $server -User $user -Password $passwd -force | Out-Null

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

###########################################################################################
#
#-- 1. Datastore info (include fix v1.0.8)
#
###########################################################################################

	Write-Host
        Write-Host "=== vSphere Datastore information for PV $pvid ==="
	
	$vsphere_datastore = Get-Datastore -Name $pv_datastore -ErrorAction SilentlyContinue

	if ( $null -eq $vsphere_datastore )
	{
		Write-Host
		Write-Host "Error: Unable to find vSphere datastore $pv_datastore on this vSphere environment"
		Write-Host "Verify that Kubernetes cluster --- $context --- is running on infrastructure managed by vCenter $server"
		Write-Host
		exit
	}
	else
	{

		Write-Host
		Write-Host "`tDatastore Name            : " $vsphere_datastore.Name
		Write-Host "`tDatastore State           : " $vsphere_datastore.State
		Write-Host "`tDatastore Type            : " $vsphere_datastore.Type
                $RoundedCapacityGB = "{0:N2}" -f $vsphere_datastore.CapacityGB
                Write-Host "`tDatastore Capacity (GB)   : " $RoundedCapacityGB
                $RoundedFreeSpaceGB = "{0:N2}" -f $vsphere_datastore.FreeSpaceGB
                Write-Host "`tDatastore Free Space (GB) : " $RoundedFreeSpaceGB
		Write-Host
	}

###########################################################################################
#
#-- 2. VMDK info
#
###########################################################################################

	Write-Host
        Write-Host "=== Virtual Machine Disk (VMDK) information for PV $pvid ==="

	$pv_vmdk = Get-HardDisk -Datastore $pv_datastore -DatastorePath "[$pv_datastore] $pv_volpath" 

	if ( $null -eq $pv_vmdk )
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

###########################################################################################
#
#-- 3. Policy Info
#
###########################################################################################

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

	$PV_POLICY = $null

	$ALLVMDKS = Get-VM | Get-HardDisk -DiskType Flat | Select-Object *

	Foreach ($VMDK in $ALLVMDKS)
	{
		# Getting VMDK info

		if ( $VMDK.Filename -match $pv_volpath )
		{
			#Write-Host "Debug: Found Match - VMDK Id is: " $VMDK.Id

			$PV_POLICY = Get-SpbmEntityConfiguration -HardDisk ( Get-HardDisk -VM $VMDK.Parent -Id $VMDK.Id )

			Write-Host
			Write-Host "`tKubernetes VM/Node : " $VMDK.Parent
			Write-Host "`tHard Disk Name     : " $PV_POLICY.Name 
			Write-Host "`tPolicy Name        : " $PV_POLICY.StoragePolicy
			Write-Host "`tPolicy Compliance  : " $PV_POLICY.ComplianceStatus 
			Write-Host
		}
	}

###########################################################################################
#
# If PV is detached from Node, then we cannot get policy info - handle that. (v1.0.5)
#
###########################################################################################

	if ( $null -eq $PV_POLICY )
	{
		Write-Host
		Write-Host "`tVMDK $pv_volpath does not appear to be attached to any K8s node - cannot retrive storage policy information..."
	}

###########################################################################################
#
#-- 4. Application info (which Pod?, is it mounted?, which K8s node is the Pod running on?)
#
###########################################################################################

	Write-Host
	Write-Host "=== Application (Pod) information for PV $pvid ==="

	$claim = & kubectl get pv $pvid --no-headers |  awk '{print $6}'

	#Write-Host
	#Write-Host "DEBUG : Persistent Volume Claim $claim"
	#Write-Host

	$claim_details = $claim -split "/"
	$pvc_namespace =  $claim_details[0]
	$pvc_pv =  $claim_details[1]

###########################################################################################
#
#-- Check that we an find the namespace and claim
#
###########################################################################################

	#Write-Host "DEBUG : Persistent Volume Namespace: $pvc_namespace"
	#Write-Host "DEBUG : Persistent Volume Claim: $pvc_pv"
	#Write-Host

	$isMounted = & kubectl describe pvc  $pvc_pv -n $pvc_namespace | grep "Mounted By:" | awk -F: '{print $2}'

###########################################################################################
#
#-- Clean up blank spaces
#
###########################################################################################

	$isMounted = $isMounted -replace '\s',''

###########################################################################################
#
#-- Check that we an find the Pod mounting the PV. <none> implies no Pod
#
###########################################################################################

	if ( $isMounted -ne "<none>" )
	{
		#Write-Host "DEBUG : Persistent Volume Pod: $isMounted"
		#Write-Host

###########################################################################################
#
#-- Display node where Pod is running
#
###########################################################################################

		$pod_node = & kubectl describe pod $isMounted -n $pvc_namespace | grep Node: | awk -F: '{print $2}'

###########################################################################################
#
#-- Clean up blank spaces
#
###########################################################################################

		$pod_node = $pod_node  -replace '\s',''

		#Write-Host "DEBUG : Persistent Volume Pod Node: $pod_node"
		#Write-Host

		$node_details = $pod_node -split "/"
		$pod_node_name =  $node_details[0]
		$pod_node_ip =  $node_details[1]

		Write-Host
		Write-Host "`tPersistent Volume       : " $pvid
		Write-Host "`tPersistent Volume Claim : " $pvc_pv

###########################################################################################
#
#-- v1.0.7 Display Namespacee (FR from FG)
#
###########################################################################################

		Write-Host "`tNamespace               : " $pvc_namespace
		Write-Host "`tUsed by Pod             : " $isMounted
		Write-Host "`tAttached to K8s Node    : " $pod_node_name

###########################################################################################
#
#-- For PKS, K8s Node Name is different to VM Name. Handle that difference here
#
###########################################################################################

		$KVM = Get-VM -NoRecursion | Where-Object { $_.Guest.IPAddress -eq $pod_node_ip } 

		if ( $KVM.Name -ne $pod_node_name )
		{
			Write-Host "`tAttached to VM          : " $KVM.Name
		}
		Write-Host
	}
	else
	{
		Write-Host
		Write-Host "`tPV $pvid / PVC $pvc_pv does not appear to be mounted by any Pod..."
		Write-Host
	}

	Disconnect-VIServer * -Confirm:$false
}

#######################################################################
#
# Display Everything...
# Get the path to VMs, Networks, Hosts, Datastores and K8s nodes
#
#######################################################################

function get_all([string]$server, [string]$user, [string]$passwd)
{

	#Write-Host "Debug : vCenter Server $server"
	#Write-Host "Debug : vCenter username $user"
	#Write-Host "Debug : vCenter password $passwd"

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

###################################################################
#
# Uncomment if you want the script to clear screen on each run
#
#		Clear-Host
#
###################################################################

		Write-Host
		$Context = & kubectl config current-context
		Write-Host "*** This command is being run against the following Kubernetes configuration context:" $Context
		Write-Host
		Write-Host "*** To switch to another context, use the kubectl config use-context command ***"
		Write-Host

######################################################################################		
#
# If there are only 1 or 2 args, then we can assume that no credentials were passed
# Thus we need to first of all prompt for credentials (unless asking for help output)
#
######################################################################################

       	switch -exact -casesensitive ($args[0]){
				{$_ -in '-e', '--hosts'} 
				{ 
					$vcenter_server, $v_username, $v_password = vc_login							
					get_hosts $vcenter_server $v_username $v_password ; break 
				}
				{$_ -in '-v', '--vms'} 
				{ 
					$vcenter_server, $v_username, $v_password = vc_login
					get_vms $vcenter_server $v_username $v_password ; break 
				}
                {$_ -in '-n', '--networks'} 
				{ 
					$vcenter_server, $v_username, $v_password = vc_login
					get_networks $vcenter_server $v_username $v_password ; break 
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
                {$_ -in '-o', '--orphanpvs'} 
				{ 
					$vcenter_server, $v_username, $v_password = vc_login
					get_orphanpvs $vcenter_server $v_username $v_password ; break 
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
				'-sp'
				{		  
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
				'-sv'{
						#Check that a service was supplied
						if ( !$args[1] )
						{
							Write-Host "No Kubernetes service name supplied - please provide the service name after -sv"
                            Write-Host "The Service name can be found using kubectl get svc"
                            Write-Host
						}
						else 
						{
							$vcenter_server, $v_username, $v_password = vc_login
							get_k8s_svc_info $vcenter_server $v_username $v_password $args[1] ; break 
						}
				}
                default {
                     		usage
                		}
			}
		exit
	}

###################################################################
#
# If there are 7 or 8 args, then we can assume that no credentials were passed
#
###################################################################

	elseif (( $Args.Count -eq 7 ) -or ( $Args.Count -eq 8 ))
	{

###################################################################
#
# Uncomment if you want the script to clear screen on each run
#
#		Clear-Host
#
###################################################################

		Write-Host
		$Context = & kubectl config current-context
		Write-Host "*** This command is being run against the following Kubernetes configuration context: " $Context
		Write-Host
		Write-Host "*** To switch to another context, use the kubectl config use-context command ***"
		Write-Host

###################################################################
#
# Get the vCenter server
#
###################################################################

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

###################################################################
#
# Get the vSphere username
#
###################################################################

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

###################################################################
#
# Get the vSphere password
#
###################################################################

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
                	{$_ -in '-o', '--orphanpvs'} { get_orphanpvs $vcenter_server $v_username $v_password ; break }
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
                        		if ( !$args[7] )
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
					'-sv'{
							# Check that Node name was supplied
							if ( !$args[7] )
							{
									Write-Host "No Kubernetes Service name supplied - please provide the Service name after -sv"
									Write-Host "The Service name can be found using kubectl get svc"
									Write-Host
							}
						else
						{ 
								#Write-Host "Debug: KN - vCenter Server $vcenter_server $args[7]"
								get_k8s_svc_info $vcenter_server $v_username $v_password $args[7] ;break 
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
