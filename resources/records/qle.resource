*** Settings ***
Library            QForce
Library            DateTime
Library            String

Resource           ../common/salesforce.resource

*** Keywords ***
Add Bundle To Quote Lines
    [Documentation]    Adds bundle product with optional products to Quote Lines
    ...  Pre-Requisite: On QLE 'Product Selection' page
    ...
    ...  Arguments
    ...  ${base_name}: The name of the main product, the product names listed in the 'Product selection' page
    ...  ${bundle_name}: Name of the bundle, For example 'Standard (V8) (committed)'
    ...  ${add_on_names}: List of add-on product names to add, For example ['Core Foundation']
    ...  ${services_names}: List of services names to add
    ...
    ...  Example: Add "Algolia Plan Bundle - Standard (V8) (committed) - Core Foundation" bundle to quote lines
    ...
    ...  ${add_on_names}=    Create List    Core Foundation
    ...  Add Bundle To Quote Lines   Algolia Plan Bundle    Standard (V8) (committed)    ${add_on_names}
    [Arguments]    ${base_name}    ${main_product_dict}=${NONE}   ${add_ons}=${NONE}    ${services}=${NONE}
    Verify Text  Product Selection

    # Select the main product
    ClickItem  checkbox  anchor=${base_name}
    ClickText    Select    partial_match=False

    # Add bundles main product, should be None if values are pre-selected
    IF    $main_product_dict is not ${NONE}
        Verify Text  Configure Products
        ClickItem    radioContainer   anchor=${main_product_dict}[name]
    END

    # add add-on products (if any to add)
    IF    $add_ons is not ${NONE}
        Verify Text  Configure Products
        FOR    ${item}    IN    @{add_ons}
            Select QLE Product  ${item}[name]
            Sleep    1
        END
    END

    # add services products (if any to add)
    IF    $services is not ${NONE}
        Verify Text  Configure Products
        FOR    ${item}    IN    @{services}
            Select QLE Product  ${item}[name]
            Sleep    1
        END
    END

    # Save and verify that we landed on the QLE 'main' page
    ClickText  Save
    VerifyText  Add Products    timeout=60

Select QLE Product
    [Documentation]    Selects or unselects the given product (name or code)
    [Arguments]    ${product_code_or_name}    ${select}=True    ${retry_limit}=5
    ${is_selected}=    Get Attribute
    ...    locator=checkbox
    ...    attribute=aria-checked
    ...    tag=paper-checkbox
    ...    anchor=${product_code_or_name}
    ...    element_type=item

    WHILE    "${is_selected}" != "${select.lower()}"    limit=${retry_limit}
        Click Item    checkbox    anchor=${product_code_or_name}
        Sleep    1

        ${is_selected}=    Get Attribute
        ...    locator=checkbox
        ...    attribute=aria-checked
        ...    tag=paper-checkbox
        ...    anchor=${product_code_or_name}
        ...    element_type=item
    END

Set QLE Product Quantities
    [Documentation]    Sets product quantities specified in a bundle dictionary
    ...    Such dictionaries are specified in cpq-x.yaml files
    ...    Refer to data.md for dictionarys structural details
    [Arguments]    ${bundle_dict}
    IF    ${bundle_dict}[main_product] is not ${NONE}
        TypeTable    Quantity    2    ${bundle_dict}[main_product][quantity]
    END
    FOR    ${index}    ${item}    IN ENUMERATE   @{bundle_dict}[auto_products]
        TypeTable    Quantity    ${index+2}    ${item}[quantity]
    END

    TRY
        ${add_ons}=    Set Variable    ${bundle_dict}[add_ons]
        FOR    ${index}    ${item}    IN ENUMERATE   @{add_ons}
            TypeTable    Quantity    ${item}[row]    ${item}[quantity]
        END
    EXCEPT
        No Operation
    END
    TRY
        ${services}=    Set Variable    ${bundle_dict}[services]
        FOR    ${index}    ${item}    IN ENUMERATE   @{services}
            TypeTable    Quantity    ${item}[row]    ${item}[quantity]
        END
    EXCEPT
        No Operation
    END

Set QLE Auto Product Discounts
    [Documentation]    Sets bundle dictionarys automatically added product additional discounts to zero
    ...    An example of such products ia Algolia Elevate Ecomm Bundle: Elevate Ecomm, Records
    ...    Refer to data.md for dictionarys structural details
    [Arguments]    ${bundle_dict}
    FOR    ${index}    ${item}    IN ENUMERATE   @{bundle_dict}[auto_products]
        TypeTable    Additional Disc.    ${index+2}    0
    END

Verify QLE Cells
    [Documentation]    Verifies that columns cells contain the values provided in the list ${cells}
    ...    ${start_index} controls the row where the validations start, ${start_index}=2 -> start at row 2
    [Arguments]    ${cells}    ${start_index}    ${column_name}
    FOR    ${index}    ${item}    IN ENUMERATE    @{cells}
        ${row}=    Evaluate    int($start_index)+int($index)
        VerifyTableCell    ${column_name}    ${row}    ${item}
    END

Verify Configuration Checkbox Disabled State
    [Documentation]    Verifies that QLE product configuration item selection is disabled or not
    ...  Arguments:
    ...  ${product_name}: Name of the configuration item to check
    ...  ${expected_state}: Should the checkbox be disabled, ${TRUE}=is disabled, ${FALSE}=is not disabled (is enabled)
    [Arguments]    ${product_name}    ${expected_state}
    ${elem}=    GetWebElement   checkbox   anchor=${product_name}  tag=paper-checkbox   element_type=item
    ${disabled}=   Evaluate     str($elem.get_attribute("aria-disabled")).lower()
    ${expected}=    ConvertToLowerCase    ${expected_state}
    ShouldBeEqualAsStrings    ${disabled}    ${expected}

Verify QLE Additional Disc Editable
    [Documentation]    Verifies that QLE 'main' page products Additional Discount column can be edited or not
    ...  Arguments:
    ...  ${product_name}: Name of the product to check
    ...  ${expected_state}: Should the products 'Additional Discount' column be editable, ${TRUE}=is editable, ${FALSE}=is not editable
    [Arguments]    ${product_name}    ${expected_state}
    ${e}=  GetWebElement  SBQQ__AdditionalDiscount__c  anchor=${product_name}  tag=div  element_type=item
    ${editable}=    Evaluate     "editable" in str($e.get_attribute("class")).lower()

    ShouldBeEqualAsStrings    ${editable}    ${expected_state}