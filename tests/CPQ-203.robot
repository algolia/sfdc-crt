*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-203.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-203 - V8 Standard
    [Tags]    cpq-203    quote    v8-standard
    Test Implementation    ${v8_standard}

CPQ-203 - V8.5 Elevate Ecomm
    [Tags]    cpq-203    quote    v8.5-elevate-ecomm
    Test Implementation    ${v85_elevate_ecomm} 

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-203

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
    AddBundleToQuoteLines   ${data_dict}[bundle][name]    ${data_dict}[bundle][main_product]    services=${data_dict}[bundle][services]
    Set QLE Product Quantities    ${data_dict}[bundle]

    FOR    ${key}    ${value}    IN    &{data_dict}[item_editable]
        VerifyQLEAdditionalDiscEditable    ${key}    ${value}
    END

    
    IF    ${data_dict}[common_additional_discount]
        TypeText    Additional Disc. (%)    50
    ELSE
        FOR    ${index}    ${item}    IN ENUMERATE   @{data_dict}[discount_items]
           TypeTable    Additional Disc.    ${index+2}     50
        END
    END
    ClickText    Calculate
    ${totals}=    SetVariable    ${data_dict}[add_disc_50]
    VerifyText    ${totals}[calc_verify]    timeout=10
    VerifyQLECells    ${totals}[customer_totals]    2    Customer Total
    
    # zero the additional discounts
    IF    ${data_dict}[common_additional_discount]
        TypeText    Additional Disc. (%)    0
    ELSE
        FOR    ${index}    ${item}    IN ENUMERATE   @{data_dict}[discount_items]
           TypeTable    Additional Disc.    ${index+2}     0
        END
    END
    TypeText    Partner Discount    20
    ClickText    Calculate

    ${totals}=    SetVariable    ${data_dict}[part_disc_20]
    VerifyText    ${totals}[calc_verify]    timeout=10
    VerifyQLECells    ${totals}[customer_totals]    2    Customer Total
    VerifyQLECells    ${totals}[net_totals]    2    Net Total
    
    TypeText    Partner Discount    0
    ClickText   Calculate
    ${totals}=    SetVariable    ${data_dict}[discs_0]
    VerifyText    ${totals}[calc_verify]    timeout=10
    VerifyQLECells    ${totals}[customer_totals]    2    Customer Total
    VerifyQLECells    ${totals}[net_totals]    2    Net Total
    

    TypeText    Target Customer Amount    28000    timeout=60
    ClickText    Calculate
    VerifyText    ${data_dict}[additional_row_discount_percent]    timeout=10
    VerifyTableCell    Additional Disc.    2    ${data_dict}[additional_row_discount_percent]
    VerifyText    ${data_dict}[additional_total_discount_percent]    anchor=Additional Discount Amount (%)
    VerifyText  USD 28,000.00  anchor=Quote Total  partial_match=False

    # Clear the discount values, calculate and quick save
    TypeText    Target Customer Amount    ${SPACE}
    FOR    ${item}    IN    @{data_dict}[additional_discount_rows]
        TypeTable    Additional Disc.    ${item}    0
    END
    Sleep    5
    ClickText    Calculate
    Sleep    5

    ClickText    Quick Save
    # Quick saving takes quite a bit of time and we want to be sure that the loading overlay does not block any actions
    ${spinner}=    SetVariable    ${TRUE}
    WHILE    ${spinner}
        ${spinner}=    IsItem  mask  tag=div  element_type=item  timeout=3
        IF    ${spinner}
            Sleep   1
        END
    END

    VerifyNoText    ${data_dict}[additional_row_discount_percent]    timeout=10
    VerifyTableCell    Additional Disc.    2    ${EMPTY}

    # Set negative discount, calculate and try to save the quote
    TypeTable    Additional Disc.    2    -100
    Sleep    2
    ClickText    Calculate
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=${data_dict}[error_message]
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off
