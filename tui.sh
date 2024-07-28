#!/bin/bash

# Defining color codes
RED="\033[1;31m"
GREEN="\033[1;32m"
NC="\033[0m" # No Color

function is_vpa_installed() {
    vpa_crd1=$(kubectl get crd verticalpodautoscalers.autoscaling.k8s.io --ignore-not-found)
    vpa_crd2=$(kubectl get crd verticalpodautoscalercheckpoints.autoscaling.k8s.io --ignore-not-found)

    if [ -n "$vpa_crd1" ] || [ -n "$vpa_crd2" ]; then
        return 0
    else
        return 1
    fi
}

function install_vpa() {
    SCRIPT_ROOT=$(dirname ${BASH_SOURCE})

    if is_vpa_installed; then
        dialog --clear --msgbox "VPA is already installed." 10 50
        return
    fi

    $SCRIPT_ROOT/hack/vpa-up.sh
}

function remove_vpa() {
    SCRIPT_ROOT=$(dirname ${BASH_SOURCE})
    exec 3>&1
    dialog --clear --backtitle "Remove VPA" --yesno "Are you sure you want to remove the VPA?" 0 60 2>&1 1>&3
    exit_status=$?
    exec 3>&-
    if [ $exit_status -eq 0 ]; then
        $SCRIPT_ROOT/hack/vpa-down.sh
    fi
}


