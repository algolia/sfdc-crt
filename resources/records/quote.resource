*** Settings ***
Library            QForce
Library            DateTime
Library            String
Library            ../python/DateUtils.py
Resource           ../common/salesforce.resource
Resource           ../common/error.resource

*** Keywords ***
Create Quote
    [Documentation]    Creates an opportunity to an account, returns the url of created opportunity
    ...  Arguments: Any of the quotes fields can be given as arguments but mandatory arguments are
    ...  ${opportunity_url}
    ...  ${primary_contact_name}
    ...  
    ...  Argument ${infrastructure_locations} accepts a single selection string or list of selections
    ...      Create Quote    ${url}    Bob Thebuilder    infrastructure_locations=US-East
    ...      # or with a list
    ...      ${locations}=    Create List    US-East    US-West
    ...      Create Quote    ${url}    Bob Thebuilder    infrastructure_locations=${locations}
    ...
    ...  There's also a utility argument:
    ...  ${days_to_start_date}: If ${start_date} is left empty then this can be used to set start date to n days from current date
    [Arguments]    ${opportunity_url}
    ...            ${primary_contact_name}
    ...            ${start_date}=${EMPTY}
    ...            ${days_to_start_date}=0
    ...            ${infrastructure_locations}=US-East
    ...            ${is_primary}=${TRUE}
    ...            ${subscription_term}=12
    ...            ${billing_frequency}=Annual
    ...            ${payment_terms}=Net 30
    ...            ${payment_method}=Wire Transfer
    ...            ${payment_method_margin}=${EMPTY}
    ...            ${contracting_entity}=Algolia, Inc.
    ...            ${bill_to_contact}=${EMPTY}
    ...            ${ship_to_contact}=${EMPTY}
    ...            ${partner}=${EMPTY}

    GoTo    ${opportunity_url}
    VerifyText    Interested
    ClickText    New Quote    anchor=FE Support Request
    VerifyText    Primary Contact

    # Resolve quote start date
    IF    "${start_date}" == "${EMPTY}"
          ${date}=    GetCurrentDate
          ${date}=    AddTimeToDate    ${date}    ${days_to_start_date} days
          ${date}=    ConvertDate    ${date}    result_format=%m/%d/%Y   exclude_millis=True
    ELSE
          ${date}=    SetVariable    ${start_date}
    END

    
    # fill modal form
    UseModal    on
    # left column
    IF    ${is_primary}
        ClickCheckBox    Primary    On
    ELSE
        ClickCheckBox    Primary    Off
    END
    
    # handle infrastructure locations
    ${ifl_is_list}    Evaluate    isinstance($infrastructure_locations, list)
    IF    ${ifl_is_list}
        FOR    ${location}    IN    @{infrastructure_locations}
            MultiPickList    Infrastructure Location    ${location}
        END
    ELSE
        MultiPickList    Infrastructure Location    ${infrastructure_locations}
    END

    TypeText          Start Date             ${date}
    TypeText          Subscription Term             ${subscription_term}
    PickList          Payment Terms    ${payment_terms}
    TypeText          Payment Method Margin    ${payment_method_margin}
    PickList          Contracting Entity      ${contracting_entity}

    IF    "${ship_to_contact}" != "${EMPTY}"
        ComboBox    Ship To Contact    ${ship_to_contact}
    END
    # right column
    ComboBox          Primary Contact    ${primary_contact_name}
    PickList          Billing Frequency    ${billing_frequency}
    PickList          Payment Method       ${payment_method}

    IF    "${bill_to_contact}" != "${EMPTY}"
        CustomComboBox    Bill To Contact    ${bill_to_contact}
    END
    
    IF    "${partner}" != "${EMPTY}"
        ComboBox    Partner    ${partner}
    END
        
    ClickText    Save
    
    # Check if the modal closed
    ${modal_closed}    Is No Text    Save    timeout=30
    IF    ${modal_closed}
        NoOperation
    ELSE
        # Did not close reclick 'Save'
        ClickText    Save
    END
    VerifyNoText    Save
    UseModal    off

    VerifyText    Quote Number:    timeout=60

    # the created Quotes url needs to be retrieved with another keyword    
    ${url}=    GetLatestQuoteUrl    ${opportunity_url}
    [Return]    ${url}


