*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Resource           ../resources/records/opportunity_line_item.resource

Variables          ../resources/test_data/cpq-20.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-20 - V8 Standard
    [Tags]    cpq-20    quote    v8-standard
    Test Implementation    ${v8_standard}

CPQ-20 - V8.5 Elevate Ecomm
    [Tags]    cpq-20    quote    v8.5-elevate-ecomm
    Test Implementation    ${v85_elevate_ecomm}

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-20

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

    ValidateQuoteDefaults    ${opp_url}
    ${quote_url}=  CreateQuote    ${opp_url}    ${common_contact_name}

    OpenQLE    ${quote_url}

    # Add bundle to quote lines
    ClickText  Add Products
    AddBundleToQuoteLines   ${data_dict}[bundle][name]    ${data_dict}[bundle][main_product]    ${data_dict}[bundle][add_ons]

    # Verify QLE values
    VerifyText  ${data_dict}[bundle][start_total]  anchor=Quote Total  partial_match=False
    Set QLE Product Quantities    ${data_dict}[bundle]
    Set QLE Auto Product Discounts    ${data_dict}[bundle]
    ClickText  Calculate
    VerifyText  ${data_dict}[bundle][end_total]  anchor=Quote Total  partial_match=False    timeout=10

    # Save and exit QLE
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off
    

    VerifyOpportunityLineItem    ${opp_url}    ${data_dict}[bundle][name]    ${data_dict}[bundle][opportunity_line_item_fields]
    IF    ${data_dict}[bundle][main_product] is not ${NONE}
        VerifyOpportunityLineItem    ${opp_url}    ${data_dict}[bundle][main_product][name]    ${data_dict}[bundle][main_product][opportunity_line_item_fields]
    END
    FOR    ${item}    IN    @{data_dict}[bundle][auto_products]
        VerifyOpportunityLineItem    ${opp_url}    ${item}[name]    ${item}[opportunity_line_item_fields]
    END
    FOR    ${item}    IN    @{data_dict}[bundle][add_ons]
        VerifyOpportunityLineItem    ${opp_url}    ${item}[name]    ${item}[opportunity_line_item_fields]
    END

    # Create non-primary quote
    ${new_quote_url}=  CreateQuote    ${opp_url}    ${common_contact_name}    is_primary=${FALSE}
    SetQuoteAsPrimary  ${new_quote_url}

    # Verify that opportunities line items gets emptied
    OpenRecordsRelatedView  ${opp_url}  OpportunityLineItems
    ReloadRecordListUntilRecordCountIs    Product Code    0

    # Set the original quote back to primary
    SetQuoteAsPrimary  ${quote_url}
    
    # Verify that the line items get re-added to the opp
    OpenRecordsRelatedView  ${opp_url}  OpportunityLineItems
    ReloadRecordListUntilRecordCountIs    Product Code    ${data_dict}[bundle][line_item_count]

    VerifyOpportunityLineItem    ${opp_url}    ${data_dict}[bundle][name]    ${data_dict}[bundle][opportunity_line_item_fields]
    IF    ${data_dict}[bundle][main_product] is not ${NONE}
        VerifyOpportunityLineItem    ${opp_url}    ${data_dict}[bundle][main_product][name]    ${data_dict}[bundle][main_product][opportunity_line_item_fields]
    END
    FOR    ${item}    IN    @{data_dict}[bundle][auto_products]
        VerifyOpportunityLineItem    ${opp_url}    ${item}[name]    ${item}[opportunity_line_item_fields]
    END
    FOR    ${item}    IN    @{data_dict}[bundle][add_ons]
        VerifyOpportunityLineItem    ${opp_url}    ${item}[name]    ${item}[opportunity_line_item_fields]
    END

    # verify opps TCV
    GoTo  ${opp_url}
    VerifyText  Opportunity Information
    VerifyField    TCV    ${data_dict}[opportunity_tcv]