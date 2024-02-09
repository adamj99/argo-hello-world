#!/bin/bash
set -o nounset # Treat unset variables as an error
export K3D_FIX_DNS=1
#-----------------------------------------------------
# FUNCTIONS
#-----------------------------------------------------
# function for yes or no prompts when script requires user interaction
yes_no() {
    while true; do
        read -p "$1 (yes/no): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}
# function to check whether docker is running and k3d is installed
requirement_check() {
    # Check prerequisites: docker, k3d, helm, and kubectl
    prerequisites=(docker k3d helm kubectl)

    for app in ${prerequisites[@]}; do
        if ! hash $app 2>/dev/null; then
                echo >&2 "This script requires $app but it's not installed. Please install it and try again."
            exit 1
        fi
    done

    cluster_setup
}

# cluster_setup is a function to create a k3d cluster named "hello-world"
cluster_setup(){
    # Define local variables
    local cluster_name="hello-world"
    local configfile="./config/k3d.yaml"
    
    # Check if the cluster is already running
    if k3d cluster list | grep -qw "${cluster_name}"; then
        echo "Cluster "${cluster_name}" is already running"
        return 
    fi

    # Check if the config file exists
    if [[ ! -f ${configfile} ]]; then
        echo "Error: Configuration file does not exist."
        # Return with error code 1 if config file does not exist
        return 1
    fi

    # Create the cluster 
    echo "Creating "${cluster_name}" k3d cluster"
    # If the cluster creation fails, print an error message and return with error code 1
    if ! k3d cluster create --config "${configfile}"; then
        echo "Error: Failed to create "${cluster_name}" k3d cluster."
        return 1
    fi
    # Confirm current kube context before we proceed with any installs
    current_context=$(kubectl config current-context 2>/dev/null)
    if [ -z "$current_context" ]; then
        echo "Kubernetes context is not set."
        exit 1
    else
        echo "Current Kubernetes context is: $current_context"
        if yes_no "Proceed with installation of ArgoCD?"; then
          echo "installing argo........."
          install_argo
        else 
          echo "exiting"
          exit 1
        fi
    fi
}

install_argo(){
    local namespace="argocd"
    helm dep update charts/argo-cd/
    helm install argo-cd charts/argo-cd --create-namespace --namespace "${namespace}"
    kubectl apply -f argocd-applications.yml
}

# Execute the function to check all requirements
requirement_check