Validate Quote Defaults
    [Documentation]  Opens quote creation modal and validates madatory fields and default values, after validations the creation is canceled
    [Arguments]    ${opportunity_url}
    GoTo    ${opportunity_url}
    VerifyText    Interested
    ClickText    New Quote    anchor=FE Support Request
    VerifyText    Primary Contact

    UseModal    on

    VerifyCheckboxValue    Primary    on

    # Infrastructure Location does not have an asterisk in front of the label...
    #Verify Field Mandatory Indicator    Infrastructure Location
    ${chosen_locations}=    GetElementCount    locator=//lightning-dual-listbox//div[@class="slds-dueling-list__column slds-dueling-list__column_responsive" and contains(.,"Chosen")]//li    timeout=2
    ShouldBeEqualAsNumbers    ${chosen_locations}    0

    # default start date is tomorrow
    ${zero_strip_char}=    GetDateZeroStripChar
    ${date}=    GetCurrentDate
    ${date}=    AddTimeToDate    ${date}    1 days
    ${date}=    ConvertDate    ${date}    result_format=%${zero_strip_char}m/%${zero_strip_char}d/%Y   exclude_millis=True

    VerifyFieldMandatoryIndicator    Start Date
    VerifyInputValue    Start Date    ${date}

    VerifyFieldMandatoryIndicator    Subscription Term
    VerifyInputValue    Subscription Term    12

    VerifyFieldMandatoryIndicator    Payment Terms
    VerifyPicklistSelection    Payment Terms    Net 30

    VerifyFieldMandatory Indicator    Contracting Entity
    VerifyPicklistSelection    Contracting Entity    --None--

    VerifyFieldMandatory Indicator    Primary Contact
    VerifyInputValue    Primary Contact    ${EMPTY}

    VerifyFieldMandatoryIndicator    Billing Frequency
    VerifyPicklistSelection    Billing Frequency    Annual

    VerifyFieldMandatory Indicator    Payment Method
    VerifyPicklistSelection    Payment Method    Wire Transfer

    ClickText    Cancel
    VerifyNoText    Cancel
    UseModal    off


Get Latest Quote Url
    [Documentation]  Opens opportunitys quotes and returns the url of the highest numbered quote
    [Arguments]    ${opportunity_url}
    OpenRecordsRelatedView    ${opportunity_url}    SBQQ__Quotes2__r
    UseTable   Quote Number

    # any found quote will be higher than this
    ${max_quote_number}=    SetVariable    00000

    ${row_count}=    GetTableRow    //last

    # reload the quote list page until there are quotes present
    IF    "${row_count}"=="1"
        Sleep    10
        RefreshPage
        UseTable   Quote Number
        ${row_count}=    GetTableRow    //last
    END
    
    # iterate through all quotes and store the highest number
    FOR    ${index}    IN RANGE    1    ${row_count}
        ${current_quote_number}=    GetAttribute    //tr[${index}]//td[3]//a    textContent
        ${curr_number}=    ReplaceString    ${current_quote_number}    Q-    ${EMPTY}
        
        IF    int("${curr_number}") > int("${max_quote_number}")
            ${max_quote_number}=    SetVariable    ${curr_number}
            ${max_quote_index}=    SetVariable    ${index}
        END
    END

    # get the url reference from the quote link element
    ${url}=    GetAttribute    //tr[${max_quote_index}]//td[3]//a    href

    # url reference might not be loaded yet, check it's value and if it is not a valid url retry reading the url after a moment 
    WHILE    "${url}"=="javascript:void(0);"    limit=10
        HoverElement    //tr[${max_quote_index}]//td[3]//a
        Sleep  1
        ${url}=    GetAttribute    //tr[${max_quote_index}]//td[3]//a    href
    END
    [Return]    ${url}


