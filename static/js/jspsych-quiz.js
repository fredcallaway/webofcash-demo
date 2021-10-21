/**
 * jspsych-survey-multi-choice
 * a jspsych plugin for multiple choice survey questions
 *
 * Shane Martin
 *
 * documentation: docs.jspsych.org
 *
 */


jsPsych.plugins['quiz'] = (function() {

  var plugin = {};

  plugin.trial = function(display_element, trial) {
    display_element.html('')

    var plugin_id_name = "jspsych-survey-multi-choice";
    var plugin_id_selector = '#' + plugin_id_name;
    var _join = function( /*args*/ ) {
      var arr = Array.prototype.slice.call(arguments, _join.length);
      return arr.join(separator = '-');
    }
    var numTriesLeft = trial.numTries;

    // trial defaults
    var default_preamble = `
      <h1>Quiz</h1>

      <p>Please answer the following questions before continuing.
    `;
    trial.preamble = typeof trial.preamble == 'undefined' ? default_preamble : trial.preamble;
    trial.horizontal = typeof trial.horizontal == 'undefined' ? false : trial.horizontal;

    // if any trial variables are functions
    // this evaluates the function and replaces
    // it with the output of the function
    trial = jsPsych.pluginAPI.evaluateFunctionParameters(trial, protect=['onMistake']);

    // form element
    var trial_form_id = _join(plugin_id_name, "form");
    display_element.append($('<form>', {
      "id": trial_form_id
    }));
    var $trial_form = $("#" + trial_form_id);

    // show preamble text
    var preamble_id_name = _join(plugin_id_name, 'preamble');
    $trial_form.append($('<div>', {
      "id": preamble_id_name,
      "class": preamble_id_name
    }));
    $('#' + preamble_id_name).html(trial.preamble);

    // add multiple-choice questions
    for (var i = 0; i < trial.questions.length; i++) {
      // create question container
      var question_classes = [_join(plugin_id_name, 'question')];
      if (trial.horizontal) {
        question_classes.push(_join(plugin_id_name, 'horizontal'));
      }

      $trial_form.append($('<div>', {
        "id": _join(plugin_id_name, i),
        "class": question_classes.join(' ')
      }));

      var question_selector = _join(plugin_id_selector, i);

      // add question text
      $(question_selector).append(
        '<p class="' + plugin_id_name + '-text survey-multi-choice">' + trial.questions[i] + '</p>'
      );

      // create option radio buttons
      for (var j = 0; j < trial.options[i].length; j++) {
        var option_id_name = _join(plugin_id_name, "option", i, j),
          option_id_selector = '#' + option_id_name;

        // add radio button container
        $(question_selector).append($('<div>', {
          "id": option_id_name,
          "class": _join(plugin_id_name, 'option')
        }));

        // add label and question text
        var option_label = '<label class="' + plugin_id_name + '-text">' + trial.options[i][j] + '</label>';
        $(option_id_selector).append(option_label);

        // create radio button
        var input_id_name = _join(plugin_id_name, 'response', i);
        $(option_id_selector + " label").prepend('<input type="radio" name="' + input_id_name + '" value="' + trial.options[i][j] + '">');
      }

      // add "question required" asterisk
      $(question_selector + " p").append("<span class='required'>*</span>")

      // add required property
      $(question_selector + " input:radio").prop("required", true);
    }

    // add submit button
    $trial_form.append($('<input>', {
      'type': 'submit',
      'id': 'submit-quiz',
      'class': plugin_id_name + ' jspsych-btn',
      'value': 'Submit Answers'
    }));

    // trial_form.noValidate = true;
    
    var attempts = []

    $trial_form.submit(function(event) {

      event.preventDefault();
      
      if (!event.target.checkValidity()) {
          event.preventDefault(); // dismiss the default functionality
          alert('Please answer all required questions.'); // error message
          return
      }

      // measure response time
      var endTime = (new Date()).getTime();
      var response_time = endTime - startTime;

      // create object to hold responses
      var question_data = [];
      $("div." + plugin_id_name + "-question").each(function(index) {
        // var id = "Q" + index;
        var val = $(this).find("input:radio:checked").val();
        // var obje = {};
        // obje[id] = val;
        // $.extend(question_data, obje);
        question_data.push(val)
      });

      var correct = null;
      var mistake = false;
      console.log(trial.correct)
      if (trial.correct) {
        correct = [];
        for (var i = 0; i < question_data.length; i++) {
          var c = trial.correct[i] == question_data[i];
          if (!c) mistake = true;
          correct.push(c)
        }
      }

      attempts.push({
         "rt": response_time,
         "responses": JSON.stringify(question_data),
         "correct": correct
       });

      if (mistake) {
        trial.onMistake();
        $('#submit-quiz').hide();
        numTriesLeft -= 1;
        
        if (numTriesLeft <= 0) {
          // End experiment
        $('<div>', {
          class: 'modal',
          html: $('<div>', {
            class: 'modal-content',
            html: `
              <h2>Disqualified</h2>

              <p>
              Sorry, you exceeded the maximum number of attempts to finish the quiz.
              This disqualifies you from completing the experiment. You will still
              receive the base pay. Please click the button below to submit.
            `
          })
        }).appendTo(display_element);
        $('<button>', {
          text: 'Submit HIT',
          class: 'btn btn-primary btn-lg',
          click: function() {
            display_element.html('');
            $('.modal').remove();
            $('#load-icon').show();
            jsPsych.endExperiment();
            jsPsych.finishTrial({
              "questions": JSON.stringify(trial.questions),
              "attempts": attempts
            });
          }
        }).appendTo($('.modal-content'));
        } else {
          // Try again
          $('<div>', {
            class: 'modal',
            html: $('<div>', {
              class: 'modal-content',
              html: `
                <h2>Not quite right</h2>

                <p>
                Please review the information below and try again.<br>
                <b>You have ${numTriesLeft} attempts remaining</b>
                </p>

                ${trial.review}
              `
            })
          }).appendTo(display_element);
          $('<button>', {
            text: 'Try Again',
            class: 'btn btn-primary btn-lg',
            click: function() {
              $('.modal').remove();
              $('#submit-quiz').show();
            }
          }).appendTo($('.modal-content'));
        }
      } else { 
        display_element.html('');

        // next trial
        jsPsych.finishTrial({
          "questions": JSON.stringify(trial.questions),
          "attempts": attempts
        });
      }

    });

    var startTime = (new Date()).getTime();
  };

  return plugin;
})();
