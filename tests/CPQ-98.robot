*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-98.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-98 - V8 Standard
    [Tags]    cpq-98    quote    v8-standard
    Test Implementation    ${v8_standard}

CPQ-98 - V8.5 Elevate Ecomm
    [Tags]    cpq-98    quote    v8.5-elevate-ecomm
    Test Implementation    ${v85_elevate_ecomm} 


*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-98

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
    AddBundleToQuoteLines   ${data_dict}[bundle][name]    ${data_dict}[bundle][main_product]
    Set QLE Product Quantities    ${data_dict}[bundle]
    Set QLE Auto Product Discounts    ${data_dict}[bundle]

    Sleep    2
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off
    # Exited QLE

    # Verify the discount schedule
    VerifyQuoteLineItem    ${quote_url}    ${data_dict}[verify_ql_item]    ${data_dict}[discount_schedule]

    # Change quantities
    OpenQLE    ${quote_url}
    Set QLE Product Quantities    ${data_dict}[bundle2]
    Set QLE Auto Product Discounts    ${data_dict}[bundle2]
    ClickText    Calculate
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

    # Verify the discount schedule
    #    This schedule should change according to the spec, but it doesn't at the moment
    VerifyQuoteLineItem    ${quote_url}    ${data_dict}[verify_ql_item]    ${data_dict}[discount_schedule2]
