*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py
Library            ../resources/python/DateUtils.py

Resource           ../resources/common/variables.resource
Resource           ../resources/common/error.resource
Resource           ../resources/records/account.resource
Resource           ../resources/common/salesforce.resource

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-273
    [Tags]    no-pricebook    account    msa    cpq-273
    Test Implementation

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    ${record_prefix}=    SetRecordPrefix    CPQ-273

Test Implementation
    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

    ${acc_url}=    CreateAccount    ${record_prefix}-Acc

    # Fields should be empty after creation
    VerifyField    Payment Terms     ${EMPTY}
    VerifyField    MSA in place      ${EMPTY}
    VerifyField    MSA Date          ${EMPTY}

    # When not in 'edit mode' of a record all editable fields will have "Edit [field name]" tooltip texts
    # Check that there is no such fields for the specced fields
    VerifyNoText    Edit Payment Terms
    VerifyNoText    Edit MSA in place
    VerifyNoText    Edit MSA Date
    
    
    ImpersonateWithUid    ${deal_desk_user}
    CloseAllSalesConsoleTabs

    GoTo    ${acc_url}
    # Fields should be editable with dd user
    VerifyText    Edit MSA Date
    ClickText    Edit MSA Date
    VerifyNoText    Edit MSA Date
    
    # Set the field contents and save
    ${zero_strip_char}=  GetDateZeroStripChar
    ${date}=    GetCurrentDate    result_format=%${zero_strip_char}m/%${zero_strip_char}d/%Y
    TypeText    MSA Date    ${date}
    PickList    Payment Terms    Net 30
    PickList    MSA in place    Yes

    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit MSA Date
    ...    click_kwargs=${click_kwargs}

    # Confirm that the fields were set
    VerifyField    MSA Date    ${date}
    VerifyField    Payment Terms    Net 30
    VerifyField    MSA in place    Yes