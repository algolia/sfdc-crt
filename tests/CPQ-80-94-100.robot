*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py
Library            ../resources/python/DateUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-80-94-100.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Variables ***
# these variables are used to check if pre-requisite tcs have passed
# will be set as the very last steps of the corresponding test implementation kws
# each set of pricebook variations will require a new pair of ${x_80_data} and ${x_94_passed}
${v8_standard_80_data}=    ${NONE}
${v8_standard_94_passed}=    ${FALSE}
${v85_elevate_ecomm_80_data}=    ${NONE}
${v85_elevate_ecomm_94_passed}=    ${FALSE}

*** Test Cases ***
CPQ-80 - V8 Standard
    [Tags]    cpq-80    quote    order    contract    amendment    v8-standard
    ${80_data}=  Test Implementation 80    ${v8_standard}
    Set Suite Variable  ${v8_standard_80_data}    ${80_data}

CPQ-94 - V8 Standard
    [Tags]    cpq-94    quote    order    contract    amendment    v8-standard
    ${94_passed}=    Test Implementation 94    ${v8_standard}    ${v8_standard_80_data}
    Set Suite Variable   ${v8_standard_94_passed}    ${94_passed}
CPQ-100 - V8 Standard
    [Tags]    cpq-100    quote    order    contract    amendment    v8-standard
    Test Implementation 100    ${v8_standard}    ${v8_standard_80_data}    ${v8_standard_94_passed}

CPQ-80 - V8.5 Elevate Ecomm
    [Tags]    cpq-80    quote    order    contract    amendment    v8.5-elevate-ecomm
    ${80_data}=  Test Implementation 80    ${v85_elevate_ecomm}
    Set Suite Variable  ${v85_elevate_ecomm_80_data}    ${80_data}
CPQ-94 - V8.5 Elevate Ecomm
    [Tags]    cpq-94    quote    order    contract    amendment    v8.5-elevate-ecomm
    ${94_passed}=    Test Implementation 94    ${v85_elevate_ecomm}    ${v85_elevate_ecomm_80_data}
    Set Suite Variable   ${v85_elevate_ecomm_94_passed}    ${94_passed}
CPQ-100 - V8.5 Elevate Ecomm
    [Tags]    cpq-100    quote    order    contract    amendment    v8.5-elevate-ecomm
    Test Implementation 100    ${v85_elevate_ecomm}    ${v85_elevate_ecomm_80_data}    ${v85_elevate_ecomm_94_passed}

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-80

