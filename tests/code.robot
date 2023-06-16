*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py
Library            ../resources/python/DateUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-39.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-39 - V8 Standard
    [Tags]    cpq-39    quote    v8-standard
    Test Implementation    ${v8_standard}

CPQ-39 - V8.5 Elevate Ecomm
    [Tags]    cpq-39    quote    v8.5-elevate-ecomm
    Test Implementation    ${v85_elevate_ecomm}

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    #CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-39

Test Implementation
    [Arguments]    ${data_dict}
    # Live Editor setup
    Check Daily Account
    ${data_dict}=    Set Variable    ${v8_standard}

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
    AddBundleToQuoteLines   ${data_dict}[bundle][name]    ${data_dict}[bundle][main_product]    ${data_dict}[bundle][add_ons]
    ClickText    Calculate
    VerifyText    ${data_dict}[initial_verify_calc]
    FOR    ${index}    ${item}    IN ENUMERATE    @{data_dict}[list_unit_prices]
        VerifyTableCell    List Unit Price    ${index+2}    ${item}
    END

    Set Quantities And Verify Cells    ${data_dict}[first]
    Set Quantities And Verify Cells    ${data_dict}[second]

Set Quantities And Verify Cells
    [Arguments]    ${data_dict}
    FOR    ${index}    ${item}    IN ENUMERATE    @{data_dict}[quantities]
        TypeTable    Quantity    ${index+2}    ${item}
    END
    ClickText    Calculate
    VerifyText    ${data_dict}[net_totals][0]    timeout=10
    FOR    ${index}    ${item}    IN ENUMERATE    @{data_dict}[net_totals]
        VerifyTableCell    Net Total    ${index+2}    ${item}
    END