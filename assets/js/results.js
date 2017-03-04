$(function(Query) {
  var query = new Query(),
  site = location.protocol + "//" + location.host;

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
        this.field('excerpt');
        this.ref('id');
      });

      // add each item from search.json to the index
      $.each(data,function(i,item) {
        item['id'] = i;
        searchIndex.add(item);
      });

      // search for the query and store the results as an array
      results = searchIndex.search(query.get());

      // go through the results
      $.each(results, function(i,result) {
        $results.append(' <h3><a href="' + data[result.ref].url +'">'+ data[result.ref].title +'</a>' +
        '<br /><small>'+ data[result.ref].date +'</small></h3>' +
        data[result.ref].excerpt +
        '<hr>');
      });
    });    
}(Query));
