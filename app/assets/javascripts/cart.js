$(document).on('ready page:load',function() {
  // a typeahead that adds people to the card.
  // interacts with cocoon to do nested forms
  // does both big and mini-cart


    // initialize bloodhound engine
  var searchSelector = 'input#cart-typeahead';

  //filters out tags that are already in the list
  var filter = function(suggestions) {9
    var current_people = $('#mini-cart tr').map(function(index,el){
      return Number(el.id.replace(/^(cart-)/,''));
    });
    return $.grep(suggestions, function(suggestion) {
        return $.inArray(suggestion.id,current_people) === -1;
    });
  };

  var bloodhound = new Bloodhound({
    datumTokenizer: function (d) {
      return Bloodhound.tokenizers.whitespace(d.value);
    },
    queryTokenizer: Bloodhound.tokenizers.whitespace,
    remote: {
      url:'/search/index_ransack.json?q[nav_bar_search_cont]=%QUERY',
      wildcard: '%QUERY',
      filter: filter,
      limit: 20,
      cache: false
    }
  });
  bloodhound.initialize();

  // initialize typeahead widget and hook it up to bloodhound engine
  // #typeahead is just a text input
  $(searchSelector).typeahead(null, {
    name: 'People',
    displayKey: 'name',
    source: bloodhound.ttAdapter()
  });

  $(searchSelector).on('typeahead:selected', function(obj, datum){ //datum
    var cart_type = 'full';
    if ($('#mini-cart').length != 0) {
      cart_type = 'mini'
    };

    $.ajax({
      url: '/cart/add/'+datum.id,
      data: {type: cart_type },
      dataType: "script",
      success: function(){
        $(searchSelector).val('');
      }
    })
  });
});