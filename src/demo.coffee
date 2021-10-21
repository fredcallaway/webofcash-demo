# coffeelint: disable=max_line_length, indentation

# tell coffeescript about global variables
EXPERIMENT = EXPERIMENT  
N_TRAIN = N_TRAIN
N_TEST = N_TEST
N_TRAIN_REWARD = N_TRAIN_REWARD

radio = (group, val, label, attrs="") -> """
  <input type="radio" id="#{val}" name="#{group}" value="#{val}" #{attrs}>
  <label for="#{val}">#{label}</label>&nbsp;&nbsp;&nbsp;
"""

askWhatDemo = ->
  top = """
    <h1>Mouselab-MDP demonstration</h1>

    <p>Which experiment/condition would you like to view?
  """
  top += "<p><strong>Experiment 1:&nbsp;&nbsp;&nbsp;</strong>"
  top += radio('exp', "1-constant", "constant", "checked")
  
  top += "<p><strong>Experiment 2:&nbsp;&nbsp;&nbsp;</strong>"
  top += radio('exp', "2-decreasing", "decreasing")
  top += radio('exp', "2-constant", "constant")
  top += radio('exp', "2-increasing", "increasing")
  
  top += "<p><strong>Experiment 3:&nbsp;&nbsp;&nbsp;</strong>"
  top += radio('exp', "3-decreasing", "decreasing")
  top += radio('exp', "3-constant", "constant")
  top += radio('exp', "3-increasing", "increasing")
  
  top += "<p><strong>Experiment 4:&nbsp;&nbsp;&nbsp;</strong>"
  top += '<a href="http://roadtriptask.herokuapp.com/exp?hitId=demo&assignmentId=demo&workerId=demo&mode=debug"><strong>click here</strong></a>'
  top += ' (task demo only)'
  
  top += """<p>
    You can do the experiment yourself or you can watch playbacks
    of our participants or the optimal model performing the task.
  """
  $('#demo-landing').html top
  $('#jspsych-target').empty()

  buttons = $('<div/>').css
    'text-align': 'center'
    'margin-top': '20px'
  buttons.appendTo($('#demo-landing'))

  click = (show) ->
    [exp, variance] = $('input[name="exp"]:checked').val().split('-')
    EXPERIMENT = parseInt exp
    window.history.pushState("", "", "/?exp=#{exp}&variance=#{variance}&show=#{show}")
    runDemo()

  $('<button/>',
    class: 'btn btn-primary '
    text: 'Do Task'
    click: -> click('task')
  ).appendTo buttons

  $('<button/>',
    class: 'btn btn-primary '
    text: 'Watch Participants'
    click: -> click('human')
  ).appendTo buttons

  $('<button/>',
    class: 'btn btn-primary '
    text: 'Watch Optimal Model'
    click: -> click('model')
  ).appendTo buttons
  
  # $('<button/>',
  #   class: 'btn btn-primary '
  #   text: 'Watch Model Simulations'
  #   click: -> click('model')
  # ).appendTo buttons

data = null
runDemo = ->
  console.log('runDemo')
  show = getSearchParam('show')
  if not show?
    askWhatDemo()
  else switch show
    when 'task' then showTask()
    when 'human' then showHuman()
    when 'model' then showModel()

showTask = ->
  console.log 'showTask', length
  length = getSearchParam('length')

  if length == 'short'
    N_TRAIN = 1
    N_TRAIN_REWARD = 3
    N_TEST = 5
    loadExperiment()
  else if length == 'full'
    loadExperiment()
  else
    $('#demo-landing').html """
    <h1>Web of Cash task demo</h1>
    <br>Would you like to do an abbreviated version of the experiment (fewer trials in each section)
     or the full-length version, exactly as given to participants?
    """
    buttons = $('<div/>').css
      'text-align': 'center'
      'margin-top': '20px'
    buttons.appendTo $('#demo-landing')

    click = (length) ->
      if length == 'skip'
        window.history.pushState("", "", location.search + "&length=full&skip=8")
      else
        window.history.pushState("", "", location.search + "&length=#{length}")
      showTask()

    $('<button/>',
      class: 'btn btn-primary '
      text: 'Shortened'
      click: -> click('short')
    ).appendTo buttons

    $('<button/>',
      class: 'btn btn-primary '
      text: 'Full length'
      click: -> click('full')
    ).appendTo buttons

    $('<button/>',
      class: 'btn btn-primary '
      text: 'Skip Instructions'
      click: -> click('skip')
    ).appendTo buttons

showHuman = ->
  wid = getSearchParam('participant')
  if wid?
    $('#demo-landing').hide()
    $('#load-icon').show()
    wid = getSearchParam('participant')
    trials = loadJson "static/json/demo/#{getSearchParam('exp')}/human/#{wid}.json"
    showDemoTrials(trials)
  else
    showHumanDashboard()

showDemoTrials = (trials) ->
  trial_idx = parseInt(getSearchParam('trial')) - 1 || 0
  PARAMS = makeParams()
  STRUCTURE = loadJson "static/json/structure/#{PARAMS.branching}.json"
  watch = new Block
    type: 'mouselab-mdp'
    playerImage: 'static/images/spider.png'
    lowerMessage: 'Move with the arrow keys.'
    clickDelay: 0
    expandOnly: PARAMS.expandOnly
    _init: ->
      _.extend(this, STRUCTURE)
      @trialCount = trial_idx

    # minTime: 7
    blockName: 'test'
    stateDisplay: 'click'
    stateClickCost: PARAMS.inspectCost
    timeline: trials[(trial_idx)...]
    rightMessage: "&nbsp;"
    leftMessage: ->
      trial = watch.trialCount + 1
      search = location.search.split('&trial')[0]
      window.history.pushState("", "", "/#{search}&trial=#{trial}")
      "Round #{trial}/#{trials.length}"
    startScore: 50

  
  jsPsych.init
    display_element: $('#jspsych-target')
    timeline: [watch]
    # show_progress_bar: true

    on_finish: ->
      window.history.pushState("", "", search)
      runDemo()

