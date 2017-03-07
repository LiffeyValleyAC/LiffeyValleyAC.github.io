$(function(Query) {
  var query = new Query();

  query
    .setFromURL('query')
    .getJSON('/search.json')
    .done(function(data) {
      var searchIndex,
      results,
      $results = $('.search-results');

      // set up the allowable fields
      searchIndex = lunr(function() {
        this.field('title');
        this.field('content');
        this.field('results');
        this.ref('id');
      });

      // add each item from search.json to the index
      $.each(data,function(i,item) {
        item['id'] = i;
        searchIndex.add(item);
      });

      // search for the query and store the results as an array
      results = searchIndex.search(query.get());

      $('h3').append(' for "' + query.get() + '"');
      // go through the results
      $.each(results, function(i,result) {
        if(data[result.ref].type == 'news') {
          $results.append(' <h4><span class="label label-primary">News Item</span> <a href="' + data[result.ref].url +'">'+ data[result.ref].title +'</a>' +
              '<br /><small>'+ data[result.ref].date +'</small></h4>' +
              data[result.ref].excerpt +
              '<hr>');
        } else if(data[result.ref].type == 'race') {
          $results.append(' <h4><span class="label label-info">Race Results</span> <a href="' + data[result.ref].url +'">'+ data[result.ref].title +'</a>' +
              '<br /><small>'+ data[result.ref].date +'</small></h4>' +
              '<hr>');
        }
      });
    });    
}(Query));