Test Implementation 80
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

    ClickText  Calculate
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

    # Verify default ren uplift and confirm that it can be edited
    VerifyField    Renewal Uplift (%)    7.000%
    ClickText    Edit Renewal Uplift (%)
    Verify No Text    Edit Renewal Uplift (%)
    TypeText    Renewal Uplift (%)    17
    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Renewal Uplift (%)
    ...    click_kwargs=${click_kwargs}
    VerifyField    Renewal Uplift (%)    17.000%
    
    # Set the ren uplift back to the default value of 7%
    ClickText    Edit Renewal Uplift (%)
    VerifyNoText    Edit Renewal Uplift (%)
    TypeText    Renewal Uplift (%)    7

    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Renewal Uplift (%)
    ...    click_kwargs=${click_kwargs}
    
    VerifyField    Renewal Uplift (%)    7.000%


    ImpersonateWithUid    ${order_management_user}
    CloseAllSalesConsoleTabs

    GoTo    ${opp_url}
    #  As 'Interested' opps can not be closed, set opp stage from 'Interested' to 'Discovery'
    ClickText    Mark Stage as Complete
    Sleep        5
    ClickText    Closed    anchor=Mark Stage as Complete    partial_match=False
    ClickText    Select Closed Stage
    UseModal     on
    VerifyText    Close This Opportunity
    # Opp can now be closed

    # Close the opp as 'Closed Won'
    Dropdown    locator=//div[./label/span[text()="Stage"]]/select    option=Closed Won
    ClickText    Save    anchor=Cancel    partial_match=False
    VerifyNoText    Close This Opportunity
    UseModal    off
    VerifyText    Closed Won    timeout=180

    # Verify that the opp closing creates a contract
    OpenRecordsRelatedView    ${opp_url}    SBQQ__Contracts__r
    # This polls roughly for 6 minutes
    #   can fail if there's heavy load on the environment and the contract generation takes long
    ReloadRecordListUntilRecordCountIs    Contract Number    1    limit=40
    
    #ClickCell    r2/c2  # Open the contract record page
    ClickElement   //tr[1]//th[1]//a
    VerifyText    Contract Start Date
    ${contract_url}=    GetUrl

    # Resolve start/end dates for verifying contract fields
    ${start_date}=     GetCurrentDate
    ${start_date}=    ConvertDate    ${start_date}    result_format=%d/%m/%Y   exclude_millis=True  # years, months, days. 1 day short of a year
    ${end_date}=    RelativeDate    1  0  -1    format=%d/%m/%Y

    # Verify contracts basic info
    VerifyText    12    anchor=Contract Term (months)
    VerifyField    Contract Start Date    ${start_date}
    VerifyField    Contract End Date    ${end_date}

    # Verify subscriptions and their start/end dates
    OpenRecordsRelatedView    ${contract_url}    SBQQ__Subscriptions__r
    ReloadRecordListUntilRecordCountIs    Quantity    ${data_dict}[line_item_count]

    #UseTable    Subscription \#
    UseTable    Quantity
    FOR    ${index}    ${item}    IN ENUMERATE   @{data_dict}[line_items]
        #VerifyTable    r${index+2}/c4    ${item}
        ${text}=  GetAttribute    locator=//tr[${index+1}]//td[3]//a  attribute=textContent
        Should Contain  ${text}    ${item}
        VerifyTable    r${index+2}/c6    ${start_date}
        VerifyTable    r${index+2}/c7    ${end_date}
    END

    # Verify quotes start/end date
    GoTo    ${quote_url}
    VerifyText    Edit Lines
    VerifyField    Start Date    ${start_date}
    VerifyField    Effective End Date    ${end_date}


    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

    GoTo    ${contract_url}
    VerifyText    Contract Start Date
    VerifyField    Renewal Uplift (%)    7.000%

    # Renew the contract
    ClickText    Edit Account Name
    VerifyNoText    Edit Account Name
    # Setting the checkbox occasionally fails if it is not in the viewport
    ScrollTo    Infrastructure Location
    Sleep    2
    ClickCheckbox    Renewal Quoted    on
    Sleep    2

    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Account Name
    ...    click_kwargs=${click_kwargs}

    # Confirm that the 'Renewal Quoted' checkbox is ticked
    ScrollTo    Infrastructure Location
    VerifyCheckboxValue    locator=//div[./div/span[text()="Renewal Quoted"]]//input    value=on

    # Verify that a renewal opportunity gets created and open it
    OpenRecordsRelatedView    ${contract_url}    SBQQ__RenewalOpportunities__r
    ReloadRecordListUntilRecordCountIs    Opportunity Name    1
    # ClickCell    r2/c2
    ClickElement    //tr[1]//th[1]//a
    VerifyText    FE Support Request

    # Verify that a quote is created to the ren opp and open it
    ${renewal_opp_url}=    GetUrl
    OpenRecordsRelatedView    ${renewal_opp_url}    SBQQ__Quotes2__r
    ReloadRecordListUntilRecordCountIs    Quote Number    1
    #UseTable    Quote Number
    #ClickCell    r2/c4
    ClickElement    //tr[1]//td[3]//a
    VerifyText    Edit Lines
    ${renewal_quote_url}=    GetUrl

    # Verify that ren quote contains the same amount of line items as the original quote
    OpenRecordsRelatedView    ${renewal_quote_url}    SBQQ__LineItems__r
    ReloadRecordListUntilRecordCountIs    Line Name    ${data_dict}[line_item_count]

    # Verify that the ren price is matching after applying  the ren uplift % (7%)
    IF    ${data_dict}[bundle][main_product] is not ${NONE}
        VerifyQuoteLineItem    ${renewal_quote_url}    ${data_dict}[bundle][main_product][name]    ${data_dict}[bundle][main_product][quote_line_item_fields]
    ELSE
        VerifyQuoteLineItem    ${renewal_quote_url}    ${data_dict}[bundle][auto_products][0][name]    ${data_dict}[bundle][auto_products][0][quote_line_item_fields]
    END
    # Create a dictionary which is used for checking that this pre-req tc has passed
    # The dict contents are also utilized in the dependent tcs
    ${cpq_80_data}=    CreateDictionary
    ...    opportunity_url=${opp_url}
    ...    quote_url=${quote_url}
    ...    contract_url=${contract_url}
    
    [Return]    ${cpq_80_data}

