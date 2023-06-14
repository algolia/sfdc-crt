*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-204.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-204 - V8 Standard
    [Tags]    cpq-204    quote    v8-standard    deprecated
    Test Implementation    ${v8_standard}

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-204

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

    # Set multiple infra locations to a quote
    ${infrastructure_locations}=    CreateList    US-East    US-West
    ${quote_url}=  CreateQuote    ${opp_url}    ${common_contact_name}    infrastructure_locations=${infrastructure_locations}

    OpenQLE    ${quote_url}

    ClickText  Add Products
    VerifyText  Product Selection

    # Add bundle with single DSN product
    ClickItem  checkbox  anchor=${data_dict}[bundle][name]
    ClickText    Select    partial_match=False
    VerifyText  Configure Products

    IF    ${data_dict}[bundle][main_product] is not ${NONE}
        ClickItem    radioContainer   anchor=${data_dict}[bundle][main_product][name]
    END
    
    # Elevate Ecomm does not have DSN to select!
    ClickItem  checkbox  anchor=DSN
    Sleep    1
    ClickText  Save

    UseModal    on

    # Warning does not appear anymore!
    VerifyText    You have more Infrastructure Locations selected than Quantity of DSN. Please attempt to upsell additional DSN.    timeout=60
    
    # Couldn't set quantities from configuration page
    # Click Continue -> move to QLE
    # Set quantities in QLE
    # Click Reconfigure Line to get back to configuration page
    # Clicking Save does no longer show alert modal
    ClickText    Continue    partial_match=False
    Use Modal    off
    # Will land on the 'main' QLE page

    # Set the product quantities
    VerifyText  Add Products
    Set QLE Product Quantities    ${data_dict}[bundle]
    Set QLE Auto Product Discounts    ${data_dict}[bundle]
    TypeTable    Quantity  ${data_dict}[dsn_row]  2  # DSN
    ClickText  Calculate

    # Check that configuration page no longer alerts about DSNs
    ClickItem    Reconfigure Line
    VerifyNoText    Add Products
    ClickText  Save
    ${on_qle_page}    IsText  Add Products  timeout=30
    IF  ${on_qle_page}
        NoOperation
    ELSE
        ClickText  Save
        VerifyText  Add Products
    END

    # Confirm prices
    VerifyQLECells    ${data_dict}[net_totals]    2    Net Total
    VerifyQLECells    ${data_dict}[list_unit_prices]    2    List Unit Prices