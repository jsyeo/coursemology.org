$(document).ready(function() {
  var content = $('.submission-question-block').annotator();
  content.annotator('addPlugin', 'Store', {
    prefix: document.URL
  });
});