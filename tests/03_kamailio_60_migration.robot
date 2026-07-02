*** Settings ***
Library   SSHLibrary

*** Test Cases ***
Kamailio reports the migrated 6.0 version
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamailio -v 2>&1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Start With    ${output}    "version: kamailio 6.0"

Kamailio htable schema uses 6.0 column widths
    ${key_name_length} =    Query htable column length    key_name
    ${key_value_length} =    Query htable column length    key_value
    Should Be Equal As Integers    ${key_name_length}    256
    Should Be Equal As Integers    ${key_value_length}    512

Kamailio 6.0 htable schema migration is idempotent
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgres psql -v ON_ERROR_STOP=1 -qU postgres kamailio -c "ALTER TABLE public.htable ALTER COLUMN key_name TYPE character varying(256), ALTER COLUMN key_value TYPE character varying(512);"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${key_name_length} =    Query htable column length    key_name
    ${key_value_length} =    Query htable column length    key_value
    Should Be Equal As Integers    ${key_name_length}    256
    Should Be Equal As Integers    ${key_value_length}    512

*** Keywords ***
Query htable column length
    [Arguments]    ${column}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgres psql -tAU postgres kamailio -c "SELECT character_maximum_length FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'htable' AND column_name = '${column}';"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${length} =    Evaluate    int('''${output}'''.strip())
    RETURN    ${length}
