*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/common/common.resource
Resource           ../resources/common/error.resource
Resource           ../resources/common/variables.resource
Resource           ../resources/records/opportunity.resource
Resource           ../resources/records/quote.resource
Resource           ../resources/records/qle.resource
Variables          ../resources/test_data/cpq-378.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
CPQ-378 - V8 Standard
    [Tags]    cpq-378    quote    v8-standard
    Test Implementation    ${v8_standard}

CPQ-378 - V8.5 Elevate Ecomm
    [Tags]    cpq-378    quote    v8.5-elevate-ecomm
    Test Implementation    ${v85_elevate_ecomm} 

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    CheckDailyAccount
    ${record_prefix}=    SetRecordPrefix    CPQ-378

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
    AddBundleToQuoteLines
    ...    ${data_dict}[bundle][name]
    ...    ${data_dict}[bundle][main_product]
    ...    add_ons=${data_dict}[bundle][add_ons]
    ...    services=${data_dict}[bundle][services]
    Set QLE Product Quantities    ${data_dict}[bundle]
    Set QLE Auto Product Discounts    ${data_dict}[bundle]

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off
    # Exited QLE

    # Set the signer for the quote
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
    # Quote has been saved after adding the required info

    # Submit quote for approval
    ClickText    Preview Approval
    VerifyText    Submit for Approval  timeout=120
    VerifyText    Algolia Guided Onboarding Approval
    ClickText    Submit for Approval

    VerifyText    Quote Details    timeout=120

    # Validate approval status gets initially set to 'Pending'
    ${approval_status}=    GetFieldValue    Approval Status
    IF    "Approval Status" != "Pending"
        # Appr status is not always updated immediately,
        #   so refresh and recheck once if it does not match the expected
        Sleep    5
        RefreshPage
        VerifyText    Quote Details
    END
    VerifyField    Approval Status    Pending


    ImpersonateWithUid    ${deal_desk_user}
    CloseAllSalesConsoleTabs

    # Open the approval item (there should only be one)
    OpenRecordsRelatedView    ${quote_url}    Approvals__r
    ReloadRecordListUntilRecordCountIs    Approval \#    1
    ClickText    A-

    # Validate approvals basic info
    VerifyText    Reassign
    ${approval_url}=    GetUrl
    VerifyField    Assigned To    ${EMPTY}
    VerifyField    Approval Chain    Algolia Guided Onboarding Approval    tag=a

    # Confirm that dd user can not approve 
    ClickText    Approve    anchor=Reject    partial_match=False
    UseModal    on
    VerifyText    Error:Not Allowed to approve because you don't have permission
    ClickText    Cancel
    UseModal  off
    
    # Set the override approvals checkbox to true
    GoTo    ${quote_url}
    VerifyText    Edit Override Approvals
    ClickText    Edit Override Approvals
    VerifyNoText    Edit Override Approvals
    ClickCheckbox    Override Approvals    on
    ClickText    Save    anchor=Cancel    partial_match=False
    VerifyText    Edit Override Approvals


    GoTo    ${approval_url}
    VerifyText    Reassign
    # Check that the approval has been assigned to the dd user
    VerifyField    Assigned To    Don Valle    tag=a

    # Actual approval
    ClickText    Approve    anchor=Reject    partial_match=False
    UseModal   on
    VerifyText    Cancel
    ClickText    Approve    anchor=Cancel    partial_match=False

    VerifyText    Quote Details    timeout=120

    # Verify that the quote has been approved
    ${approval_status}=    GetFieldValue    Approval Status
    IF    "Approval Status" != "Approved"
        Sleep    5
        RefreshPage
        VerifyText    Quote Details
    END
    VerifyField    Approval Status    Approved