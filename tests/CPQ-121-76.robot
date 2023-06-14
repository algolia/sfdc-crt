*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-121-76.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Variables ***
# these variables are used to check if pre-requisite tcs have passed
# will be set as the very last steps of the corresponding test implementation kws
# each set of pricebook variations will require a new ${x_121_quote_url} variable
${v8_standard_121_quote_url}=    ${NONE}
${v85_elevate_ecomm_121_quote_url}=    ${NONE}

*** Test Cases ***
CPQ-121 - V8 Standard
    [Tags]    cpq-121    quote    order    contract    amendment    v8-standard
    ${quote_url}=  Test Implementation 121    ${v8_standard}
    Set Suite Variable  ${v8_standard_121_quote_url}    ${quote_url}

CPQ-76 - V8 Standard  # whitespace has switched to conga documents
    [Tags]    cpq-76    quote    order    contract    amendment    deprecated    v8-standard
    Test Implementation 76    ${v8_standard_121_quote_url}

CPQ-121 - V8.5 Elevate Ecomm
    [Tags]    cpq-121    quote    order    contract    amendment    v8.5-elevate-ecomm
    ${quote_url}=  Test Implementation 121    ${v85_elevate_ecomm}
    Set Suite Variable  ${v85_elevate_ecomm_121_quote_url}    ${quote_url}
CPQ-76 - V8.5 Elevate Ecomm  # whitespace has switched to conga documents
    [Tags]    cpq-76    quote    order    contract    amendment    deprecated    v8.5-elevate-ecomm
    Test Implementation 76    ${v85_elevate_ecomm_121_quote_url}

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-121

Test Implementation 121
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

    ClickText  Add Products
    AddBundleToQuoteLines   ${data_dict}[bundle][name]    ${data_dict}[bundle][main_product]
    Set QLE Product Quantities    ${data_dict}[bundle]
    Set QLE Auto Product Discounts    ${data_dict}[bundle]
    ClickText    Calculate
    VerifyText    ${data_dict}[quote_total]    anchor=Quote Total  partial_match=False    timeout=10

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

    ClickText    Preview Approval
    ClickText    Submit for Approval  timeout=120
    VerifyText    You are required to populate the Docusign Signer, Bill To and Business Contacts at this time.

    ClickText    Return to Quote

    VerifyText    Edit Lines
    ClickText    Edit DocuSign Signer
    VerifyNoText    Edit DocuSign Signer

    Custom Combobox    DocuSign Signer    ${common_contact_name}
    Custom Combobox    Bill To Contact    ${common_contact_name}
    Custom Combobox    Ship To Contact    ${common_contact_name}

    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit DocuSign Signer
    ...    click_kwargs=${click_kwargs}

    ClickText    Preview Approval
    ClickText    Submit for Approval  timeout=120
    VerifyText    Quote Details    timeout=120

    [Return]    ${quote_url}

Test Implementation 76
    [Arguments]    ${quote_url}=${NONE}
    IF    $quote_url is ${NONE}
        Fail     Pre-requisite test case CPQ-121 has not been executed successfully before running this test case!"
    END
    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs
    GoTo    ${quote_url}
    ClickText    Show more actions
    ClickText    Generate Document
    VerifyText    Document Options
    VerifyNoText    Output Format


    ImpersonateWithUid    ${deal_desk_user}
    CloseAllSalesConsoleTabs
    GoTo    ${quote_url}
    ClickText    Show more actions
    ClickText    Generate Document
    VerifyText    Document Options
    VerifyText    Output Format
    ${output_formats}=    GetDropDownValues    Output Format

    ShouldContain    ${output_formats}    PDF
    ShouldContain    ${output_formats}    MS Word


    ImpersonateWithUid    ${legal_user}
    CloseAllSalesConsoleTabs
    GoTo    ${quote_url}
    ClickText    Show more actions
    ClickText    Generate Document
    VerifyText    Document Options
    VerifyText    Output Format
    ${output_formats}=    GetDropDownValues    Output Format

    ShouldContain    ${output_formats}    PDF
    ShouldContain    ${output_formats}    MS Word