Open QLE
    [Documentation]  Navigates to the provided quote url, and opens QLE 
    ...  Also sets config 'ShadowDOM': 'True' so that QLE elements can be interacted upon
    [Arguments]    ${quote_url}
    ${on_quote_page}=    IsText    Edit Lines    partial_match=False    timeout=0.5
    IF    not ${on_quote_page}
        GoTo    ${quote_url}
    END
    VerifyText    Edit Lines
    ClickText    Edit Lines

    SetConfig  ShadowDOM  On
    ${no_error}=    IsText  Calculate    timeout=60
    IF    ${no_error}
        ReturnFromKeyword
    END

    # QLE might open 'empty' with only the lock row error modal present
    # if the error modal is present, try reloading the page and checking for the text 'Calculate' again
    ${is_error}=    IsText    unable to obtain exclusive access    timeout=5
    IF    ${is_error}
        RefreshPage
        VerifyText    Calculate    timeout=60
    ELSE
        LogScreenshot
        Fail    No lock row error was found but the text to 'Calculate' did not appear
    END
    

Set Quote As Primary
    [Documentation]  Navigates to a quote and sets the quote as the primary quote
    [Arguments]    ${quote_url}
    GoTo  ${quote_url}

    ClickText  Edit Primary
    VerifyNoText    Edit Primary
    # Checkbox states are bit finicky in SFDC, even if the cb gets set it might get reset if the next interaction happens too fast
    Sleep    2
    ClickCheckbox  Primary  on
    Sleep    2
    
    ${click_kwargs}=    Evaluate    {'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit Primary
    ...    click_kwargs=${click_kwargs}


Verify Quote Line Item
    [Documentation]  Navigates to quotes line items and validates the given line items fields
    ...  Arguments:
    ...  ${quote_url}: Url to the opportunity of which line item will be validated
    ...  ${item_name}: Name of the line item which will be validated
    ...  ${field_dict}: Dictionary containing field name-field value pairs
    ...
    ...  Example: Verifies that the quote has line item 'Algolia Plan Bundle'
    ...           And that the line item record has Quantity of '1.00', List Price of 'USD 0.00' and Total Price of 'USD 0.00'
    ...
    ...  ${bundle_fields}=    Evaluate    {'Quantity':'1.00', 'List Price':'USD 0.00', 'Total Price':'USD 0.00'}
    ...  Verify Quote Line Item    ${quote_url}    Algolia Plan Bundle    ${bundle_fields}
    [Arguments]    ${quote_url}
    ...            ${item_name}
    ...            ${field_dict}
    ...            ${anchor}=1

    OpenRecordsRelatedView    ${quote_url}    SBQQ__LineItems__r

    UseTable    Line Name
    Sleep    2
    
    #ClickCell    r?${item_name}/c4
    ${row_count}=    GetTableRow    //last
    FOR    ${index}    IN RANGE    1    ${row_count}
        ${row_item}=    GetAttribute    //tr[${index}]//td[3]//a    textContent
        
        IF    $row_item == $item_name          
              ClickElement    //tr[${index}]//th//a
              BREAK
        END
    END

    VerifyText    Pricing Information
    FOR    ${key}    ${value}    IN    &{field_dict}
        ${status}=    Run Keyword And Return Status    Verify Field    ${key}    ${value}

        # Field content might be a link so if the Verify Field failed, retry by expecting the field to be a link
        # If it's not a link with the expected text then the keyword is going fail as it should
        
        IF    ${status}==${FALSE}
            VerifyField    ${key}    ${value}    tag=a
        END
    END


Update Quote For Service Order Document
    [Arguments]
    ...    ${quote_url}
    ...    ${auto_renewal}=${TRUE}
    ...    ${show_additional_discount}=${TRUE}
    ...    ${show_partner_discount_on_so}=${TRUE}
    ...    ${is_success_plan_eligible}=${TRUE}
    ...    ${po_required_on_so}=${TRUE}
    ...    ${logo_consent}=${TRUE}
    ...    ${publicity_rights}=${TRUE}
    ...    ${case_study_commitment}=${TRUE}
    ...    ${case_study_and_engagement_notes}=${FALSE}
    ...    ${social_media_distribution}=${FALSE}
    ...    ${public_speaker}=${FALSE}
    ...    ${reference_calls}=${FALSE}
    ...    ${replace_previous_so}=${FALSE}
    ...    ${bundle_line_items}=${FALSE}
    ...    ${price_protection}=${NONE}  # Price Protection - Time Period / Price Protection - up to % increase
    ...    ${price_protection_term_in_years}=${NONE}
    ...    ${price_protection_up_to_percent}=${NONE}
    ...    ${discounted_excess_search_rate_unit}=${NONE}
    ...    ${discounted_excess_search_volume}=${NONE}
    ...    ${discounted_excess_recommend_rate_unit}=${NONE}
    ...    ${discounted_excess_recommend_volume}=${NONE}

    GoTo    ${quote_url}
    VerifyText    Quote Details
    ClickText    Edit PO Required
    VerifyNoText  Edit PO Required
    Sleep    1

    Set Form Checkbox    Auto Renewal   ${auto_renewal}
    Set Form Checkbox    Show Additional Discount    ${show_additional_discount}
    Set Form Checkbox    Show Partner Discount on SO    ${show_partner_discount_on_so}
    Set Form Checkbox    Is Success Plan Eligible    ${is_success_plan_eligible}
    Set Form Checkbox    PO Required option on SO    ${po_required_on_so}

    Set Form Checkbox    Logo Consent    ${logo_consent}
    Set Form Checkbox    Publicity Rights    ${publicity_rights}
    Set Form Checkbox    Case Study Commitment    ${case_study_commitment}
    Set Form Checkbox    Case Study & Engagement Notes    ${case_study_and_engagement_notes}
    Set Form Checkbox    Social Media Distribution    ${social_media_distribution}
    Set Form Checkbox    Public Speaker    ${public_speaker}
    Set Form Checkbox    Reference Calls    ${reference_calls}

    Set Form Checkbox    Replace Previous SO    ${replace_previous_so}
    Set Form Checkbox    Bundle Line Items    ${bundle_line_items}

    IF    $price_protection is not None
        Picklist    Price Protection    ${price_protection}
        Sleep    1
    END
    IF    $price_protection_term_in_years is not None
        TypeText    Price Protection Term In Years    ${price_protection_term_in_years}
        Sleep    1
    END
    IF    $price_protection_up_to_percent is not None
        TypeText    Price Protection Up To %    ${price_protection_up_to_percent}
        Sleep    1
    END

    
    IF    $discounted_excess_search_rate_unit is not None
        TypeText    Discounted Excess Search Rate/Unit    ${discounted_excess_search_rate_unit}
        Sleep    1
    END
    IF    $discounted_excess_search_volume is not None
        TypeText    Discounted Excess Search Volume    ${discounted_excess_search_volume}
        Sleep    1
    END
    IF    $discounted_excess_recommend_rate_unit is not None
        TypeText    Discounted Excess Recommend Rate/Unit    ${discounted_excess_recommend_rate_unit}
        Sleep    1
    END
    IF    $discounted_excess_recommend_volume is not None
        TypeText    Discounted Excess Recommend Volume    ${discounted_excess_recommend_volume}
        Sleep    1
    END

    ${click_kwargs}=    Evaluate    {'anchor':"Cancel",'partial_match':False}
    ${wait_kwargs}=    Evaluate    {'timeout':60}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=Edit PO Required
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}


Set Form Checkbox
    [Documentation]    Checks or unchecks the labeled checkbox of a record form (needs to be in edit mode)
    [Arguments]    ${label}    ${checked}
    ${status}=    FormCheckboxStatus    ${label}    timeout=0.1
    WHILE    ${status}!=${checked}    limit=5
        ClickElement    xpath=//lightning-input[.//label[.="${label}"]]//input    timeout=2.0
        Sleep  1
        ${status}=    FormCheckboxStatus    ${label}
    END
    

Form Checkbox Status
    [Documentation]    Returns true if the labeled Checkbox is checked and false if unchecked
    [Arguments]    ${label}    ${timeout}=1
    ${status}=    IsElement    xpath=//lightning-input[.//label[.="${label}"] and @checked]    timeout=${timeout}
    [Return]    ${status}