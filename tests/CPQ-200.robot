*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-200.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-200 - V8 Standard
    [Tags]    cpq-200    quote    v8-standard
    Test Implementation    ${v8_standard}

CPQ-200 - V8.5 Elevate Ecomm
    [Tags]    cpq-200    quote    v8.5-elevate-ecomm
    Test Implementation    ${v85_elevate_ecomm} 

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-200

Test Implementation
    [Arguments]    ${data_dict}
    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

    ${opp_url}=    CreateOpportunity    
    ...  ${common_account_id}
    ...  contact_name=${common_contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=${data_dict}[potential_plan]
    ...  price_book=${data_dict}[price_book]
    ${quote_url}=  CreateQuote    ${opp_url}    ${common_contact_name}

    OpenQLE    ${quote_url}

    # Open QLE product configuration view
    ClickText  Add Products
    VerifyText  Product Selection

    ClickItem  checkbox  anchor=${data_dict}[bundle]
    ClickText    Select    partial_match=False

    VerifyText  Configure Products
    VerifyAll    ${data_dict}[products]