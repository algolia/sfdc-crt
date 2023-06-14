*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py
Library            ../resources/python/DateUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-73.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
Standard Quote Doc V2 - V8 Standard
    [Tags]    v8-standard    quote    document-template    standard-document
    Test Implementation    ${v8_standard}[standard_doc]

Standard PAB Quote Doc V2 - V8 Standard
    [Tags]    v8-standard    quote    document-template    pab-document
    Test Implementation    ${v8_standard}[standard_pab_doc]

Standard Quote Doc V2 - V8.5 Elevate Ecomm  # uses conga service order in whitespace
    [Tags]    v8.5-elevate-ecomm    quote    document-template    standard-document    deprecated
    Test Implementation    ${v85_elevate_ecomm}[standard_doc]

# Elevate Ecomm does not have Premium Adoption Bundle

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-73

    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

Test Implementation
    [Arguments]    ${data_dict}

    ${opp_url}=    CreateOpportunity    
    ...  ${common_account_id}
    ...  contact_name=${common_contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=${data_dict}[potential_plan]
    ...  price_book=${data_dict}[price_book]
    
    ${quote_url}=  CreateQuote    ${opp_url}    ${common_contact_name}

    OpenQLE    ${quote_url}

    ClickText  Add Products
    AddBundleToQuoteLines   ${data_dict}[bundle][name]    ${data_dict}[bundle][main_product]
    Set QLE Product Quantities    ${data_dict}[bundle]
    Set QLE Auto Product Discounts    ${data_dict}[bundle]
    
    TypeText    Subscription Term    ${data_dict}[bundle][subscription_term]
    ClickText    Calculate
    
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off
    # Exited from QLE

    # Open quote document preview
    ClickText    Preview Document
    VerifyText  Quote Preview    timeout=180
    # Close the actual document preview
    ClickElement    xpath=//div[@class="sbDialogCon"]//button

    VerifyText    Document Options
    VerifyInputValue    Template    ${data_dict}[template_name]
    # Verify that the Template can not be changed
    ${is_disabled}=    GetAttribute
    ...    documentModel.templateName
    ...    ng-disabled
    ...    anchor=Template
    ...    tag=input

    ShouldBeEqualAsStrings    ${is_disabled}    true
