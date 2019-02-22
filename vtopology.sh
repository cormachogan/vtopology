#! /bin/bash
#
# Simple kubectl plugin which will display some of the topology 
# information from a vsphere cluster, using Govc - the CLI
# that uses the vmware/govmomi (the GO library for the VMware
# vSphere APIs)
#
# Author: CJH - 20th Feb 2019
#
######################################################################
#
# This tool requires Govc - https://github.com/vmware/govmomi/releases
#
######################################################################
#
########################################################################
#
# Usage() - give some instructions about how to use tool, including
# requirements and supported arguments
#
########################################################################
#

usage()
{
	echo
	echo "Usage: kubectl vtopology <args>"
	echo "  where arg is one of the following:"
	echo "	-e | --hosts"
	echo "	-v | --vms"
	echo "	-n | --networks"
	echo "	-d | --datastores"
	echo "	-k | --k8svms"
	echo "	-a | --all"
	echo "	-h | --help"
	echo
	echo "Advanced options"
	echo "	-pv <pv_id>   - display vSphere storage details about a Persistent Volume"
	echo "	-kn <node_id> - display vSphere VM details about a Kubernetes node"
	echo
	echo "Note this tool requires VMware GO API CLI - govc"
	echo "It can be found here: https://github.com/vmware/govmomi/releases"
	echo
	exit;
}
#
########################################################################
#
# Check dependencies, i.e. govc and kubectl
#
########################################################################
#

check_deps()
{
	echo

	which govc 1>/dev/null 2>&1
	if [ $? -eq 1 ]
	then
		echo "Unable to find govc - ensure it is installed, and added to your PATH"
		echo
		exit;
	fi

	which kubectl 1>/dev/null 2>&1
	if [ $? -eq 1 ]
	then
		echo "Unable to find kubectl - ensure it is installed, and added to your PATH"
		echo
		exit;
	fi
}

#
########################################################################
#
# This kubectl plugin also requires the following environment variables
# to be set in the .bash_profile of the user running the plugin:
#
# GOVC_URL="URL of vCenter Server of ESXi host"
# GOVC_USERNAME='login of valid vCenter or ESXi user'
# GOVC_PASSWORD='Passwd of valid vCenter or ESXi user'
# GOVC_INSECURE=true
#
# TODO: Read these in from a file (securely, without plain text password)
# TODO: Use certs (ugh!)
#
export GOVC_URL="https://vcsa-06-b.rainpole.com"
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='VMware123.'
export GOVC_INSECURE=true
#
#######################################################################
#
# Parse the arguments before doing anything else
#
#######################################################################
#
#######################################################################
#
# Display Everything...
# Get the path to VMs, Networks, Hosts, Datastores and K8s nodes
#
#######################################################################
#
get_all()
{
	echo "*** VMs ..."
	get_vms
	echo
	echo "*** Hosts ..."
	get_hosts
	echo
	echo "*** Datastoress ..."
	get_datastores
	echo
	echo "*** Networks ..."
	get_networks
	echo
	echo "*** Kubernetes VMs ..."
	get_k8svms
	echo
}
#
#######################################################################
#
# Get all VMs
#
#######################################################################
#

get_vms()
{
	echo
	DATACENTER=`govc ls`
	
	for i in ${DATACENTER[@]}; do
	
		if [[ $i =~ vm ]]; then
		govc ls $i
		echo
		fi
	done
}

#
#######################################################################
#
# Get all Kubernetes VMs
#
#######################################################################
#

get_k8svms()
{
	DATACENTER=`govc ls`
	
	for i in ${DATACENTER[@]}; do
	
		if [[ $i =~ vm ]]; then

		K8SVMS=`kubectl get nodes -o wide | awk '{print $7}'`

			for j in ${K8SVMS[@]}; do
				if [[ $j =~ EXTERNAL ]]
				then
					echo
					#no-op
				else
#					echo "DEBUG: EXTERNAL IP OF K8s NODE: $j"
					k8s_node_name=`kubectl get nodes -o wide | grep $j | awk '{print $1}'`
					echo "K8s node name:  ${k8s_node_name}"
					govc vm.info -vm.ip=${j}
					echo
				fi
			done
		fi
	done
}

#
#######################################################################
#
# Get Networks
#
#######################################################################
#

get_networks()
{
	echo
	DATACENTER=`govc ls`
	
	for i in ${DATACENTER[@]}; do
	
		if [[ $i =~ network ]]; then
		govc ls $i
		echo
		fi
	done
}

#
#######################################################################
#
# Get Hosts
#
#######################################################################
#

