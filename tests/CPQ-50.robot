*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py
Library            ../resources/python/DateUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-50.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers


*** Test Cases ***
CPQ-50 - V8 Standard
    [Tags]    cpq-50    quote    v8-standard
    Test Implementation    ${v8_standard}

CPQ-50 - V8.5 Elevate Ecomm
    [Tags]    cpq-50    quote    v8.5-elevate-ecomm
    Test Implementation    ${v85_elevate_ecomm} 

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-50

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

    ClickText  Add Products
    AddBundleToQuoteLines   ${data_dict}[bundle][name]    ${data_dict}[bundle][main_product]    ${data_dict}[bundle][add_ons]
    Set QLE Product Quantities    ${data_dict}[bundle]

    # base line for price calculations
    Calculate And Verify Cells    ${data_dict}[list_unit_prices]    ${data_dict}[start]

    # test price scaling with subscription term
    TypeText    Subscription Term    18
    Calculate And Verify Cells       ${data_dict}[list_unit_prices]    ${data_dict}[subscription_term]

    # test price scaling with end date
    # years, months, days. 1 day short of two years
    ${end_date}=    RelativeDate    2    0    -1
    TypeText    End Date    ${end_date}    partial_match=False
    Calculate And Verify Cells       ${data_dict}[list_unit_prices]    ${data_dict}[end_date]

    # clear fields and confirm base line
    TypeText    Subscription Term    12
    TypeText    End Date    ${EMPTY}    partial_match=False
    Calculate And Verify Cells    ${data_dict}[list_unit_prices]    ${data_dict}[start]

Calculate And Verify Cells
    [Arguments]    ${list_unit_prices}    ${net_totals}
    ClickText    Calculate
    VerifyText    ${net_totals}[0]    timeout=10
    FOR    ${index}    ${item}    IN ENUMERATE    @{list_unit_prices}
        VerifyTableCell    List Unit Price    ${index+2}    ${item}
    END
    FOR    ${index}    ${item}    IN ENUMERATE    @{net_totals}
        VerifyTableCell    Net Total    ${index+2}    ${item}
    END