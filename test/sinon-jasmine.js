(function() {
  var sinonJasmine = (function() {
    var spyMatchers = "called calledOnce calledTwice calledThrice calledBefore calledAfter calledOn alwaysCalledOn calledWith alwaysCalledWith calledWithExactly alwaysCalledWithExactly".split(" "),
      i = spyMatchers.length,
      spyMatcherHash = {},
      unusualMatchers = {
        "returned": "toHaveReturned",
        "alwaysReturned": "toHaveAlwaysReturned"
      },
    
    getMatcherFunction = function(sinonName) {
      return function() {
        var sinonProperty = this.actual[sinonName];
        return (typeof sinonProperty === 'function') ? sinonProperty.apply(this.actual, arguments) : sinonProperty;
      };
    };
    
    while(i--) {
      var sinonName = spyMatchers[i],
        matcherName = "toHaveBeen" + sinonName.charAt(0).toUpperCase() + sinonName.slice(1);
      
      spyMatcherHash[matcherName] = getMatcherFunction(sinonName);
    };
  
    for (var j in unusualMatchers) {
      spyMatcherHash[unusualMatchers[j]] = getMatcherFunction(j);
    }
  
    return {
      getMatchers: function() {
        return spyMatcherHash;
      }
    };
  
    })();

    beforeEach(function() {
      this.addMatchers(sinonJasmine.getMatchers());
    });
  
})();