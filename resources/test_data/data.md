Test data files are in YAML format which allows building complex data in quite easily digestable format.
    cheatsheet
        https://quickref.me/yaml.html
    full specification
        https://yaml.org/spec/1.2.2/
    
There are few conventions that should be followed but in general the data structuring has been done per test case basis.

Outermost data elements target potential plans, can be ignored if necessary
    v8_standard for Standard Committed - V8
    v85_elevate_ecomm for Elevate Ecomm v8.5
All data sets should contain key-value pairs
    potential_plan: Standard Committed - V8
    price_book: Algolia V8 Pricing

If products are added to a quote in the test case then the general the products are specified within a key named "bundle":
    # Standard Committed V8 : Algolia Plan Bundle
    bundle:
        name: Algolia Plan Bundle    # mandatory, name name of the bundle to add for the quote
        main_product:                # mandatory, if bundle has multiple main products to select then this should be specified, also look next example
            name: Standard (V8) (committed)
            quantity: '10000'        # quantity can be set automatically
        auto_products: []            # must be present, values will be set if bundle has products that are automatically added to it
        add_ons:                     # list of products to add under the add-ons section
            - name: Core Foundation
        services:                    # list of products to add under the services section
            - name: Algolia Guided Onboarding

    # Elevate Ecomm v8.5: Algolia Elevate Ecomm Bundle
    bundle:
        name: Algolia Elevate Ecomm Bundle
        main_product: Null           # must be always present, 
        auto_products:               # products which are automatically added to the bundle
          - name: Elevate Ecomm
            quantity: '10000'        # quantities can be set automatically
          - name: Records
            quantity: '2500'
        add_ons:
          - name: Enterprise Foundation
                                     # if there are no services or add_ons, they do not need to be present

Depending on test case 'bundle' can contain additional key-values and it's inner key-values might also have additional key-values:
    bundle:
      name: Algolia Plan Bundle
      start_total: USD 12,000.00     # initial total of the quote when all products have qty of 1
      end_total: USD 18,550.00       # total after main product qty has been updated to 10000
      line_item_count: 3             # 
      opportunity_line_item_fields:  # used for validating the opportunitys line item page for this item
        Quantity: '1.00'             # opp line item page should contain these key-value pairs, notice that the keys are typed as they appear on the page
        List Price: 'USD 0.00'
        Total Price: 'USD 0.00'
      main_product:
        name: Standard (V8) (committed)
        quantity: '10000'
        opportunity_line_item_fields:
          Quantity: '1.00'
          List Price: 'USD 1.00'
          Total Price: 'USD 6,550.00'
    auto_products: []
    add_ons:
      - name: Core Foundation
        opportunity_line_item_fields:
          Quantity: '1.00'
          List Price: 'USD 12,000.00'
          Total Price: 'USD 12,000.00'

One of the most generically conforming test data files is cpq-378.yaml which can be used as a starting point when creating initial test data for new test cases