function attach_vpa() {
    if ! is_vpa_installed; then
        dialog --clear --msgbox "VPA is not installed. Please install it first." 10 50
        return
    fi
    exec 3>&1
    user_namespaces=$(dialog --inputbox "Please enter the namespaces (comma-separated. Format: namespace1,namespace2): " 10 60 2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    if [ $exit_status != 0 ]; then
        return
    fi

    IFS=',' read -ra namespaces <<< "$user_namespaces"
    for namespace in "${namespaces[@]}"
    do
      deployments=$(kubectl get deployments -n $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
      for deployment in $deployments
      do
        vpaConfig="apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: ${deployment}-vpa
  namespace: $namespace
spec:
  targetRef:
    apiVersion: \"apps/v1\"
    kind: Deployment
    name: $deployment
  updatePolicy:
    updateMode: \"Off\""
        echo "$vpaConfig" > ${deployment}-vpa.yaml
        kubectl apply -f ${deployment}-vpa.yaml -n $namespace
        rm ${deployment}-vpa.yaml
      done
    done
    dialog --clear --msgbox "VPA object is created for the deployments" 10 50
}


function attach_vpa() {
    if ! is_vpa_installed; then
        dialog --clear --msgbox "VPA is not installed. Please install it first." 10 50
        return
    fi

    exec 3>&1
    user_namespaces=$(dialog --inputbox "Please enter the namespaces (comma-separated. Format: namespace1,namespace2): " 10 60 2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    if [ $exit_status != 0 ]; then
        return
    fi

    IFS=',' read -ra namespaces <<< "$user_namespaces"
    for namespace in "${namespaces[@]}"
    do
      deployments=$(kubectl get deployments -n $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
      for deployment in $deployments
      do
        vpaConfig="apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: ${deployment}-vpa
  namespace: $namespace
spec:
  targetRef:
    apiVersion: \"apps/v1\"
    kind: Deployment
    name: $deployment
  updatePolicy:
    updateMode: \"Off\""
        echo "$vpaConfig" > ${deployment}-vpa.yaml
        kubectl apply -f ${deployment}-vpa.yaml -n $namespace
        rm ${deployment}-vpa.yaml
      done
    done
    dialog --clear --msgbox "VPA object is created for the deployments" 10 50

}

function update_vpa_webhook() {
    if ! is_vpa_installed; then
        dialog --clear --msgbox "VPA is not installed. Please install it first." 10 50
        return
    fi
    kubectl patch mutatingwebhookconfigurations vpa-webhook-config --type='json' -p='[{"op": "replace", "path": "/webhooks/0/namespaceSelector", "value": {"matchExpressions":[{"key":"vpa","operator":"NotIn","values":["disabled"]}]}}]'
    kubectl label namespace cattle-fleet-system cattle-impersonation-system cattle-system fleet-system ingress-nginx kube-node-lease kube-public kube-system longhorn-system vpa=disabled
    dialog --clear --msgbox "VPA admission webhook configuration updated to exclude system namespaces." 10 50
}

function get_report() {
    if ! is_vpa_installed; then
        dialog --clear --msgbox "VPA is not installed. Please install it first." 10 50
        return
    fi

    output_file="/output/vpa_recommendations.csv"
    echo "NAMESPACE,VPA_NAME,CONTAINER_NAME,LOWER_BOUND_CPU,LOWER_BOUND_MEM,TARGET_CPU,TARGET_MEM,UNCAPPED_TARGET_CPU,UNCAPPED_TARGET_MEM,UPPER_BOUND_CPU,UPPER_BOUND_MEM" > $output_file
    namespaces=$(kubectl get ns -o json | jq -r '.items[].metadata.name')

    if [ -z "$namespaces" ]; then
        dialog --clear --backtitle "Report Generation" --msgbox "No namespaces found." 0 60
        return
    fi

    clear
    echo -e "${GREEN}Generating report... Please wait.${NC}"

    for namespace in $namespaces; do
        vpas=$(kubectl get vpa -n $namespace -o json | jq -r '.items[].metadata.name')
        if [ -z "$vpas" ]; then
            continue
        fi
        for vpa in $vpas; do
            details=$(kubectl get vpa $vpa -n $namespace -o json)
            if [ $(echo $details | jq '.status.recommendation? | length') -eq 0 ]; then
                dialog --clear --backtitle "Report Generation" --msgbox "Not enough data to generate the report for ${vpa}. Please wait for VPA to gather data." 10 50
                rm $output_file
                return
            fi
            recommendation=$(echo $details | jq -r '.status.recommendation.containerRecommendations[] | [.containerName, .lowerBound.cpu, .lowerBound.memory, .target.cpu, .target.memory, .uncappedTarget.cpu, .uncappedTarget.memory, .upperBound.cpu, .upperBound.memory] | @csv' | awk -v namespace=$namespace -v vpa=$vpa -F',' 'BEGIN{OFS=","} {print namespace, vpa, $1, $2, $3, $4, $5, $6, $7, $8, $9}')
            echo $recommendation >> $output_file
        done
    done

    if [ ! -s "$output_file" ]; then
        dialog --clear --backtitle "Report Generation" --msgbox "No VPA recommendations found." 0 60
        rm $output_file
        return
    fi

    clear
    echo -e "${GREEN}Report saved to $output_file in your current directory. You can check it after exiting the script.${NC}"
    read -n 1 -s -r -p "Press any key to continue..."
}

while true; do
    exec 3>&1
    selection=$(dialog --clear --backtitle "VPA Operations" --no-collapse --cancel-label "Exit" --menu "Please choose:" 0 60 5 \
    "1" "Install VPA" \
    "2" "Remove VPA" \
    "3" "Create VPA object for deployments" \
    "4" "Update VPA to exclude system namespaces" \
    "5" "Get report" 2>&1 1>&3)
    exit_status=$?
    exec 3>&-

    case $exit_status in
        1)  # User selected "Exit"
            clear
            echo -e "${RED}Program terminated.${NC}"
            exit
            ;;
        255)  # User pressed ESC
            clear
            echo -e "${RED}Program aborted.${NC}" >&2
            exit 1
            ;;
    esac

    case $selection in
        0 )
            echo -e "${RED}Program terminated.${NC}"
            ;;
        1 )
            install_vpa
            ;;
        2 )
            remove_vpa
            ;;
        3 )
            attach_vpa
            ;;
        4 )
            update_vpa_webhook
            ;;
        5 )
            get_report
            ;;
    esac
done