showHumanDashboard = ->
  $('#demo-landing').show()
  $('#jspsych-target').empty()
  top = """
    <h1>Human data playbacks</h1>
    Click on one of the buttons below to view the behavior of our
    participants. Note that the URL will be updated as you progress through
    the experiment, so you can create a link to the current trial by copying
    the text in the search bar.

    <br><br>
  """
  $('#demo-landing').html top

  $('#demo-landing').append $('<button/>',
    class: 'btn btn-primary'
    text: 'Back'
    style: 'margin-bottom: 10px'
    click: ->
      window.history.pushState("", "", "/")
      runDemo()
  )
  # $('#demo-landing').css
  #   width: 'px'


  WATCH = true
  table = loadJson "static/json/demo/#{getSearchParam('exp')}/human/table-#{getSearchParam('variance')}.json"

  tbl = $("<table/>").addClass 'table'
  header = $("<tr>").appendTo tbl
  for col in DASHBOARD_COLS
    $('<td/>').css("font-weight","Bold").text(col).appendTo(header)

  _(table).forEach (d) ->
    row = $('<tr/>').appendTo(tbl)
    for col in ['wid', 'variance', 'score', 'clicks', ] # 'optimal_cost', 'optimal_nll', 'bestfirst_nll'
      $('<td/>').text(d[col]).appendTo(row)

    row.append $ '<button/>',
      class: 'btn btn-primary '
      text: 'Go'
      click: ->
        search = location.search + "&participant=#{d.wid}"
        window.history.pushState("", "", search)
        showHuman()

  tbl.appendTo $('#demo-landing')

showModel = ->
  console.log('showModel')
  model = getSearchParam('model')

  if model?
    $('#demo-landing').hide()
    $('#load-icon').show()
    trials = loadJson "static/json/demo/#{getSearchParam('exp')}/optimal/#{model}.json"
    showDemoTrials(trials)
  else
    showModelDashboard()

demoTask = ->
  switch SHOW
    when 'short'
      N_TRAIN = 1
      N_TEST = 5
      initializeExperiment()
    when 'full','test','debug','quiz','comprehension'
      initializeExperiment()
    else
      top = """
        <h1>Web of Cash Experiment Demo</h1>
        Please select one of the buttons below to do the full experiment,
        a version of the experiment with fewer trials,
        or just the task (skipping instructions).
      """
      $('#demo-landing').html top

      buttons = $('<div/>').css
        'text-align': 'center'
        'margin-top': '20px'
      buttons.appendTo($('#demo-landing'))

      $('<button/>',
        class: 'btn btn-primary'
        text: 'Full Length'
        click: ->
          window.history.pushState("", "", "/?show=full")
          SHOW = "full"
          initializeExperiment()
      ).appendTo buttons

      $('<button/>',
        class: 'btn btn-primary '
        text: 'Shortened'
        click: ->
          N_TRAIN = 1
          N_TEST = 5
          window.history.pushState("", "", "/?show=short")
          SHOW = "short"
          initializeExperiment()
      ).appendTo buttons

      $('<button/>',
        class: 'btn btn-primary '
        text: 'Test Only'
        click: ->
          window.history.pushState("", "", "/?show=test")
          DEMO = true
          SHOW = "test"
          initializeExperiment()
      ).appendTo buttons


DASHBOARD_COLS = [
    'Participant ID'
    'Variance'
    'Average Score'
    'Average Clicks'
    # 'MLE Cost'
    # 'Optimal NLL'
    # 'BestFirst NLL'
    'Click To Watch'
  ]

showModelDashboard = ->
  $('#demo-landing').show()
  console.log('showModelDashboard')
  top = markdown """
    <h1>Web of Cash Visualization Dashboard</h1>
    Click on one of the buttons below to view model simulations.
    <br><br>
  """
  $('#demo-landing').html top
  $('#demo-landing').append $('<button/>',
    class: 'btn btn-primary'
    text: 'Back'
    style: 'margin-bottom: 10px'
    click: ->
      window.history.pushState("", "", "/")
      runDemo()
  )

  WATCH = true
  table = loadJson "static/json/demo/#{getSearchParam('exp')}/optimal/table-#{getSearchParam('variance')}.json"
  
  tbl = $("<table/>").addClass 'table'
  tbl.appendTo $('#demo-landing')
  header = $("<tr>").appendTo tbl
  for col in ['Cost', 'Average Score', 'Average Clicks', 'Click to Watch']

    $('<td/>').css("font-weight","Bold").text(col).appendTo(header)

  _(table).forEach (d) ->
    row = $('<tr/>').appendTo(tbl)
    for col in ['cost', 'score', 'clicks'] # 'optimal_cost', 'optimal_nll', 'bestfirst_nll'
      $('<td/>').text(d[col]).appendTo(row)

    row.append $ '<button/>',
      class: 'btn btn-primary '
      text: 'Go'
      click: ->
        search = location.search + "&model=#{d.name}"
        window.history.pushState("", "", search)
        showModel()
