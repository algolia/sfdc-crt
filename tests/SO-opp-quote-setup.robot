*** Settings ***
Documentation      Creates base quotes for manual Service Order document testing
...                Should be excluded from normal test runs with '-e so-gen'

Library            QForce
Library            ../resources/python/ImpersonationUtils.py
Library            ../resources/python/DateUtils.py
Library            ../resources/python/GlobalSearch.py
Library            DateTime

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

Test Setup    RefreshPage
*** Variables ***
${usd_acc_id}=    0017A00000yZusCQAS
${eur_acc_id}=    0017A00000yZup4QAC
${msa_acc_id}=    0017A00000yeMSwQAM

${usd_contact}=    CRT-CPQ Common-User-SO-test-1-USD
${eur_contact}=    CRT-CPQ Common-User-SO-test-1-EUR
${msa_contact}=    CRT-CPQ Common-User-SO-test-1-MSA

*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs

    #Create accounts
    Create SO Account    usd
    Create SO Account    eur
    Create SO Account    msa    1/31/2023   # month/day/year  without leading zeros

Create SO Account
    [Arguments]    ${type}    ${msa_date}=${NONE}
    ${today}=       GetCurrentDate    result_format=%y%m%d
    ${type_lc}=     Evaluate    $type.lower()
    ${type_uc}=     Evaluate    $type.upper()
    ${acc_name}=    SetVariable    CRT-SO-Quote-${type_uc}-${today}
    ${f_name}=      SetVariable    CRT-SO
    ${l_name}=      SetVariable    Quote-${type_uc}-User-${today}

    ${curr}=    SetVariable    USD - U.S. Dollar
    IF    $type_lc == "eur"
        ${curr}=    SetVariable    EUR - Euro
    END

    ${b64_query}=    GetSearchQuery    ${acc_name}    Account
    GoTo    url=${login_url}/one/one.app#${b64_query}
    VerifyText    Result
    
    ${daily_acc_exists}=    IsElement    xpath=//a[@title="${acc_name}"]    timeout=10s
    IF    ${daily_acc_exists}
        ${acc_id}=    GetAttribute    locator=(//a[@title="${acc_name}"])[1]    attribute=data-recordid
    ELSE
        ${acc_url}=    Create Account    ${acc_name}    currency=${curr}
        ${contact_url}=    Create Contact    ${acc_url}    ${f_name}    ${l_name}    currency=${curr}
        Create App To Account    ${acc_url}    ${acc_name}    ${f_name} ${l_name}
        ${acc_id}=    Resolve Record Id From Url    ${acc_url}    Account

        IF    $msa_date is not ${NONE}
            ImpersonateWithUid    ${deal_desk_user}
            CloseAllSalesConsoleTabs

            GoTo    ${acc_url}
            # Fields should be editable with dd user
            VerifyText    Edit MSA Date
            ClickText    Edit MSA Date
            VerifyNoText    Edit MSA Date
    
            # Set the field contents and save
            TypeText    MSA Date    ${msa_date}
            PickList    MSA in place    Yes

            ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
            ClickTextAndRetryOnLockRowError
            ...    text_to_click=Save
            ...    text_to_wait=Edit MSA Date
            ...    click_kwargs=${click_kwargs}

            ImpersonateWithUid    ${primary_user}
            CloseAllSalesConsoleTabs
        END
    END

    Set Suite Variable    ${${type_lc}_acc_id}    ${acc_id}
    Set Suite Variable    ${${type_lc}_contact}    ${f_name} ${l_name}

*** Test Cases ***
v8.1 Premium
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}
    ${record_prefix}=    SetRecordPrefix    SO-v8.1 Premium

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium v8.1
    ...  price_book=Algolia v8.1 Premium Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=UK
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${main_product}=    Evaluate    {"name":"Premium"}
    ${add_ons}=    Evaluate    [{"name":"Recommend"}]
    Add Bundle To Quote Lines    Algolia Premium Bundle    ${main_product}    ${add_ons}
    TypeTable    Quantity    2    10000
    TypeTable    Quantity    3    5000

    TypeTable    Additional Disc.    2    15
    TypeTable    Additional Disc.    3    15

    ClickText    Calculate
    
    Verify Text  15.00000 %

    VerifyTableCell    Quantity  2  10,000
    VerifyTableCell    Quantity  3  5,000

    VerifyTableCell    Additional Disc.  2  15.00000 %
    VerifyTableCell    Additional Disc.  3  15.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

