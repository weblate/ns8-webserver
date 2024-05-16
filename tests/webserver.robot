*** Settings ***
Library    SSHLibrary
Resource    api.resource

*** Keywords ***
Retry test
    [Arguments]    ${keyword}
    Wait Until Keyword Succeeds    60 seconds    1 second    ${keyword}

Backend URL is reachable
    ${rc} =    Execute Command    curl -f ${backend_url}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0


*** Test Cases ***
Check if mattermost is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if mattermost can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"path":"/sftpgo","http2https": true,"sftp_tcp_port": 2092,"sftpgo_service": true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Retrieve mattermost backend URL
    # Assuming the test is running on a single node cluster
    ${response} =    Run task     module/traefik1/get-route    {"instance":"${module_id}"}
    Set Suite Variable    ${backend_url}    ${response['url']}

Check if mattermost works as expected
    Retry test    Backend URL is reachable

Check if mattermost is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0