*** Settings ***
Library    SSHLibrary
Resource    ./api.resource

*** Test Cases ***
Gather system information
    ${output} =    Execute Command    ip -j addr show dev wg0 | jq -r .[].addr_info[].local
    Set Global Variable    ${service_ip}    ${output}
    ${output} =    Execute Command    ip -j addr show dev eth0 | jq -r '.[].addr_info[] | select(.family=="inet") | .local' | head -n 1
    Set Global Variable    ${local_ip}    ${output}