get_hosts()
{
	echo
	DATACENTER=`govc ls`
	
	for i in ${DATACENTER[@]}; do
	
		if [[ $i =~ host ]]; then
		echo "Cluster ... "
		govc ls $i
		echo
#
# With the cluster, we can now list the hosts and resources
#
		CLUSTER=`govc ls $i`
		echo "Hosts and Resources..."
		govc ls $CLUSTER
		echo
		HOSTSRES=`govc ls $CLUSTER`
			for host in ${HOSTSRES[@]}; do
#			echo "DEBUG: Found $host ..."
			realhost=`echo $host | awk -F/ '{print $5}'`
			if [[ $realhost =~ Resources ]]; then
#				echo "DEBUG: This is resources ... nothing to do"
				echo
			else
				echo "ESXi host $realhost storage info ..."	
				govc host.storage.info -host=${realhost}
				echo
				echo "ESXi host $realhost vswitch info ..."	
				govc host.vswitch.info -host=${realhost}
				echo
			fi
		done
		fi
	done
}

#
#######################################################################
#
# Get Datastores
#
#######################################################################
#

get_datastores()
{
	echo
	DATACENTER=`govc ls`
	
	for i in ${DATACENTER[@]}; do
	
		if [[ $i =~ datastore ]]; then
#		echo "DEBUG: Datastores ... $i"
		echo
		govc ls $i
		echo
		fi
	done
}


#
#######################################################################
#
# Get indivual Kubernetes Node info
#
#######################################################################
#

get_k8s_node_info()
{
	node_id=${1}

#	echo "DEBUG: Kubernetes Node ID is $node_id"

#
#######################################################################
#
# There is no way to verify this is a virtual machine on vSphere
# We will just have to assume that it is
#
#######################################################################
#

	ext_ip=`kubectl get nodes $node_id -o wide --no-headers | awk '{print $7}'`

	echo "K8s node name:  ${node_id}"
	echo "External IP:    ${ext_ip}"
	echo
		govc vm.info -vm.ip=${ext_ip}
	echo
}

#
#######################################################################
#
# Get Persisteny Volume info
#
#######################################################################
#

get_pv_info()
{

#
#######################################################################
#
# First, verify this is a vSphere volume
#
#######################################################################
#
	pvid=${1}

#	echo "DEBUG: PV ID is $pvid"

	is_vsphere=`kubectl describe pv $pvid | grep "    Type" | awk '{print $2}'`

	if [[ $is_vsphere =~ vSphereVolume ]]; then
	pv_volpath=`kubectl describe pv $pvid | grep "    VolumePath:" | awk '{print $3}'`
	pv_datastore=`kubectl describe pv $pvid | grep "    VolumePath:" | awk '{print $2}' | sed 's/[][]//g'`
	else
		echo "Does not appear to be a PV on vSphere storage - $is_vsphere"
		exit
	fi
#		echo "DEBUG: Path to VMDK = $pv_volpath"
#	 	echo "DEBUG: Datastore = $pv_datastore"

#
#######################################################################
#
# OK - its definetely a vSphere volume - lets dump some useful info
#
#######################################################################
#

	echo
	echo "*** PV $pvid is on datastore $pv_datastore"
	echo
	govc datastore.info $pv_datastore

	echo
	echo "*** PV $pvid is VMDK $pv_volpath"
	echo
	govc datastore.disk.info -ds $pv_datastore $pv_volpath

	echo
}

######################################################################
#
# Count arguments. If there are none, throw usage
# Verify that govc and kubectl are in the PATH
# Validate arguments. If unrecognised one, throw usage
#
######################################################################

if [[ $# -eq 0 ]]
then
	usage
else
	check_deps
	case $1 in
		-e|--hosts)
			get_hosts
			;;
		-v|--vms)
			get_vms
			;;
		-n|--networks)
			get_networks
			;;
		-d|--datastores)
			get_datastores
			;;
		-k|--k8svms)
			get_k8svms
			;;
		-a|--all)
			get_all
			;;
		-h|--help)
			usage
			;;
		-pv)
			# Check that PV ID was supplied
			if [[ -z $2 ]]
			then
				echo "No Persistent Volume ID supplied - please provide the PV ID after -pv"
				echo "The PV ID can be found using kubectl get pv"
				echo
				exit
			else
				get_pv_info $2
			fi
			;;
		-kn)
			# Check that Node name was supplied
			if [[ -z $2 ]]
			then
				echo "No Kubernetes Node name supplied - please provide the Node name after -kn"
				echo "The Node name can be found using kubectl get nodes"
				echo
				exit
			else
				get_k8s_node_info $2
			fi
			;;
		*)
			usage
			;;
	esac
fi

######################################################################
