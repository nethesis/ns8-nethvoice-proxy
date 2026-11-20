*** Settings ***
Library   SSHLibrary
Library    Collections
Resource  ../api.resource

*** Test Cases ***
Facts are returned
    ${facts} =    Run task    module/${module_id}/get-facts    {}
    ${config} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${facts['nethvoice_proxy_alerts_enabled']}    ${config['alerts_enabled']}
    Should Be Equal    ${facts['nethvoice_proxy_lets_encrypt']}    ${config['lets_encrypt']}
    Length Should Be    ${config['local_networks']}    ${facts['nethvoice_proxy_local_networks_count']}

Route counts match the route lists
    ${facts} =    Run task    module/${module_id}/get-facts    {}
    ${routes} =    Run task    module/${module_id}/list-routes    {}
    ${trunks} =    Run task    module/${module_id}/list-trunks    {}
    Length Should Be    ${routes}    ${facts['nethvoice_proxy_domain_routes_count']}
    Length Should Be    ${trunks}    ${facts['nethvoice_proxy_trunk_routes_count']}
