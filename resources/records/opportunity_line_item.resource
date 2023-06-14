*** Settings ***
Library    QForce
Resource   ../common/salesforce.resource

*** Keywords ***
Verify Opportunity Line Item
    [Documentation]  Navigates to opportunitys line items and validates the given line items fields
    ...  Arguments:
    ...  ${opportunity_url}: Url to the opportunity of which line item will be validated
    ...  ${item_name}: Name of the line item which will be validated
    ...  ${field_dict}: Dictionary containing field name-field value pairs
    ...
    ...  Example: Verifies that an opportunity has line item 'Algolia Plan Bundle'
    ...           And that the line item record has Quantity of '1.00', List Price of 'USD 0.00' and Total Price of 'USD 0.00'
    ...
    ...  ${bundle_fields}=    Evaluate    {'Quantity':'1.00', 'List Price':'USD 0.00', 'Total Price':'USD 0.00'}
    ...  Verify Opportunity Line Item    ${opp_url}    Algolia Plan Bundle    ${bundle_fields}
    [Arguments]    ${opportunity_url}
    ...            ${item_name}
    ...            ${field_dict}

    OpenRecordsRelatedView  ${opportunity_url}  OpportunityLineItems
    VerifyText    Product Code
    
    ClickText    ${item_name}    tag=a
    # Link click does not always register so we check if we landed on the the li page 
    ${on_line_item_page}=    IsText    Product Information    timeout=30
    IF  ${on_line_item_page}
        NoOperation
    ELSE
        # not on the li page retry clicking the link
        ClickText    ${item_name}    tag=a
        VerifyText    Product Information    timeout=30
    END

    #  Check all provided field name-field value pairs
    FOR    ${key}    ${value}    IN    &{field_dict}
        VerifyField    ${key}    ${value}
    END