v8.1 Premium - R&R
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-v8.1 Premium - R&R

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  opportunity_type=Upgrade
    ...  upgrade_from=V8 Standard Committed
    ...  potential_plan=Premium v8.1
    ...  price_book=Algolia v8.1 Premium Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=EU
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}
    ...  replace_previous_so=${TRUE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend"}, {"name":"Enterprise Foundation (incl. Analytics)"}]
    ${main_product}=    Evaluate    {"name":"Premium"}
    Add Bundle To Quote Lines    Algolia Premium Bundle    ${main_product}    ${add_ons}
    TypeTable    Quantity    2    26000
    TypeTable    Quantity    3    10000

    TypeTable    Additional Disc.    2    26
    TypeTable    Additional Disc.    3    10

    ClickText    Calculate
    
    Verify Text  26.00000 %

    VerifyTableCell    Quantity  2  26,000
    VerifyTableCell    Quantity  3  10,000

    VerifyTableCell    Additional Disc.  2  26.00000 %
    VerifyTableCell    Additional Disc.  3  10.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Scale
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Scale

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Scale v8.5
    ...  price_book=Algolia v8.5 Scale Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Monthly
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    Add Bundle To Quote Lines    Algolia Scale Bundle
    TypeTable    Quantity    2    15000
    TypeTable    Quantity    3    2000

    TypeTable    Additional Disc.    2    15
    TypeTable    Additional Disc.    3    15

    ClickText    Calculate
    
    Verify Text  15.00000 %

    VerifyTableCell    Quantity  2  15,000
    VerifyTableCell    Quantity  3  2,000

    VerifyTableCell    Additional Disc.  2  15.00000 %
    VerifyTableCell    Additional Disc.  3  15.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Scale - No Auto Renewal
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Scale - No Auto Renewal

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Scale v8.5
    ...  price_book=Algolia v8.5 Scale Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=24
    ...  infrastructure_locations=US-West
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  auto_renewal=${FALSE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    Add Bundle To Quote Lines    Algolia Scale Bundle
    TypeTable    Quantity    2    1500000
    TypeTable    Quantity    3    20000

    TypeTable    Additional Disc.    2    0
    TypeTable    Additional Disc.    3    0

    ClickText    Calculate
    
    Verify Text  1,500,000

    VerifyTableCell    Quantity  2  1,500,000
    VerifyTableCell    Quantity  3  20,000


    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Scale - Publicity Changes - MDQ
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Scale - Publicity Changes - MDQ

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Scale v8.5
    ...  price_book=Algolia v8.5 Scale Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=24
    ...  infrastructure_locations=US-West
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  logo_consent=${FALSE}
    ...  publicity_rights=${FALSE}
    ...  case_study_commitment=${FALSE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    Add Bundle To Quote Lines    Algolia Scale Bundle
    TypeTable    Quantity    2    1500000
    TypeTable    Quantity    3    20000

    TypeTable    Additional Disc.    2    0
    TypeTable    Additional Disc.    3    0

    ClickText    Calculate
    
    Verify Text  1,500,000

    VerifyTableCell    Quantity  2  1,500,000
    VerifyTableCell    Quantity  3  20,000


    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Scale - various add ons 1
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Scale - various add ons 1

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Scale v8.5
    ...  price_book=Algolia v8.5 Scale Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=US-East
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products

    ${add_ons}=    Evaluate    [{"name":"Recommend"}, {"name":"Analytics Extended Retention"},{"name":"DSN"},{"name":"HIPAA/BAA"},{"name":"Single Tenancy + Vault"}]
    Add Bundle To Quote Lines    Algolia Scale Bundle    add_ons=${add_ons}
    TypeTable    Quantity    2    12000
    TypeTable    Quantity    3    1000
    TypeTable    Quantity    4    12050

    TypeTable    Additional Disc.    2    32
    TypeTable    Additional Disc.    3    10
    TypeTable    Additional Disc.    4    32
    TypeTable    Additional Disc.    7    5

    ClickText    Calculate
    
    Verify Text  32.00000 %

    VerifyTableCell    Quantity  2  12,000
    VerifyTableCell    Quantity  3  1,000
    VerifyTableCell    Quantity  4  12,050

    VerifyTableCell    Additional Disc.  2  32.00000 %
    VerifyTableCell    Additional Disc.  3  10.00000 %
    VerifyTableCell    Additional Disc.  4  32.00000 %
    VerifyTableCell    Additional Disc.  7  5.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Scale - various add ons 2
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Scale - various add ons 2

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Scale v8.5
    ...  price_book=Algolia v8.5 Scale Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=US-East
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products

    ${add_on_names}=    CreateList
    ...  Crawler
    ...  Premier SLA
    ...  Extended Support
    ...  Essential Foundation
    ...  Named Contact
    ${add_ons}=    Evaluate    [{"name":"Recommend"}, {"name":"Analytics Extended Retention"},{"name":"DSN"},{"name":"HIPAA/BAA"},{"name":"Single Tenancy + Vault"}]
    Add Bundle To Quote Lines    Algolia Scale Bundle    add_ons=${add_ons}

    TypeTable    Quantity    2    12000
    TypeTable    Quantity    3    1000

    TypeTable    Additional Disc.    2    32
    TypeTable    Additional Disc.    3    10
    TypeTable    Additional Disc.    4    32
    TypeTable    Additional Disc.    5    8
    TypeTable    Additional Disc.    6    5
    TypeTable    Additional Disc.    7    25

    ClickText    Calculate
    
    Verify Text  32.00000 %

    VerifyTableCell    Quantity  2  12,000
    VerifyTableCell    Quantity  3  1,000

    VerifyTableCell    Additional Disc.  2  32.00000 %
    VerifyTableCell    Additional Disc.  3  10.00000 %
    VerifyTableCell    Additional Disc.  4  32.00000 %
    VerifyTableCell    Additional Disc.  5  8.00000 %
    VerifyTableCell    Additional Disc.  6  5.00000 %
    VerifyTableCell    Additional Disc.  7  25.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Elevate
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Elevate

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Elevate v8.5
    ...  price_book=Algolia v8.5 Elevate Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=Germany
    ...  billing_frequency=Monthly
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products

    ${add_ons}=    Evaluate    [{"name":"Analytics Extended Retention"}]
    Add Bundle To Quote Lines    Algolia Elevate Bundle    add_ons=${add_ons}
    TypeTable    Quantity    2    200000
    TypeTable    Quantity    3    30000

    TypeTable    Additional Disc.    2    25
    TypeTable    Additional Disc.    3    25
    TypeTable    Additional Disc.    4    25
    ClickText    Calculate
    
    Verify Text  25.00000 %

    VerifyTableCell    Quantity  2  200,000
    VerifyTableCell    Quantity  3  30,000

    VerifyTableCell    Additional Disc.  2  25.00000 %
    VerifyTableCell    Additional Disc.  3  25.00000 %
    VerifyTableCell    Additional Disc.  4  25.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Elevate - R&R (bundled items)
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Elevate - R&R (bundled items)

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  opportunity_type=Upgrade
    ...  potential_plan=Elevate v8.5
    ...  price_book=Algolia v8.5 Elevate Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=36
    ...  infrastructure_locations=Canada
    ...  payment_terms=Net 60
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  replace_previous_so=${TRUE}
    ...  bundle_line_items=${TRUE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Crawler"}]
    Add Bundle To Quote Lines    Algolia Elevate Bundle    add_ons=${add_ons}
    TypeTable    Quantity    2    200000
    TypeTable    Quantity    3    30000

    TypeTable    Additional Disc.    2    25
    TypeTable    Additional Disc.    3    25
    TypeTable    Additional Disc.    4    25
    
    ClickText    Calculate
    
    Verify Text  25.00000 %

    VerifyTableCell    Quantity  2  200,000
    VerifyTableCell    Quantity  3  30,000

    VerifyTableCell    Additional Disc.  2  25.00000 %
    VerifyTableCell    Additional Disc.  3  25.00000 %
    VerifyTableCell    Additional Disc.  4  25.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Elevate - various add ons - R&R (bundled items)
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Elevate - various add ons - R&R (bundled items)

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  opportunity_type=Upgrade
    ...  potential_plan=Elevate v8.5
    ...  price_book=Algolia v8.5 Elevate Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=EU
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}
    ...  replace_previous_so=${TRUE}
    ...  bundle_line_items=${TRUE}

    OpenQLE    ${quote_url}
    ClickText    Add Products

    ${add_ons}=    Evaluate    [{"name":"Core Foundation"},{"name":"Extended Support"},{"name":"Named Contact"}]
    Add Bundle To Quote Lines    Algolia Elevate Bundle    add_ons=${add_ons}
    TypeTable    Quantity    2    25000
    TypeTable    Quantity    3    2000

    TypeTable    Additional Disc.    2    0
    TypeTable    Additional Disc.    3    0

    ${product_discounts}=    Evaluate    {'auto_products':[1,2]}
    Set QLE Auto Product Discounts    ${product_discounts}

    ClickText    Calculate
    
    Verify Text  25,000

    VerifyTableCell    Quantity  2  25,000
    VerifyTableCell    Quantity  3  2,000

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Elevate Ecomm
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Elevate Ecomm

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Elevate Ecomm v8.5
    ...  price_book=Algolia v8.5 Elevate Ecomm Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  infrastructure_locations=Singapore
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Extended Support"}]
    Add Bundle To Quote Lines    Algolia Elevate Ecomm Bundle    add_ons=${add_ons}
    TypeTable    Quantity    2    10000
    TypeTable    Quantity    3    2000

    TypeTable    Additional Disc.    2    75
    TypeTable    Additional Disc.    3    20
    TypeTable    Additional Disc.    4    75

    ClickText    Calculate
    
    Verify Text  75.00000 %

    VerifyTableCell    Quantity  2  10,000
    VerifyTableCell    Quantity  3  2,000

    VerifyTableCell    Additional Disc.  2  75.00000 %
    VerifyTableCell    Additional Disc.  3  20.00000 %
    VerifyTableCell    Additional Disc.  4  75.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Elevate Ecomm & PS
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Elevate Ecomm & PS

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Elevate Ecomm v8.5
    ...  price_book=Algolia v8.5 Elevate Ecomm Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=18
    ...  infrastructure_locations=EU
    ...  payment_terms=Net 40
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${services_names}=    CreateList
    ...  Algolia Blueprint - Prepaid Services
    ...  Algolia AEM Accelerator - Prepaid Services
    ${services}=    Evaluate    [{"name":"Algolia Blueprint - Prepaid Services"},{"name":"Algolia AEM Accelerator - Prepaid Services"}]
    Add Bundle To Quote Lines    Algolia Elevate Ecomm Bundle    services=${services}

    TypeTable    Quantity    2    10000
    TypeTable    Quantity    3    2000

    TypeTable    Additional Disc.    2    45
    TypeTable    Additional Disc.    3    20

    ClickText    Calculate
    
    Verify Text  45.00000 %

    VerifyTableCell    Quantity  2  10,000
    VerifyTableCell    Quantity  3  2,000

    VerifyTableCell    Additional Disc.  2  45.00000 %
    VerifyTableCell    Additional Disc.  3  20.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

Elevate Ecomm - Hide Discount
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-Elevate Ecomm - Hide Discount

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Elevate Ecomm v8.5
    ...  price_book=Algolia v8.5 Elevate Ecomm Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=24
    ...  infrastructure_locations=EU
    ...  payment_terms=Net 40
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}
    ...  show_additional_discount=${FALSE}
    ...  show_partner_discount_on_so=${FALSE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    
    Select QLE Product    Algolia Kickstart - Prepaid Services
    ClickText    Select    partial_match=False

    ClickText    Calculate
    Sleep  2
    
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Quarterly
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}

    TypeTable    Quantity    2    150000

    TypeTable    Additional Disc.    2    35

    ClickText    Calculate
    
    Verify Text  35.00000 %

    VerifyTableCell    Quantity  2  150,000

    VerifyTableCell    Additional Disc.  2  35.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - MSA
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${msa_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - MSA

    ${opp_url}=    Create Opportunity
    ...  account_id=${msa_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}
    TypeTable    Quantity    2    150000

    TypeTable    Additional Disc.    2    35

    ClickText    Calculate
    
    Verify Text  35.00000 %

    VerifyTableCell    Quantity  2  150,000

    VerifyTableCell    Additional Disc.  2  35.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - PS
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - PS

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    
    ${services}=    Evaluate    [{"name":"Algolia Advisory 25 - Prepaid Services"}]
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    services=${services}

    TypeTable    Quantity    2    150000

    TypeTable    Additional Disc.    2    35

    ClickText    Calculate
    
    Verify Text  35.00000 %

    VerifyTableCell    Quantity  2  150,000

    VerifyTableCell    Additional Disc.  2  35.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - Reseller
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - Reseller

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.
    ...  partner=Frank Digital Pty Ltd - Partner

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}

    TypeTable    Quantity    2    150000

    TypeTable    Additional Disc.    2    35

    TypeText    Partner Discount    25

    ClickText    Calculate
    
    Verify Text  35.00000 %

    VerifyTableCell    Quantity  2  150,000

    VerifyTableCell    Additional Disc.  2  35.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - R&R
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - R&R

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  replace_previous_so=${TRUE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}

    TypeTable    Quantity    2    150000

    TypeTable    Additional Disc.    2    35

    ClickText    Calculate
    
    Verify Text  35.00000 %

    VerifyTableCell    Quantity  2  150,000

    VerifyTableCell    Additional Disc.  2  35.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - Discounted Excess Usage
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - Discounted Excess Usage

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  discounted_excess_search_rate_unit=0.55
    ...  discounted_excess_search_volume=10000

    OpenQLE    ${quote_url}
    ClickText    Add Products
    
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}

    TypeTable    Quantity    2    10000

    TypeTable    Additional Disc.    2    35

    ClickText    Calculate
    
    Verify Text  35.00000 %

    VerifyTableCell    Quantity  2  10,000

    VerifyTableCell    Additional Disc.  2  35.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - Discounted Excess Usage (& Recommend)
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - Discounted Excess Usage (& Recommend)

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  discounted_excess_search_rate_unit=0.55
    ...  discounted_excess_search_volume=10000
    ...  discounted_excess_recommend_rate_unit=0.45
    ...  discounted_excess_recommend_volume=120000

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend (committed)"}]
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    12000
    TypeTable    Quantity    3    12000000

    TypeTable    Additional Disc.    3    10

    ClickText    Calculate
    
    Verify Text  10.00000 %

    VerifyTableCell    Quantity  2  12,000
    VerifyTableCell    Quantity  3  12,000,000

    VerifyTableCell    Additional Disc.  3  10.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - Price Protection - 3 Years
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - Price Protection - 3 Years

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  price_protection=Price Protection - Time Period
    ...  price_protection_term_in_years=3

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend (committed)"}]
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    12000
    TypeTable    Quantity    3    12000000

    TypeTable    Additional Disc.    3    10

    ClickText    Calculate
    
    Verify Text  10.00000 %

    VerifyTableCell    Quantity  2  12,000
    VerifyTableCell    Quantity  3  12,000,000

    VerifyTableCell    Additional Disc.  3  10.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - Price Protection - 1 Year
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - Price Protection - 1 Year

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  price_protection=Price Protection - Time Period
    ...  price_protection_term_in_years=1

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend (committed)"}]
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    12000
    TypeTable    Quantity    3    12000000

    TypeTable    Additional Disc.    3    10

    ClickText    Calculate
    
    Verify Text  10.00000 %

    VerifyTableCell    Quantity  2  12,000
    VerifyTableCell    Quantity  3  12,000,000

    VerifyTableCell    Additional Disc.  3  10.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Premium - Price Protection %
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Premium - Price Protection %

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Premium Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=EU
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}
    ...  price_protection=Price Protection - up to % increase
    ...  price_protection_up_to_percent=6

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend (committed)"}]
    ${main_product}=    Evaluate    {"name":"Premium (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    12000
    TypeTable    Quantity    3    12000000

    TypeTable    Additional Disc.    3    10

    ClickText    Calculate
    
    Verify Text  10.00000 %

    VerifyTableCell    Quantity  2  12,000
    VerifyTableCell    Quantity  3  12,000,000

    VerifyTableCell    Additional Disc.  3  10.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Standard - MDQ
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Standard - MDQ

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=24
    ...  infrastructure_locations=UK
    ...  billing_frequency=Monthly
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend (committed)"}]
    ${main_product}=    Evaluate    {"name":"Standard (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    280000
    TypeTable    Quantity    3    10000000

    TypeTable    Additional Disc.    2    24.5
    TypeTable    Additional Disc.    3    24.5

    ClickText    Calculate
    
    Verify Text  24.50000 %

    VerifyTableCell    Quantity  2  280,000
    VerifyTableCell    Quantity  3  10,000,000

    VerifyTableCell    Additional Disc.  2  24.50000 %
    VerifyTableCell    Additional Disc.  3  24.50000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Standard - R&R, MDQ
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Standard - R&R, MDQ

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=36
    ...  infrastructure_locations=UK
    ...  billing_frequency=Monthly
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}
    ...  replace_previous_so=${TRUE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend (committed)"}]
    ${main_product}=    Evaluate    {"name":"Standard (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    280000
    TypeTable    Quantity    3    10000000

    TypeTable    Additional Disc.    2    24.5
    TypeTable    Additional Disc.    3    24.5

    ClickText    Calculate
    
    Verify Text  24.50000 %

    VerifyTableCell    Quantity  2  280,000
    VerifyTableCell    Quantity  3  10,000,000

    VerifyTableCell    Additional Disc.  2  24.50000 %
    VerifyTableCell    Additional Disc.  3  24.50000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Standard - Discounted Excess Usage
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Standard - Discounted Excess Usage

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  discounted_excess_search_rate_unit=0.55
    ...  discounted_excess_search_volume=10000

    OpenQLE    ${quote_url}
    ClickText    Add Products
    
    ${main_product}=    Evaluate    {"name":"Standard (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}

    TypeTable    Quantity    2    10000

    TypeTable    Additional Disc.    2    35

    ClickText    Calculate
    
    Verify Text  35.00000 %

    VerifyTableCell    Quantity  2  10,000

    VerifyTableCell    Additional Disc.  2  35.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Standard - Discounted Excess Usage (& Recommend)
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Standard - Discounted Excess Usage (& Recommend)

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-East
    ...  billing_frequency=Annual
    ...  payment_terms=Net 45
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}
    ...  discounted_excess_search_rate_unit=0.55
    ...  discounted_excess_search_volume=10000
    ...  discounted_excess_recommend_rate_unit=0.45
    ...  discounted_excess_recommend_volume=120000

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Recommend (committed)"}]
    ${main_product}=    Evaluate    {"name":"Standard (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    12000
    TypeTable    Quantity    3    12000000

    TypeTable    Additional Disc.    3    10

    ClickText    Calculate
    
    Verify Text  10.00000 %

    VerifyTableCell    Quantity  2  12,000
    VerifyTableCell    Quantity  3  12,000,000

    VerifyTableCell    Additional Disc.  3  10.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 PS Only
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 PS Only

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=US-West
    ...  billing_frequency=Annual
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia, Inc.

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    Select QLE Product    Algolia Merchandising Accelerator - Prepaid Services
    Select QLE Product    Algolia Advisory 25 - Prepaid Services
    Select QLE Product    Algolia Quick Start for Shopify - Prepaid Service
    ClickText    Select    partial_match=False

    ClickText    Calculate
    Sleep    2

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Standard - Publicity changes
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Standard - Publicity changes

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=UK
    ...  billing_frequency=Monthly
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}
    ...  case_study_and_engagement_notes=${TRUE}
    ...  social_media_distribution=${TRUE}
    ...  public_speaker=${TRUE}
    ...  reference_calls=${TRUE}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_ons}=    Evaluate    [{"name":"Analytics Extended Retention"}, {"name":"DSN"}, {"name":"Single Tenancy + Vault"}, {"name":"Core Foundation"}, {"name":"HIPAA/BAA"}]
    ${main_product}=    Evaluate    {"name":"Standard (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    58500

    TypeTable    Additional Disc.    2    48

    ClickText    Calculate
    
    Verify Text  48.00000 %

    VerifyTableCell    Quantity  2  58,500

    VerifyTableCell    Additional Disc.  2  48.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

V8 Standard Plus
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${eur_contact}

    ${record_prefix}=    SetRecordPrefix    SO-V8 Standard Plus

    ${opp_url}=    Create Opportunity
    ...  account_id=${eur_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Plus (V8) (committed)
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=12
    ...  infrastructure_locations=UK
    ...  billing_frequency=Monthly
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products
    ${add_on_names}=    CreateList
    ...  Crawler
    ...  Enterprise Foundation (incl. Analytics)
    ...  Premier SLA
    
    ${add_ons}=    Evaluate    [{"name":"Crawler"}, {"name":"Enterprise Foundation (incl. Analytics)"}, {"name":"Premier SLA"}]
    ${main_product}=    Evaluate    {"name":"Standard Plus (V8) (committed)"}
    Add Bundle To Quote Lines    Algolia Plan Bundle    ${main_product}    ${add_ons}

    TypeTable    Quantity    2    25000

    TypeTable    Additional Disc.    2    38
    TypeTable    Additional Disc.    3    38
    TypeTable    Additional Disc.    4    38
    TypeTable    Additional Disc.    5    38

    ClickText    Calculate
    
    Verify Text  38.00000 %

    VerifyTableCell    Quantity  2  25,000

    VerifyTableCell    Additional Disc.  2  38.00000 %
    VerifyTableCell    Additional Disc.  3  38.00000 %
    VerifyTableCell    Additional Disc.  4  38.00000 %
    VerifyTableCell    Additional Disc.  5  38.00000 %

    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off

PAB
    [Tags]    so-gen    so-new-business
    ${contact_name}   SetVariable    ${usd_contact}

    ImpersonateWithUid    ${primary_user}
    CloseAllSalesConsoleTabs
    ${record_prefix}=    SetRecordPrefix    SO-PAB

    ${opp_url}=    Create Opportunity
    ...  account_id=${usd_acc_id}
    ...  contact_name=${contact_name}
    ...  opportunity_name=${record_prefix}-Opp
    ...  potential_plan=Standard Committed - V8
    ...  price_book=Algolia V8 Pricing
    ${quote_url}=    CreateQuote
    ...  opportunity_url=${opp_url}
    ...  primary_contact_name=${contact_name}
    ...  subscription_term=4
    ...  infrastructure_locations=EU
    ...  billing_frequency=Annual
    ...  payment_method=Credit Card
    ...  payment_terms=Due on receipt
    ...  contracting_entity=Algolia SAS

    Update Quote For Service Order Document    ${quote_url}

    OpenQLE    ${quote_url}
    ClickText    Add Products

    ${services}=    Evaluate    [{"name":"Algolia Kickstart - Prepaid Services"}]
    Add Bundle To Quote Lines    Premium Adoption Bundle    services=${services}

    ClickText    Calculate
    Sleep    2    
    
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Lines
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}
    SetConfig  ShadowDOM  Off