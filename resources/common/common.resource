*** Settings    
Library    QForce
Library    DateTime
Library    ../python/ImpersonationUtils.py
Library    ../python/GlobalSearch.py
Resource   ../common/salesforce.resource
Resource   ../records/account.resource
Resource   ../records/contact.resource

*** Variables ***
${common_account_id}=    ${NONE}  # 0012300000jzspoAAA
${common_contact_name}=    ${NONE}  # CRT-CPQ Common-User-170423

*** Keywords ***
Check Daily Account
    [Documentation]    Creates a daily common account for CPQ test cases
    ...    This account will be used for all test cases that do not require account creation
    IF    $common_account_id is not ${NONE}
        Return From Keyword
    END

    ${today}=    GetCurrentDate    result_format=%y%m%d
    ${acc_name}=    SetVariable    CRT-Daily-Account-${today}
    ${f_name}=    SetVariable    CRT-Daily
    ${l_name}=    SetVariable    User-${today}

    # Search accounts with an url, the top bar global search is quite flaky
    # https://sfdad4tec.medium.com/salesforce-lightning-global-search-in-chrome-url-address-bar-8aebd3175ef9
    ${b64_query}=    GetSearchQuery    ${acc_name}    Account
    GoTo    url=${login_url}/one/one.app#${b64_query}
    VerifyText    Result
    
    ${daily_acc_exists}=    IsElement    xpath=//a[@title="${acc_name}"]    timeout=10s
    IF    ${daily_acc_exists}
        ${acc_id}=    GetAttribute    locator=(//a[@title="${acc_name}"])[1]    attribute=data-recordid
        SetGlobalVariable    ${common_account_id}    ${acc_id}
        SetGlobalVariable    ${common_contact_name}    ${f_name} ${l_name}
        Return From Keyword
    END

    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

    ${acc_url}=    CreateAccount    ${acc_name}
    ${contact_url}=    CreateContact    ${acc_url}    ${f_name}    ${l_name}
    CreateAppToAccount    ${acc_url}    CRT-APP-${today}    ${f_name} ${l_name}

    ${acc_id}=    ResolveRecordIdFromUrl    ${acc_url}    Account
    ${contact_id}=    ResolveRecordIdFromUrl    ${contact_url}    Contact

    SetGlobalVariable    ${common_account_id}    ${acc_id}
    SetGlobalVariable    ${common_contact_name}    ${f_name} ${l_name}
    