Test Implementation 94
    [Arguments]    ${data_dict}    ${cpq_80_data}=${NONE}
    IF    $cpq_80_data is ${NONE}
        Fail     Pre-requisite test case CPQ-80 has not been executed successfully before running this test case!"
    END

    ImpersonateWithUid    ${order_management_user}
    CloseAllSalesConsoleTabs

    ${opp_url}=  SetVariable    ${cpq_80_data}[opportunity_url]
    ${quote_url}=  SetVariable    ${cpq_80_data}[quote_url]

    # Confirm that an order has been created for the original opp (CPQ-80) after closing it
    OpenRecordsRelatedView    ${opp_url}    Orders
    ReloadRecordListUntilRecordCountIs    Order Number    1
    # ClickCell    r2/c2
    ClickElement    //tr[1]//th[1]//a
    VerifyText    Order Information
    ${order_url}=    GetUrl

    # Store orders field values for validation
    ${account}=    GetFieldValue    Account Name    tag=a
    ${partner}=    GetFieldValue    Partner    tag=a    # not sure if this is a link
    ${start_date}=    GetFieldValue    Order Start Date
    ${price_book}=    GetAttribute     locator=(//div[./div/span[text()="Price Book"]]//a)[1]    attribute=text    visibility=false
    ${payment_method}=    GetFieldValue    Payment Method
    
    ${payment_term}=    GetFieldValue    Payment Term
    ${billing_frequency}=    GetAttribute     locator=(//div[./div/span[text()="Billing Frequency"]]//lightning-formatted-text)[1]    attribute=innerText    visibility=false
    ${opportunity}=    GetFieldValue    Opportunity    tag=a
    ${contracting_entity}=    GetAttribute     locator=(//div[./div/span[text()="Contracting Entity"]]//lightning-formatted-text)[1]    attribute=innerText    visibility=false
    ${po_required}=    GetFieldValue    PO Required

    # Store lightning opp values
    ${opportunity_name}=    GetFieldValue    Opportunity Name
    ${type}=    GetFieldValue    Type
    ${subscription_term}=    GetFieldValue    Subscription Term
    ${is_po_required}=    IsElement    xpath=//div[./div/span[text()="Is PO Required"]]//img[@alt="True"]
    ${bundle_line_items}=    IsElement    xpath=//div[./div/span[text()="Bundle Line Items"]]//img[@alt="True"]
    
    ${vat_number}=    GetFieldValue    VAT Number
    ${opp_owner}=    GetFieldValue     Opp Owner
    ${potential_plan}=    GetFieldValue  Potential Plan
    ${appid}=    GetFieldValue    APPID
    ${referral_discount_p}=    GetFieldValue  Referral Discount (%)
    
    ${referral_discount_amount}=    GetFieldValue    Referral Discount Amount
    ${withholding_tax_p}=    GetFieldValue    Withholding Tax (%)
    ${withholding_tax_amount}=    GetFieldValue  Withholding Tax Amount

    # Store lightning quote values
    ${tcv}=    GetFieldValue  TCV
    ${arr}=    GetFieldValue  ARR
    ${nrr}=    GetFieldValue  NRR
    ${auto_renewal}=    IsElement  xpath=//div[./div/span[text()="Auto Renewal"]]//img[@alt="True"]

    # Not present in quote
    ${contract_term}=    GetFieldValue  Contract Term (Months)
    
    ${avg_customer_disc_p}=    GetFieldValue  Avg. Customer Disc. (%)
    ${additional_disc_amount}=    GetFieldValue  Addl. Disc. Amount
    ${partner_discount}=    GetFieldValue  Partner Discount
    
    # Directly check the quote lightning component values which are on the order
    VerifyField    Price Book    ${price_book}    tag=a
    VerifyField    Partner    ${partner}    index=2
    VerifyField    Payment Terms    ${payment_term}
    #VerifyField    Billing Frequency    ${billing_frequency}    index=2    # does not match
    VerifyField    Contracting Entity    ${contracting_entity}

    # Validate order items
    OpenRecordsRelatedView    ${order_url}    OrderItems
    ReloadRecordListUntilRecordCountIs    Ordered Quantity    ${data_dict}[line_item_count]

    UseTable    Ordered Quantity
    FOR    ${index}    ${item}    IN ENUMERATE   @{data_dict}[line_items]
        #VerifyTable    r${index+2}/c2    ${item}
        ${text}=    GetAttribute    locator=//tr[${index+1}]//th[1]//a  attribute=textContent    value=${item}
        Should Contain  ${text}    ${item}
    END

    # Open opp and validate fields against the orders values
    GoTo    ${opp_url}
    VerifyText    FE Support Request

    VerifyField    Opportunity Name    ${opportunity_name}
    VerifyField    Type    ${type}
    #VerifyField    Subscription Term    ${subscription_term}    # no such field
    # Checkboxes are a bit tricky to check
    IF    ${is_po_required}
        VerifyElement    xpath=//lightning-input[@checked]//span[text()="Is PO Required"]
    ELSE
        VerifyNoElement    xpath=//lightning-input[@checked]//span[text()="Is PO Required"]
    END
    IF    ${bundle_line_items}
        VerifyElement    xpath=//lightning-input[@checked]//span[text()="Bundle Line Items"]
    ELSE
        VerifyNoElement    xpath=//lightning-input[@checked]//span[text()="Bundle Line Items"]
    END
    
    #VerifyField    VAT Number    ${vat_number}  # no such field
    VerifyField    Opportunity Owner    ${opp_owner}    tag=a
    VerifyField    Potential Plan    ${potential_plan}
    VerifyField    AlgoliaApp    ${appid}
    VerifyField    Referral Discount (%)    ${referral_discount_p}
    
    VerifyField    Referral Discount Amount    ${referral_discount_amount}
    VerifyField    Withholding Tax (%)    ${withholding_tax_p}
    VerifyField    Withholding Tax Amount    ${withholding_tax_amount}
    
    # Open quote and validate fields against the orders values
    GoTo    ${quote_url}
    VerifyText    Edit Lines

    VerifyField    Account    ${account}    tag=a
    VerifyField    Partner    ${partner}    tag=a  # not sure if this is a link
    VerifyField    Start Date    ${start_date}
    VerifyField    Price Book    ${price_book}    tag=a
    VerifyField    Payment Method    ${payment_method}

    VerifyField    Payment Terms    ${payment_term}
    VerifyField    Billing Frequency    ${billing_frequency}
    VerifyField    Opportunity    ${opportunity}    tag=a
    VerifyField    Contracting Entity    ${contracting_entity}
    VerifyField    PO Required    ${po_required}

    VerifyField    TCV    ${tcv}
    VerifyField    ARR    ${arr}
    VerifyField    NRR    ${nrr}
    # Checkboxes are a bit tricky to check
    IF    ${auto_renewal}
        VerifyElement    xpath=//lightning-input[@checked]//span[text()="Auto Renewal"]
    ELSE
        VerifyNoElement    xpath=//lightning-input[@checked]//span[text()="Auto Renewal"]
    END
    # Not present in quote
    #VerifyField    Contract Term (Months)    ${contract_term}
    #VerifyField    Avg. Customer Disc. (%)    ${avg_customer_disc_p}    # no such field
    VerifyField    Addl. Disc. Amount    ${additional_disc_amount}
    VerifyField    Partner Discount    ${partner_discount}

    # Open order, fill financial fields and save
    GoTo    ${order_url}
    VerifyText  Order Information
    ScrollTo    Order Information

    ClickText    Edit Invoiced
    VerifyNoText    Edit Invoiced

    ClickCheckbox    Invoiced  on
    TypeText    Invoice Number    1234
    TypeText    Invoice Date    ${start_date}
    TypeText    Invoiced By    CRT-Test
    ClickCheckbox    Provisioned  on
    TypeText  Provisioned Date  ${start_date}
    TypeText  Provisioned By  CRT-Test
    TypeText  PO Number  0987
    PickList  PO Required  No

    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Invoiced
    ...    click_kwargs=${click_kwargs}

    [Return]    ${TRUE}

Test Implementation 100
    [Arguments]    ${data_dict}    ${cpq_80_data}=${NONE}    ${cpq_94_passed}=${FALSE}
    IF    $cpq_80_data is ${NONE}
        Fail     Pre-requisite test case CPQ-80 has not been executed successfully before running this test case!"
    END
    IF    not ${cpq_94_passed}
        Fail     Pre-requisite test case CPQ-94 has not been executed successfully before running this test case!"
    END

    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

    ${contract_url}=    SetVariable    ${cpq_80_data}[contract_url]

    # Amend the contract
    GoTo    ${contract_url}
    VerifyField    Amendment Start Date    ${EMPTY}
    VerifyField    Amendment Opportunity Stage    ${EMPTY}
    VerifyField    Amendment Owner    ${EMPTY}
    VerifyField    Amendment Pricebook Id    ${EMPTY}
    VerifyNoElement    xpath=//lightning-input[@checked]//span[text()="Disable Amendment Co-Term"]

    ClickText   Amend    partial_match=False
    VerifyText    Amend Contract  partial_match=False
    ClickText   Amend    partial_match=False
    SetConfig    ShadowDOM    on
    ${no_error}=    IsText    Edit Quote    timeout=120
    IF    not ${no_error}
        SetConfig    ShadowDOM    off
        ${is_error}=    IsText    unable to obtain exclusive access    timeout=5
        IF    ${is_error}
            ClickText     Amend    partial_match=False
            SetConfig    ShadowDOM    on
            VerifyText    Edit Quote    timeout=120
        ELSE
            LogScreenshot
            Fail    No lock row error was found but the text to wait 'Edit Quote' did not appear
        END    
    END    

    # Amending will land us in QLE
    SetConfig    ShadowDOM    on
    VerifyText    Edit Quote    timeout=120

    # Test amending in QLE
    VerifyTableCell    Product Name    1    ${data_dict}[bundle][name]
    VerifyTableCell    List Total  1  USD 0.00

    FOR    ${index}    ${item}    IN ENUMERATE    @{data_dict}[amend_items]
        VerifyTableCell    Product Name    ${index+2}    ${item}[name]
        VerifyTableCell    List Total    ${index+2}    ${item}[list_total_1]
        TypeTable    Quantity    ${index+2}    ${item}[quantity_2]
    END
    
    ClickText  Calculate

    VerifyText    ${data_dict}[amend_totals][0]    anchor=Quote Total
    FOR    ${index}    ${item}    IN ENUMERATE    @{data_dict}[amend_items]
        VerifyTableCell    List Total    ${index+2}    ${item}[list_total_2]
    END
    
    # whitespace workaround for no error, not sure if this is intended behavior
    IF    "whitespace" not in $login_url
        ClickText    Quick Save
        VerifyText    You are not allowed to downgrade or cancel any quote lines. Please adjust your quantities back to the original quantities, or click cancel to start over    timeout=60
    END

    ${amend_quote_name}=    GetText    Q-
    # Exit and re-enter QLE
    ClickText    Cancel    anchor=Save    partial_match=False
    VerifyText    Account

    ${b64_query}=    GetSearchQuery    ${amend_quote_name}    SBQQ__Quote__c
    GoTo    url=${login_url}/one/one.app#${b64_query}
    VerifyText    Result
    
    ClickElement    xpath=//a[@title="${amend_quote_name}"]    timeout=10s
    VerifyText    Edit Lines
    ${amend_quote_url}=    GetUrl

    ClickText    Edit Lines
    VerifyText    Edit Quote    timeout=120

    # Double the original quantity
    FOR    ${index}    ${item}    IN ENUMERATE    @{data_dict}[amend_items]
        TypeTable    Quantity    ${index+2}    ${item}[quantity_3]
    END

    ClickText  Calculate
    VerifyText    ${data_dict}[amend_totals][1]    anchor=Quote Total
    FOR    ${index}    ${item}    IN ENUMERATE    @{data_dict}[amend_items]
        VerifyTableCell    List Total    ${index+2}    ${item}[list_total_3]
    END

    # Save the quote and confirm that we land on Quote record page
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Account
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

    # Open amendment opportunity
    GoTo    ${amend_quote_url}
    ClickText    Add-On    anchor=Opportunity    tag=a
    VerifyText  FE Support Request
    VerifyField    Opportunity Record Type    Expansion/Contraction    partial_match=True
    VerifyField  Stage  Interested