*** Settings ***
Documentation      Creates base contracts for manual Service Order document testing
...                Should be excluded from normal test runs with '-e so-gen'
Library            QForce
Library            ../resources/python/ImpersonationUtils.py
Library            ../resources/python/DateUtils.py
Library            ../resources/python/GlobalSearch.py

Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/account.resource
Resource           ../resources/records/contact.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Resource           ../resources/records/opportunity_line_item.resource

Suite Setup    SuiteSetupActions
Suite Teardown    CloseAllBrowsers

*** Variables ***
# these vars will be set during suite setup
${acc_id}
${contact_name}

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login

    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs
    
    # Check if daily account exists and create one if not
    ${today}=    GetCurrentDate    result_format=%y%m%d  exclude_millis=True
    ${acc_name}=    SetVariable    CRT-SO-Renew-${today}
    ${f_name}=      SetVariable    CRT-SO
    ${l_name}=      SetVariable    Renew-User-${today}

    ${b64_query}=    GetSearchQuery    ${acc_name}    Account
    GoTo    url=${login_url}/one/one.app#${b64_query}
    VerifyText    Result
    
    ${daily_acc_exists}=    IsElement    xpath=//a[@title="${acc_name}"]    timeout=10s
    IF    ${daily_acc_exists}
        ${acc_id}=    GetAttribute    locator=(//a[@title="${acc_name}"])[1]    attribute=data-recordid
    ELSE
        ${acc_url}=    Create Account    ${acc_name}
        ${contact_url}=    Create Contact    ${acc_url}    ${f_name}    ${l_name}
        Create App To Account    ${acc_url}    ${acc_name}    ${f_name} ${l_name}
        ${acc_id}=    Resolve Record Id From Url    ${acc_url}    Account
    END

    Set Suite Variable    ${acc_id}    ${acc_id}
    Set Suite Variable    ${contact_name}    ${f_name} ${l_name}

*** Test Cases ***
V8 Premium
    [Tags]    so-gen    so-renew    v8-premium
    ${bundle_main_product}=  Evaluate    {"name":"Premium (V8) (committed)"}
    ${add_ons}=  Evaluate    [{"name":"Recommend (committed)"}, {"name":"Enterprise Foundation (incl. Analytics)"}]
    ${quantities}=  CreateList  22000  2200000
    CreateBaseContract
    ...  Premium Committed - V8
    ...  Algolia V8 Pricing
    ...  Algolia Plan Bundle
    ...  ${bundle_main_product}
    ...  ${add_ons}
    ...  ${NONE}
    ...  ${quantities}
    ...  under_v8=${FALSE}

V8 Standard
    [Tags]    so-gen    so-renew    v8-standard
    ${bundle_main_product}=  Evaluate    {"name":"Standard (V8) (committed)"}
    ${add_ons}=  Evaluate    [{"name":"Recommend (committed)"}]
    ${quantities}=  CreateList    15000  12000000
    CreateBaseContract
    ...  Standard Committed - V8
    ...  Algolia V8 Pricing
    ...  Algolia Plan Bundle
    ...  ${bundle_main_product}
    ...  ${add_ons}
    ...  ${NONE}
    ...  ${quantities}
    ...  under_v8=${FALSE}

V8 Standard Plus
    [Tags]    so-gen    so-renew    v8-standard-plus
    ${bundle_main_product}=  Evaluate    {"name":"Standard Plus (V8) (committed)"}
    ${add_ons}=  Evaluate    [{"name":"Crawler"}, {"name":"Enterprise Foundation (incl. Analytics)"}]
    ${quantities}=  CreateList    10000
    CreateBaseContract
    ...  Standard Plus (V8) (committed)
    ...  Algolia V8 Pricing
    ...  Algolia Plan Bundle
    ...  ${bundle_main_product}
    ...  ${add_ons}
    ...  ${NONE}
    ...  ${quantities}
    ...  under_v8=${FALSE}

V5 Business
    [Tags]    so-gen    so-renew    v5-business
    CreateBaseContract
    ...  Business
    ...  Algolia V5 Pricing
    ...  Business 30 (Annual)

V5 Enterprise 1
    [Tags]    so-gen    so-renew    v5-enterprise-1
    CreateBaseContract
    ...  Enterprise
    ...  Algolia V5 Pricing
    ...  Enterprise 1 Cluster

V5 Enterprise 2
    [Tags]    so-gen    so-renew    v5-enterprise-2
    CreateBaseContract
    ...  Enterprise
    ...  Algolia Pre V5 Pricing
    ...  Enterprise 2 Cluster

V6 Business
    [Tags]    so-gen    so-renew    v6-business
    CreateBaseContract
    ...  Business
    ...  Algolia V6 Pricing
    ...  Business Plan (Annual)

V6 Enterprise
    [Tags]    so-gen    so-renew    v6-enterprise
    CreateBaseContract
    ...  Enterprise
    ...  Algolia V6 Pricing
    ...  Enterprise Plan

V7 Business Lite
    [Tags]    so-gen    so-renew    v7-business-lite
    CreateBaseContract
    ...  Business Light - V7
    ...  Algolia V7 Pricing
    ...  Business Lite Plan
    
V7 Business
    [Tags]    so-gen    so-renew    v7-business
    CreateBaseContract
    ...  Business - V7
    ...  Algolia V7 Pricing
    ...  Business Plan

V7 Enterprise
    [Tags]    so-gen    so-renew    v7-enterprise
    CreateBaseContract
    ...  Enterprise - V7
    ...  Algolia V7 Pricing
    ...  Enterprise Plan

*** Keywords ***
Create Base Contract
    [Arguments]
    ...  ${potential_plan}
    ...  ${price_book}
    ...  ${base_product}
    ...  ${bundle_main_product}=${NONE}
    ...  ${add_ons}=${NONE}
    ...  ${services}=${NONE}
    ...  ${quantities}=${NONE}
    ...  ${under_v8}=${TRUE}
    
    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

    ${today}=    GetCurrentDate    result_format=%m/%d/%Y  exclude_millis=True

    IF    ${under_v8}
        ${opp_url}=    Create Opportunity
        ...  account_id=${acc_id}
        ...  contact_name=${contact_name}
        ...  opportunity_name=${price_book}-${potential_plan}-Opp
        
        # on pre V8 plans/pbs the potential plan and price book need to be set after opp creation
        ClickWhile    Edit Opportunity Name    Edit Opportunity Name    interval=15

        # Price Book combobox does not play nice
        ClickElement  xpath=//lightning-grouped-combobox[./label[text()="Price Book"]]//button[.//span[text()="Clear Selection"]]  timeout=1
        ${linebreak}=    SetConfig    LineBreak    ${EMPTY}
        TypeText    locator=//lightning-grouped-combobox[./label[text()="Price Book"]]  input_text=${price_book}  timeout=1
        VerifyElement   xpath=//lightning-grouped-combobox[./label[text()="Price Book"]]//lightning-base-combobox-formatted-text[@title="${price_book}"]
        Sleep    1
        ClickElement    xpath=//lightning-grouped-combobox[./label[text()="Price Book"]]//lightning-base-combobox-formatted-text[@title="${price_book}"]
        SetConfig    LineBreak    ${linebreak}

        PickList    Potential Plan    ${potential_plan}

        ${click_kwargs}=    Evaluate    {'partial_match':False}
        ClickTextAndRetryOnLockRowError
        ...    text_to_click=Save
        ...    text_to_wait=Edit Opportunity Name
        ...    click_kwargs=${click_kwargs}
        
    ELSE
        ${opp_url}=    Create Opportunity
        ...  account_id=${acc_id}
        ...  contact_name=${contact_name}
        ...  opportunity_name=${price_book}-${potential_plan}-Opp
        ...  potential_plan=${potential_plan}
        ...  price_book=${price_book}
    END

    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=EU
    ...  contracting_entity=Algolia, Inc.
    ...  bill_to_contact=${contact_name}
    ...  ship_to_contact=${contact_name}

    OpenQLE    ${quote_url}
    ClickText    Add Products

    AddBundleToQuoteLines    ${base_product}    ${bundle_main_product}    ${add_ons}    ${services}

    IF    $quantities is not None
        FOR    ${index}  ${item}  IN ENUMERATE  @{quantities}
            ${row}=    Convert To String  ${index+2}  # index starts at 0 and the mutable prods from row 2
            TypeTable    Quantity    ${row}    ${item}
        END
    END

    ClickText    Calculate
    Sleep    5

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':120}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

    ClickText    Edit PO Required
    CustomComboBox    DocuSign Signer    ${contact_name}
    ${click_kwargs}=    Evaluate    {'anchor':"Cancel",'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit PO Required
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    
    IF  ${under_v8}
        # on pre V8 pbs we need to set the Approval Status with elevated role
        StopImpersonation
        GoTo    ${quote_url}
        VerifyText    Edit PO Required
        ClickWhile    Edit PO Required    Edit PO Required    interval=15
        PickList    Approval Status    Approved

        ${click_kwargs}=    Evaluate    {'anchor':"Cancel",'partial_match':False}
        ${wait_kwargs}=    Evaluate    {'timeout':60}
        ClickTextAndRetryOnLockRowError
        ...    text_to_click=Save
        ...    text_to_wait=Edit PO Required
        ...    click_kwargs=${click_kwargs}
        ...    wait_kwargs=${wait_kwargs}
    ELSE
        ClickText    Preview Approval
        VerifyText    Submit for Approval
        ClickText    Submit for Approval

        VerifyText    Approval Status
        StopImpersonation
    END
    

    GoTo    ${opp_url}
    VerifyText    New Quote
    ClickText    Discovery
    Sleep  2
    ClickText    Mark as Current Stage
    Sleep  2
    VerifyText    Mark Stage as Complete

    # Set opp values in order to set the opp to status:Signed
    ClickText    Edit Potential Plan
    VerifyNoText    Edit Potential Plan
    Picklist    Expansion Type    Customer Growth
    TypeText    AE Renewal/Expansion Notes    Test Automation
    TypeText    What will Algolia Power?    Test Automation

    # MEDDPICC
    TypeText    Mutual Closing Plan    Test Automation
    TypeText    Closing Notes    Test Automation
    #RichTextInput    Identified Pain    Test Automation    # set on opp creation
    #RichTextInput    Ability to buy    Test Automation     # set on opp creation
    RichTextInput    Metrics / ROI Details    Test Automation
    RichTextInput    Competition Details    Test Automation
    RichTextInput    Decision Criteria    Test Automation
    RichTextInput    Paper process    Test Automation
    RichTextInput    Decision Process    Test Automation
    MultiPickList    Competition    Amazon Cloud Search
    PickList    Primary Competitor    Azure Cognitive Search

    # Handover Information
    PickList    Implementation Responsibility    External Partner
    PickList    Expansion Potential    Consumption Capacity
    TypeText    Expansion Potential Details    Test Automation
    TypeText    Expected Go Live    ${today}

    ${click_kwargs}=    Evaluate    {'anchor':"Cancel",'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Potential Plan
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    

    ClickText    Signed  anchor=Closed  partial_match=false
    Sleep  2
    ClickText    Mark as Current Stage
    VerifyText    Mark Stage as Complete
    ClickText    Closed  anchor=Signed  partial_match=false
    ClickText    Select Closed Stage
    UseModal    On
    VerifyText    Close This Opportunity
    Dropdown    locator=//div[./label/span[text()="Stage"]]/select  option=Closed Won
    ClickText    Save    anchor=Cancel    partial_match=false
    VerifyNoText    Close This Opportunity
    UseModal    off
    VerifyText    Closed Won    timeout=180

     # Verify that the opp closing creates a contract
    OpenRecordsRelatedView    ${opp_url}    SBQQ__Contracts__r
    # This polls roughly for 6 minutes
    #   can fail if there's heavy load on the environment and the contract generation takes long
    ReloadRecordListUntilRecordCountIs    Contract Number    1    limit=40
